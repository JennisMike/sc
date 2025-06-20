import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/offer_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/offer_action_box.dart';
import '../../widgets/reply_dialog.dart';
import '../../widgets/reply_bubble.dart';
import '../../models/reply_model.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reply_provider.dart';
import '../../providers/offer_service_provider.dart';
import '../splash/splash_screen.dart';
import '../../providers/marketplace_provider.dart';
import '../../features/chat/providers/chat_providers.dart';
import '../../features/chat/screens/individual_chat_screen.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _offerKeys = {};
  Map<String, Offer> _offerDetailsCache = {};

  // Added exchange rate constant here
  static const double _exchangeRateRmbToFcfa = 80.0; 

  double _walletBalance = 0.0;
  UserModel? _currentUser;
  bool _isComposingOffer = false;
  bool _isShowingInternalLoadingIndicator = true;
  bool _hasProcessedFirstOfferStreamEvent = false;

  String offerType = '';
  String amountRaw = '';
  String rateRaw = '';
  bool isPanelOpen = false;
  List<String> offerSteps = [];

  late AnimationController _panelController;
  late Animation<double> _panelAnimation;
  late final NumberFormat _numberFormat;
  late final TextEditingController _amountController;
  late final TextEditingController _rateController;

  @override
  void initState() {
    super.initState();
    final initialLoadDone = ref.read(marketplaceInitialLoadDoneProvider);
    if (!initialLoadDone) {
      _isShowingInternalLoadingIndicator = true;
      _hasProcessedFirstOfferStreamEvent = false;
    } else {
      _isShowingInternalLoadingIndicator = false;
      _hasProcessedFirstOfferStreamEvent = true;
    }

    _numberFormat = NumberFormat.currency(symbol: 'FCFA ');
    _amountController = TextEditingController();
    _rateController = TextEditingController();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeInOut,
    );

    _scrollController.addListener(_onScroll);
    
    _initializeCurrentUser();
  }
  
  void _onScroll() {
    if (_scrollController.hasClients && 
        _scrollController.position.pixels <= _scrollController.position.minScrollExtent + 50 &&
        _scrollController.position.outOfRange == false &&
        !ref.watch(offerLoadMoreProvider).isLoading) {
      debugPrint("Marketplace: Scrolled to top, loading more offers.");
      ref.read(offerLoadMoreProvider.future).then((hasMore) {
        // if(mounted && !hasMore) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(content: Text('No more offers to load.'), duration: Duration(seconds: 2)), //I've commented the text "No more offers to load."
        //   );
        // }
      }).catchError((e) {
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading more offers: $e'), duration: Duration(seconds: 2)),
            );
         }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _panelController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeCurrentUser() async {
    final authState = ref.read(authRepositoryProvider);
    
    authState.whenData((authData) {
      if (authData.status == AuthStatus.authenticated && authData.user != null) {
        if (mounted) {
          setState(() {
            _currentUser = authData.user;
          });
          _loadUserBalance();
        }
      } else {
          if (mounted) {
            setState(() {
            _currentUser = null;
          });
        }
      }
    });

    if (_currentUser == null) {
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      if (supabaseUser != null) {
      try {
          final userProfileMap = await _authService.getUserProfile(supabaseUser.id);
          if (userProfileMap != null && mounted) {
          setState(() {
              _currentUser = UserModel.fromMap(userProfileMap);
          });
          _loadUserBalance();
        }
        } catch (e) {
          debugPrint("Error fetching profile for current user: $e");
        }
      }
    }
     if (mounted && _currentUser == null) {
        debugPrint('Marketplace: User not authenticated. Some actions might be unavailable.');
    }
  }

  Future<void> _loadUserBalance() async {
    if (_currentUser != null) {
      if (mounted) {
    setState(() {
          _walletBalance = _currentUser?.walletBalance ?? 0.0;
        });
      }
    }
  }

  String get _builtMessage {
    if (offerType.isEmpty) return '';
    String formattedAmount = amountRaw.isNotEmpty
        ? _numberFormat.format(double.tryParse(amountRaw) ?? 0)
        : '';
    String currentRateVal = rateRaw.replaceAll('%', '');

    if (offerType == 'RMB available') {
      String msg = 'RMB available';
      if (amountRaw.isNotEmpty) {
        msg += ', $formattedAmount RMB max';
      }
      if (currentRateVal.isNotEmpty) {
        msg += ', $currentRateVal%';
      }
      return msg;
    }
    if (offerType == 'Need RMB') {
      String msg = 'Need RMB';
      if (amountRaw.isNotEmpty) {
        msg += ' for $formattedAmount FCFA';
      }
      if (currentRateVal.isNotEmpty) {
        msg += ' ($currentRateVal%)';
      }
      return msg;
    }
    if (offerType == 'Need FCFA') {
      String msg = 'Need FCFA';
      if (amountRaw.isNotEmpty) {
        msg += ' for $formattedAmount RMB';
      }
      if (currentRateVal.isNotEmpty) {
        msg += ' ($currentRateVal%)';
      }
      return msg;
    }
    String msg = offerType;
    if (amountRaw.isNotEmpty) {
      msg += ' for $formattedAmount';
    }
    if (currentRateVal.isNotEmpty) {
      msg += ' ($currentRateVal%)';
    }
    return msg;
  }

  bool get canSend => (offerType == 'RMB available'
      ? amountRaw.isNotEmpty && rateRaw.isNotEmpty
      : offerType.isNotEmpty && amountRaw.isNotEmpty);

  Future<bool> _onWillPop() async {
    if (isPanelOpen) {
      closePanel();
      return false;
    }
    return true;
  }

  Future<void> _handleSendOffer() async {
    final offerService = await ref.read(supabaseOfferServiceProvider.future);
    final currentAuthUser = _currentUser;

    if (currentAuthUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please sign in to create an offer'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            duration: Duration(seconds: 3),
          ),
        );
        await _initializeCurrentUser();
      }
      return;
    }

    final userDisplayName = currentAuthUser.username ?? 'User';
    final userAvatarUrl = currentAuthUser.profilePicture ?? '';

    double parsedAmount;
    double? parsedRate;

    if (amountRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount is required.')));
        return;
      }
    parsedAmount = double.tryParse(amountRaw) ?? 0;
      if (parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount must be greater than 0.')));
        return;
      }

    // Check wallet balance for "Need RMB" offers
    if (offerType == 'Need RMB') {
      if (_walletBalance <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
            content: Text('You need to have funds in your wallet to create a "Need RMB" offer.'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
          );
          return;
        }
      if (parsedAmount > _walletBalance) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Amount exceeds your wallet balance of ${_walletBalance.toStringAsFixed(0)} FCFA.'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
          );
          return;
      }
    }

    if ((offerType == 'RMB available' || offerType == 'Need FCFA') && parsedAmount > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max amount is 5000 RMB.')));
      return;
    }

    if (rateRaw.isNotEmpty) {
      parsedRate = double.tryParse(rateRaw.replaceAll('%', '')) ?? 0;
      if (parsedRate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate must be greater than 0 if provided.')));
        return;
      }
      if (parsedRate > 20) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max rate is 20%.')));
        return;
      }
    } else if (offerType == 'RMB available') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate is required for RMB available offers.')));
      return;
    }

    String finalMessage = _builtMessage;
    final String typeForDb = offerType;
    final double amountForDb = parsedAmount;
    final double? rateForDb = parsedRate;

    // Create temporary offer for immediate UI update
    final tempOffer = Offer(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      userId: currentAuthUser.id,
      userDisplayName: userDisplayName,
      userAvatarUrl: userAvatarUrl,
      type: typeForDb,
      amount: amountForDb,
      rate: rateForDb,
      message: finalMessage,
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Clear input fields and close panel immediately
    setState(() {
      offerType = '';
      amountRaw = '';
      rateRaw = '';
      offerSteps.clear();
      _amountController.clear();
      _rateController.clear();
    });
    closePanel();

    // Show loading indicator
    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Posting offer...'),
          ],
        ),
          duration: Duration(seconds: 10),
      ),
    );
    }

    print('MarketplaceScreen: _handleSendOffer: Calling offerService.createOffer with type: $typeForDb');
    try {
      // Create offer in database
      final newOffer = await offerService!.createOffer(
        userId: currentAuthUser.id,
        userDisplayName: userDisplayName,
        userAvatarUrl: userAvatarUrl,
        type: typeForDb,
        amount: amountForDb,
        rate: rateForDb,
        message: finalMessage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Offer posted successfully! (ID: ${newOffer.id})'),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          duration: const Duration(seconds: 3),
        ),
      );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        String errorMessage = 'Error creating offer: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: const Duration(seconds: 5),
        ),
      );
      }
    }
  }

  Future<void> _handleDeleteOffer(Offer offer) async {
    final offerService = await ref.read(supabaseOfferServiceProvider.future);
    try {
      await offerService!.updateOfferStatus(offer.id, 'deleted');
      if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer deleted successfully')),
      );
      }
    } catch (e) {
      if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting offer: ${e.toString()}')),
      );
    }
  }
  }

  Future<void> _handleReplyToOffer(Offer offer) async {
    final currentAuthUser = _currentUser;

    if (currentAuthUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to reply.')),
        );
      }
        return;
      }

    await showDialog(
        context: context,
        builder: (context) => ReplyDialog(
          offer: offer,
        onSendReply: (String message, double rate, double? amount, bool isPublic, String transactionSummary) async {
          print('[MarketplaceScreen] _handleReplyToOffer: onSendReply CALLED. Message: "$message"'); // Removed duplicate
          final replyService = ref.read(supabaseReplyServiceProvider);
            print('[MarketplaceScreen] _handleReplyToOffer: Got replyService instance: ${replyService.hashCode}');
            try {
            print('[MarketplaceScreen] _handleReplyToOffer: TRYING to call replyService.createReply');
            await replyService.createReply(
                offerId: offer.id,
              userId: currentAuthUser.id,
              userDisplayName: currentAuthUser.username ?? 'Anonymous',
              userAvatarUrl: currentAuthUser.profilePicture ?? '',
              message: message,
                rate: rate,
                amount: amount,
                isPublic: isPublic,
                transactionSummaryForReplier: transactionSummary,
                offerOwnerId: offer.userId,
              );
            print('[MarketplaceScreen] _handleReplyToOffer: replyService.createReply SUCCEEDED (apparently)');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reply sent!'), backgroundColor: Theme.of(context).colorScheme.secondaryContainer),
                );
              }
            } catch (e) {
            print('[MarketplaceScreen] _handleReplyToOffer: CATCH block. Error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error sending reply: $e'), backgroundColor: Theme.of(context).colorScheme.errorContainer),
              );
            }
            }
          },
        ),
      );
  }

  Future<void> _handleAcceptReply(Offer offer, Reply reply) async {
    final offerService = await ref.read(supabaseOfferServiceProvider.future);
    final replyService = ref.read(supabaseReplyServiceProvider);
    final chatService = ref.read(chatServiceProvider);
    final currentAuthUser = _currentUser;

    if (currentAuthUser == null || currentAuthUser.id != offer.userId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not authorized to accept this reply.')),
        );
      }
      return;
    }

    if (offer.status == 'accepted') {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This offer has already been accepted.')),
      );
      }
      return;
    }
    if (reply.status == 'accepted') {
       if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This reply has already been accepted.')),
      );
      }
      return;
    }

    // Show confirmation dialog
    final confirmAccept = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Acceptance'),
          content: Text('Accepting this reply will create a private chat with ${reply.userDisplayName} so you can exchange payment details securely. Proceed?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // User canceled
              },
            ),
            TextButton(
              child: const Text('Accept & Chat'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // User confirmed
              },
            ),
          ],
        );
      },
    );

    if (confirmAccept != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acceptance canceled.')),
        );
      }
      return; // User canceled
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Processing acceptance...'),
            duration: Duration(seconds: 10)), // Show a longer initial snackbar
      );
    }

    try {
      print("MarketplaceScreen: Attempting to accept reply ${reply.id} for offer ${offer.id}");

      // Update reply status to 'accepted'
      print("  Action: Update reply status to 'accepted'. Reply ID: ${reply.id}");
      await replyService.updateReplyStatus(reply.id, 'accepted');
      print("  Reply status updated.");

      // Update offer status to 'accepted' and store accepted_by_user_id and accepted_at
      final DateTime acceptedTimestamp = DateTime.now();
      print("  Action: Update offer status to 'accepted', accepted_by_user_id: ${reply.userId}, accepted_at: $acceptedTimestamp. Offer ID: ${offer.id}");
      await offerService!.updateOfferStatus(
        offer.id, 
        'accepted', 
          acceptedByUserId: reply.userId,
        acceptedAt: acceptedTimestamp,
      );
      print("  Offer status updated.");

      // Create or get conversation
      print("  Action: Create or get conversation. Offer Owner: ${offer.userId}, Replier: ${reply.userId}, Offer: ${offer.id}");
      final conversationId = await chatService.createConversationForOffer(
        offerOwnerId: offer.userId,
        replyUserId: reply.userId,
        offerId: offer.id,
        replyId: reply.id,
      );
      print("  Chat service call completed. Conversation ID: $conversationId");

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove "Processing..."
        if (conversationId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reply accepted! Chat created.'), backgroundColor: Theme.of(context).colorScheme.secondaryContainer),
          );

          // Construct the context message
          String offerOwnerSummary = "";
          String replierSummary = reply.transactionSummaryForReplier ?? "Details for replier not available.";
          final NumberFormat currencyFormat = NumberFormat("#,##0.00");
          final NumberFormat fcfaFormat = NumberFormat("#,##0");

          // Calculate summary for offer owner based on offer type and reply
          if (offer.type == 'Need RMB') { // Offer owner needs RMB, will pay FCFA. Replier provides RMB, receives FCFA.
            final fcfaOwnerReceives = offer.amount;
            final rmbOwnerPays = fcfaOwnerReceives * (1 - reply.rate / 100) / _exchangeRateRmbToFcfa;
            offerOwnerSummary = "You will receive ${fcfaFormat.format(fcfaOwnerReceives)} FCFA and pay ${currencyFormat.format(rmbOwnerPays)} RMB (based on replier's rate of ${reply.rate}%).";

          } else if (offer.type == 'Need FCFA') { // Offer owner needs FCFA, will pay RMB. Replier provides FCFA, receives RMB.
            final rmbOwnerPays = offer.amount; 
            final fcfaOwnerReceives = rmbOwnerPays * (1 - reply.rate / 100) * _exchangeRateRmbToFcfa;
             offerOwnerSummary = "You will receive ${fcfaFormat.format(fcfaOwnerReceives)} FCFA and pay ${currencyFormat.format(rmbOwnerPays)} RMB (based on replier's rate of ${reply.rate}%).";

          } else if (offer.type == 'RMB available') { // Offer owner has RMB, needs FCFA. Replier provides FCFA, receives RMB.
            final fcfaOwnerReceives = reply.amount ?? 0;
            if (offer.rate != null && fcfaOwnerReceives > 0) {
              final rmbOwnerPays = fcfaOwnerReceives / _exchangeRateRmbToFcfa * (1 - offer.rate! / 100);
              offerOwnerSummary = "You will receive ${fcfaFormat.format(fcfaOwnerReceives)} FCFA and pay ${currencyFormat.format(rmbOwnerPays)} RMB (at your offer rate of ${offer.rate}%).";
            } else {
              offerOwnerSummary = "Details for offer owner not available due to missing reply amount or offer rate.";
            }
          }
          
          String offerAmountFormatted = offer.type.contains("FCFA") ? fcfaFormat.format(offer.amount) : currencyFormat.format(offer.amount);
          String offerUnit = offer.type.contains("RMB") ? "RMB" : "FCFA";
          String replyDetail = reply.message.isNotEmpty ? "Message: ${reply.message}" : "Proposed Rate: ${reply.rate}%";
          if (offer.type == 'RMB available' && reply.amount != null) {
            replyDetail += "\nProposed FCFA for exchange: ${fcfaFormat.format(reply.amount)} FCFA";
          }

          final String contextMessage = """
**Transaction Details Agreed:**

**Original Offer (${offer.userDisplayName}):**
Type: ${offer.type}
Amount: $offerAmountFormatted $offerUnit
${offer.rate != null ? "Rate: ${offer.rate}%" : ""}
Message: ${offer.message}

**Accepted Reply (${reply.userDisplayName}):**
$replyDetail

---
**Summary for Offer Owner (${offer.userDisplayName}):**
$offerOwnerSummary

**Summary for Replier (${reply.userDisplayName}):**
$replierSummary
---
This message confirms the terms of your transaction. Please proceed with the exchange.
          """.trim().replaceAll(RegExp(r'\n          +'), '\n');


          // Send the context message
          await chatService.sendTextMessage(
            conversationId: conversationId,
            senderId: currentAuthUser.id, // Offer owner sends the context message
            text: contextMessage,
            senderDisplayName: currentAuthUser.username,
            senderAvatarUrl: currentAuthUser.profilePicture,
          );
          print("  Context message sent to conversation $conversationId");
          
          // Navigate to the chat screen
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => IndividualChatScreen(
            conversationId: conversationId,
            otherUserId: reply.userId,
            otherUserDisplayName: reply.userDisplayName, 
            otherUserAvatarUrl: reply.userAvatarUrl,
          )));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reply accepted, but failed to set up chat.'), backgroundColor: Theme.of(context).colorScheme.errorContainer),
          );
        }
      }

    } catch (e) {
      print("MarketplaceScreen: Error accepting reply: ${e.toString()}");
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting reply: ${e.toString()}')),
      );
      }
    }
  }

  void openPanel() {
    setState(() {
       isPanelOpen = true;
       _isComposingOffer = true;
    });
    _panelController.forward();
  }

  void closePanel() {
    _panelController.reverse().then((_) {
      if (mounted) {
        setState(() {
          isPanelOpen = false;
          _isComposingOffer = false;
        });
      }
    });
  }

  void clearOffer() {
    if (mounted) {
      setState(() {
        offerType = '';
        amountRaw = '';
        rateRaw = '';
        offerSteps.clear();
        _amountController.clear();
        _rateController.clear();
      });
    }
  }
  
  void backStep() {
    if (mounted) {
      setState(() {
        if (offerSteps.isNotEmpty) {
          String last = offerSteps.removeLast();
          if (last == 'rate') rateRaw = '';
          else if (last == 'amount') amountRaw = '';
          else if (last == 'type') offerType = '';
        }
      });
    }
  }

  void selectType(String type) {
    if (mounted) {
      setState(() {
        offerType = type;
        amountRaw = '';
        rateRaw = '';
        _amountController.clear();
        _rateController.clear();
        if (!offerSteps.contains('type')) {
            offerSteps.add('type');
                } else {
            offerSteps.removeWhere((step) => step == 'amount' || step == 'rate');
        }
        });
      }
  }

  void setAmount(String value) {
    if (mounted) {
      setState(() {
        amountRaw = value;
        if (value.isNotEmpty && !offerSteps.contains('amount')) offerSteps.add('amount');
        else if (value.isEmpty && offerSteps.contains('amount')) offerSteps.remove('amount');
      });
    }
  }

  void setRate(String value) {
    if (mounted) {
      setState(() {
        rateRaw = value;
        if (value.isNotEmpty && !offerSteps.contains('rate')) offerSteps.add('rate');
        else if (value.isEmpty && offerSteps.contains('rate')) offerSteps.remove('rate');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final offersAsyncValue = ref.watch(offersStreamProvider);
    final currentAuthUserId = _currentUser?.id;
    final panelHeight = 280.0;

    final initialLoadHasCompleted = ref.watch(marketplaceInitialLoadDoneProvider);

    final shouldRunInitialLoadSequence = !initialLoadHasCompleted;

    if (shouldRunInitialLoadSequence) {
      _isShowingInternalLoadingIndicator = true;
                } else {
      _isShowingInternalLoadingIndicator = false;
    }

    ref.listen<AsyncValue<List<Offer>>>(offersStreamProvider, (previous, next) {
      if (!ref.read(marketplaceInitialLoadDoneProvider)) {
        next.when(
          data: (offers) {
            if (mounted && !_hasProcessedFirstOfferStreamEvent) {
              _hasProcessedFirstOfferStreamEvent = true;
              print("MarketplaceScreen: First offer data received (initial load sequence). Starting 2s delay.");

              Future.delayed(const Duration(milliseconds: 2000), () {
                if (mounted) {
                  print("MarketplaceScreen: 2s delay finished (initial load sequence). Hiding internal splash.");
                  if (_isShowingInternalLoadingIndicator) {
                    setState(() {
                      _isShowingInternalLoadingIndicator = false;
                    });
                  }

                  ref.read(marketplaceInitialLoadDoneProvider.notifier).state = true;
                  print("MarketplaceScreen: marketplaceInitialLoadDoneProvider set to true.");
                }
              });
            }
          },
          loading: () {
            print("MarketplaceScreen: Offer stream loading (initial load sequence). Splash visibility controlled by initialLoadHasCompleted.");
            if (shouldRunInitialLoadSequence && !_isShowingInternalLoadingIndicator) {
            } else if (shouldRunInitialLoadSequence) {
                 _isShowingInternalLoadingIndicator = true;
            }
          },
          error: (e, s) {
            if (mounted && !ref.read(marketplaceInitialLoadDoneProvider)) {
              print("MarketplaceScreen: Error in offer stream (initial load sequence). Error: $e. Setting initial load done.");
              if (_isShowingInternalLoadingIndicator) {
                  setState(() {
                      _isShowingInternalLoadingIndicator = false;
                  });
              }
              ref.read(marketplaceInitialLoadDoneProvider.notifier).state = true;
            }
          }
        );
      }
    });

    bool actuallyShowSplash = !initialLoadHasCompleted && _isShowingInternalLoadingIndicator;
    
    if (!initialLoadHasCompleted && offersAsyncValue is AsyncLoading) {
        print("MarketplaceScreen: Build: Initial load not done AND offers are AsyncLoading. Showing SplashScreen.");
        actuallyShowSplash = true;
    }

    if (actuallyShowSplash) {
      print("MarketplaceScreen: Build method: Showing internal splash screen via actuallyShowSplash.");
      return const SplashScreen();
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          offersAsyncValue.when(
            data: (offers) {
              if (offers.isEmpty) {
                print("MarketplaceScreen: offersAsyncValue.data is empty, showing SplashScreen instead of 'No offers' message.");
                return const SplashScreen(); 
              }

              _offerKeys.clear();
              _offerDetailsCache.clear();
              for (var offerdata in offers) {
                _offerKeys[offerdata.id] = GlobalKey();
                _offerDetailsCache[offerdata.id] = offerdata;
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: EdgeInsets.only(
                  bottom: isPanelOpen ? panelHeight + 60 : 80,
                  top: 8,
                  left: 4,
                  right: 4,
                ),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final reversedIndex = offers.length - 1 - index;
                    final offerItem = offers[reversedIndex];
                    final isMine = offerItem.userId == currentAuthUserId;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: OfferBubble(
                        key: _offerKeys[offerItem.id],
                        offer: offerItem,
                      isMine: isMine,
                        onDelete: isMine ? () => _handleDeleteOffer(offerItem) : null,
                        onReply: !isMine ? () => _handleReplyToOffer(offerItem) : null,
                        onAcceptOfferReply: isMine ? (Offer acceptedOffer, Reply acceptedReply) => _handleAcceptReply(acceptedOffer, acceptedReply) : null,
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) {
              debugPrint('Error fetching offers: $error\n$stackTrace');
              if (shouldRunInitialLoadSequence && !_isShowingInternalLoadingIndicator) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _isShowingInternalLoadingIndicator = true;
                    });
                  }
                });
              }
              String userMessage;
              final errorString = error.toString();
              if (errorString.contains('SocketException') ||
                  errorString.contains('Failed host lookup')) {
                userMessage = 'Network error. Please check your connection and try again.';
              } else {
                userMessage = 'Error fetching offers. Please try again later.';
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(userMessage, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(offersStreamProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: isPanelOpen ? panelHeight : 0,
            child: OfferInputBar(
              message: _builtMessage,
              onTap: openPanel,
              onSend: canSend ? _handleSendOffer : null,
              canSend: canSend,
            ),
          ),
          if (isPanelOpen)
            AnimatedBuilder(
              animation: _panelAnimation,
              builder: (context, child) {
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: panelHeight * _panelAnimation.value,
                  child: child!,
                );
              },
              child: CustomAnimatedPanel(
                offerType: offerType,
                currentAmountRaw: amountRaw,
                currentRateRaw: rateRaw,
                walletBalance: _walletBalance,
                onTypeSelected: selectType,
                onAmountChanged: setAmount,
                onRateChanged: setRate,
                onBack: offerSteps.isNotEmpty ? backStep : null,
                onClear: (offerType.isNotEmpty || amountRaw.isNotEmpty || rateRaw.isNotEmpty) ? clearOffer : null,
                onClose: closePanel,
                amountController: _amountController,
                rateController: _rateController,
              ),
            ),
        ],
      ),
    );
  }
}

class OfferBubble extends ConsumerWidget {
  final Offer offer;
  final bool isMine;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final Function(Offer offer, Reply reply)? onAcceptOfferReply;

  const OfferBubble({
    Key? key,
    required this.offer,
    required this.isMine,
    this.onDelete,
    this.onReply,
    this.onAcceptOfferReply,
  }) : super(key: key);

  void _showActionBox(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset position = box.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Theme.of(context).colorScheme.scrim.withOpacity(0.12)),
            ),
          ),
          Positioned(
            left: isMine ? null : 12,
            right: isMine ? 12 : null,
            bottom: MediaQuery.of(context).size.height -
                position.dy -
                box.size.height,
            width: 150,
            child: OfferActionBox(
              isOwner: isMine,
              offerStatus: offer.status,
              onDelete: onDelete,
              onReply: onReply,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isOfferEffectivelyAccepted = offer.status == 'accepted'; // Determine if offer is accepted

    // Conditionally fetch profile if avatar or display name is missing or looks like a fallback (ID)
    // This is mainly for other users' offers. Own offers should have data from creation.
    final bool needsProfileFetch = !isMine && (offer.userAvatarUrl.isEmpty || offer.userDisplayName == offer.userId);
    final offerUserProfileAsync = needsProfileFetch 
        ? ref.watch(userProfileProviderFamily(offer.userId))
        : null; // Don't watch if not needed


    // Determine display name and avatar URL
    String finalDisplayName = offer.userDisplayName;
    String finalAvatarUrl = offer.userAvatarUrl;

    if (offerUserProfileAsync != null) {
      offerUserProfileAsync.whenData((profile) {
        if (profile != null) {
          finalDisplayName = profile.username ?? offer.userDisplayName; // Prefer fetched, fallback to offer's stored
          finalAvatarUrl = profile.profilePicture ?? offer.userAvatarUrl; // Prefer fetched, fallback to offer's stored
        }
      });
      // Note: We're not showing loading/error states here to keep the bubble clean.
      // It will just use the offer.userDisplayName/userAvatarUrl until profile loads.
      // For a more explicit loading state, the .when() would need to wrap more of the UI.
    }
    
    // Fallback for avatar character if display name is empty or just an ID
    final String displayChar = finalDisplayName.isNotEmpty && finalDisplayName != offer.userId 
                              ? finalDisplayName[0].toUpperCase() 
                              : (offer.userId.isNotEmpty ? offer.userId[0].toUpperCase() : "?");


    final replyService = ref.watch(supabaseReplyServiceProvider);

    final Color userBubbleColorLight =
        theme.colorScheme.primaryContainer;
    final Color userBubbleColorDark =
        theme.colorScheme.primaryContainer; // Use theme color
    final Color otherBubbleColorLight =
        theme.colorScheme.surfaceVariant;
    final Color otherBubbleColorDark = theme.colorScheme.surfaceVariant; // Use theme color
    final Color userBubbleTextColorLight = theme.colorScheme.onPrimaryContainer;
    final Color userBubbleTextColorDark = theme.colorScheme.onPrimaryContainer; // Use theme color
    final Color otherBubbleTextColorLight = theme.colorScheme.onSurfaceVariant;
    final Color otherBubbleTextColorDark = theme.colorScheme.onSurfaceVariant; // Use theme color

    final bubbleColor = isMine
        ? (isDark ? userBubbleColorDark : userBubbleColorLight)
        : (isDark ? otherBubbleColorDark : otherBubbleColorLight);
    final textColor = isMine
        ? (isDark ? userBubbleTextColorDark : userBubbleTextColorLight)
        : (isDark ? otherBubbleTextColorDark : otherBubbleTextColorLight);

    final displayNameColor =
        isDark ? theme.colorScheme.onSurface : theme.colorScheme.primary;
    final avatarBackgroundColor =
        isDark ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.secondaryContainer;
    final avatarForegroundColor =
        isDark ? theme.colorScheme.onSurface : theme.colorScheme.onSecondaryContainer;
    final rateBadgeBackgroundColorIsMine = isDark
        ? theme.colorScheme.onPrimaryContainer.withOpacity(0.2)
        : theme.colorScheme.surface.withOpacity(0.2);
    final rateBadgeBackgroundColorOther = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.secondaryContainer.withOpacity(0.5);
    final rateBadgeTextColorIsMine =
        isDark ? theme.colorScheme.onPrimaryContainer.withOpacity(0.85) : theme.colorScheme.onSurface;
    final rateBadgeTextColorOther =
        isDark ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSecondaryContainer;
    final timestampColorIsMine = isDark
        ? theme.colorScheme.onPrimaryContainer.withOpacity(0.7)
        : theme.textTheme.bodySmall?.color?.withOpacity(0.7);
    final timestampColorOther = isDark
        ? theme.colorScheme.onSurfaceVariant.withOpacity(0.7)
        : theme.textTheme.bodySmall?.color?.withOpacity(0.7);

    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          );

    return GestureDetector(
      onLongPress: () => _showActionBox(context),
      child: Opacity(
        opacity: isOfferEffectivelyAccepted && !isMine ? 0.7 : 1.0, // Slightly dim accepted offers for others
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: align,
            child: Container(
              margin: EdgeInsets.only(
                left: isMine ? 60 : 12,
                right: isMine ? 12 : 60,
                top: 4,
                bottom: 2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    CircleAvatar(
                      backgroundColor: avatarBackgroundColor,
                      foregroundColor: avatarForegroundColor,
                        backgroundImage: finalAvatarUrl.isNotEmpty // Use finalAvatarUrl
                            ? NetworkImage(finalAvatarUrl)
                          : null,
                        child: finalAvatarUrl.isEmpty // Use finalAvatarUrl
                            ? Text(displayChar) // Use calculated displayChar
                          : null,
                    ),
                  if (!isMine) const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMine)
                            Text(finalDisplayName, // Use finalDisplayName
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: displayNameColor)),
                        if (!isMine) const SizedBox(height: 2),
                        Text(offer.message,
                            style: TextStyle(color: textColor, fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: isMine
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (offer.rate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? rateBadgeBackgroundColorIsMine
                                      : rateBadgeBackgroundColorOther,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${offer.rate}%',
                                  style: TextStyle(
                                    color: isMine
                                        ? rateBadgeTextColorIsMine
                                        : rateBadgeTextColorOther,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (offer.rate != null) const SizedBox(width: 8),
                              Row(
                                children: [
                            Text(
                              DateFormat('HH:mm').format(offer.createdAt),
                              style: TextStyle(
                                color: isMine
                                    ? timestampColorIsMine
                                    : timestampColorOther,
                                fontSize: 12,
                              ),
                              textAlign:
                                  isMine ? TextAlign.right : TextAlign.left,
                                  ),
                                  if (isOfferEffectivelyAccepted)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Icon(
                                        Icons.check_circle_outline,
                                        color: isMine ? timestampColorIsMine : Colors.green,
                                        size: 14,
                                      ),
                                    ),
                                ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<List<Reply>>(
              stream: replyService.getRepliesStream(offer.id),
            builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData && !snapshot.hasError) {
                  return const SizedBox.shrink(); 
              }
                
                if (snapshot.hasError) {
                  print('OfferBubble: Error in replies stream for ${offer.id}: ${snapshot.error}');
                return const SizedBox.shrink();
              }

                final replies = snapshot.data ?? [];

                if (replies.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                    return const SizedBox.shrink();
                }
                
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: replies
                    .map((reply) => ReplyBubble(
                          reply: reply,
                          offerType: offer.type,
                          isOfferOwner: isMine,
                            isOfferAccepted: isOfferEffectivelyAccepted, // Pass this down
                          onAcceptReply: isMine &&
                                    offer.status != 'accepted' && // Offer not yet accepted
                                    reply.status == 'pending'    // Reply is pending
                              ? () {
                                  if (onAcceptOfferReply != null) {
                                    onAcceptOfferReply!(offer, reply);
                                  }
                                }
                              : null,
                        ))
                    .toList(),
              );
            },
          ),
        ],
        ),
      ),
    );
  }
}

class OfferInputBar extends StatelessWidget {
  final String message;
  final VoidCallback onTap;
  final VoidCallback? onSend;
  final bool canSend;

  const OfferInputBar({
    Key? key,
      required this.message,
      required this.onTap,
      this.onSend,
    required this.canSend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                  ),
                  child: Text(
                    message.isEmpty ? 'Tap to create an offer...' : message,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.send, color: canSend ? theme.colorScheme.primary : theme.disabledColor),
              onPressed: canSend ? onSend : null,
            ),
          ],
        ),
      ),
    );
  }
}

class CustomAnimatedPanel extends StatefulWidget {
  final String offerType;
  final String currentAmountRaw;
  final String currentRateRaw;
  final double walletBalance;
  final Function(String) onTypeSelected;
  final Function(String) onAmountChanged;
  final Function(String) onRateChanged;
  final VoidCallback? onBack;
  final VoidCallback? onClear;
  final VoidCallback onClose;
  final TextEditingController amountController;
  final TextEditingController rateController;

  const CustomAnimatedPanel({
    Key? key,
    required this.offerType,
    required this.currentAmountRaw,
    required this.currentRateRaw,
    required this.walletBalance,
    required this.onTypeSelected,
    required this.onAmountChanged,
    required this.onRateChanged,
    this.onBack,
    this.onClear,
    required this.onClose,
    required this.amountController,
    required this.rateController,
  }) : super(key: key);

  @override
  State<CustomAnimatedPanel> createState() => _CustomAnimatedPanelState();
}

class _CustomAnimatedPanelState extends State<CustomAnimatedPanel> {
  final _formKey = GlobalKey<FormState>();
  FocusNode? _amountFocusNode;
  FocusNode? _rateFocusNode;

  @override
  void initState() {
    super.initState();
    _amountFocusNode = FocusNode();
    _rateFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _amountFocusNode?.dispose();
    _rateFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final ThemeData theme = Theme.of(context);

    return Material(
      elevation: 16,
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SingleChildScrollView(
        child: Form(
          key: _formKey,
              child: Column(
            mainAxisSize: MainAxisSize.min,
                children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                    children: [
                      Text('Build Offer',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              fontSize: 18)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: theme.colorScheme.onSurface, size: 32),
                      onPressed: widget.onClose,
                      ),
                    ],
                  ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ChoiceChip(
                        label: Text(
                          'Need RMB',
                          style: TextStyle(
                                      color: widget.offerType == 'Need RMB'
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                                  selected: widget.offerType == 'Need RMB',
                                  onSelected: (_) => widget.onTypeSelected('Need RMB'),
                        showCheckmark: false,
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.7)),
                      ),
                      ChoiceChip(
                        label: Text(
                          'Need FCFA',
                          style: TextStyle(
                                      color: widget.offerType == 'Need FCFA'
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                                  selected: widget.offerType == 'Need FCFA',
                                  onSelected: (_) => widget.onTypeSelected('Need FCFA'),
                        showCheckmark: false,
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.7)),
                      ),
                      ChoiceChip(
                        label: Text(
                          'RMB available',
                          style: TextStyle(
                                      color: widget.offerType == 'RMB available'
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                                  selected: widget.offerType == 'RMB available',
                                  onSelected: (_) => widget.onTypeSelected('RMB available'),
                        showCheckmark: false,
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.7)),
                      ),
                    ],
                  ),
                        if (widget.offerType.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                            widget.offerType == 'RMB available'
                          ? 'Max Amount and Rate'
                          : 'Amount and Rate',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 6),
                    Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                                child: TextFormField(
                                  controller: widget.amountController,
                                  focusNode: _amountFocusNode,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                                    hintText: (widget.offerType == 'RMB available' ||
                                            widget.offerType == 'Need FCFA')
                                        ? 'Amount in RMB' 
                                        : (widget.offerType == 'Need RMB'
                                            ? 'Amount in FCFA' 
                                      : 'Enter amount'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: widget.onAmountChanged,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Amount required';
                                    }
                                    final val = double.tryParse(value);
                                    if (val == null) return 'Invalid number';
                                    if (val <= 0) return 'Must be > 0';
                                    if ((widget.offerType == 'RMB available' || widget.offerType == 'Need FCFA') && val > 5000) {
                                      return 'Max 5000 RMB';
                                    }
                                    if (widget.offerType == 'Need RMB' && widget.walletBalance > 0 && val > widget.walletBalance) {
                                      return 'Max ${widget.walletBalance.toStringAsFixed(0)} FCFA';
                                    }
                                    return null; 
                                  },
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                                child: TextFormField(
                                  controller: widget.rateController,
                                  focusNode: _rateFocusNode,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                                    hintText: widget.offerType == 'RMB available'
                                        ? 'Rate (e.g. 5 for 5%)'
                                        : 'Rate (Optional)',
                                    suffixText: '%',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: widget.onRateChanged,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      if (widget.offerType == 'RMB available') return 'Rate required';
                                      return null;
                                    }
                                    final val = double.tryParse(value);
                                    if (val == null) return 'Invalid rate';
                                    if (val <= 0) return 'Rate must be > 0';
                                    if (val > 20) return 'Max rate is 20%';
                                    return null;
                                  },
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
              ),
              // Bottom buttons
              Padding(
                padding: EdgeInsets.only(
                  left: 20,
            right: 20,
            bottom: 20 + bottomInset,
                ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                      if (widget.onBack != null)
                  ElevatedButton.icon(
                    icon: Icon(Icons.arrow_back,
                        color: theme.colorScheme.primary),
                    label: Text('Back',
                        style: TextStyle(color: theme.colorScheme.primary)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      elevation: 0,
                      side: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.5)),
                    ),
                          onPressed: widget.onBack,
                  ),
                const SizedBox(width: 8),
                      if (widget.onClear != null)
                  ElevatedButton.icon(
                    icon: Icon(Icons.clear, color: theme.colorScheme.error),
                    label: Text('Clear',
                        style: TextStyle(color: theme.colorScheme.error)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      elevation: 0,
                      side: BorderSide(
                          color: theme.colorScheme.error.withOpacity(0.5)),
                    ),
                          onPressed: widget.onClear,
                  ),
              ],
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}
