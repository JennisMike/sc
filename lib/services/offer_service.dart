import 'package:rxdart/rxdart.dart';
import '../models/offer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfferService {
  List<Offer> _cachedOffers = [];
  final BehaviorSubject<List<Offer>> _offersSubject = BehaviorSubject<List<Offer>>.seeded([]);
  final _supabase = Supabase.instance.client;

  Stream<List<Offer>> get offersStream => _offersSubject.stream;

  OfferService();

  Future<void> init() async {
    await fetchAndLoadOffers();
  }

  Future<void> fetchAndLoadOffers() async {
    try {
      final response = await _supabase
          .from('offers')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);
      final List<Offer> fetchedOffers = (response as List)
          .map((obj) => Offer.fromMap(obj))
          .toList();
      _cachedOffers = fetchedOffers;
      _offersSubject.add(List.unmodifiable(_cachedOffers));
    } catch (e) {
      print('Exception in fetchAndLoadOffers: $e');
      _offersSubject.addError(e);
    }
  }

  Future<Offer> createOffer({
    required String userId,
    required String userDisplayName,
    required String userAvatarUrl,
    required String type,
    required double amount,
    double? rate,
    required String message,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'user_display_name': userDisplayName,
        'user_avatar_url': userAvatarUrl,
        'type': type,
        'amount': amount,
        'rate': rate,
        'message': message,
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      };
      final response = await _supabase
          .from('offers')
          .insert(data)
          .select()
          .single();
      final newOffer = Offer.fromMap(response);
      _cachedOffers.insert(0, newOffer);
      _offersSubject.add(List.unmodifiable(_cachedOffers));
      return newOffer;
    } catch (e) {
      print('Exception when creating offer: $e');
      throw Exception('Failed to create offer: $e');
    }
  }

  Future<void> updateOfferStatus(String offerId, String newStatus, {String? acceptedByUserId}) async {
    try {
      final updateData = {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (newStatus == 'accepted' && acceptedByUserId != null) {
        updateData['accepted_by_user_id'] = acceptedByUserId;
        updateData['accepted_at'] = DateTime.now().toIso8601String();
      }
      final response = await _supabase
          .from('offers')
          .update(updateData)
          .eq('id', offerId)
          .select()
          .single();
      final index = _cachedOffers.indexWhere((offer) => offer.id == offerId);
      if (index != -1) {
        final updatedOffer = _cachedOffers[index].copyWith(
          status: newStatus,
          acceptedByUserId: acceptedByUserId,
          acceptedAt: newStatus == 'accepted' ? DateTime.now() : null,
        );
        _cachedOffers[index] = updatedOffer;
        _offersSubject.add(List.unmodifiable(_cachedOffers));
      }
    } catch (e) {
      print('Error updating offer status: $e');
      throw Exception('Failed to update offer status: $e');
    }
  }

  void dispose() {
    _offersSubject.close();
  }
} 