import 'package:flutter_riverpod/flutter_riverpod.dart';
 
// This provider will track if the initial loading animation and data fetch
// for the MarketplaceScreen has completed once in the app's lifecycle (for this session).
final marketplaceInitialLoadDoneProvider = StateProvider<bool>((ref) => false); 