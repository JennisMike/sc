import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_reply_service.dart';
 
// Provider for the SupabaseReplyService instance
final supabaseReplyServiceProvider = Provider<SupabaseReplyService>((ref) {
  return SupabaseReplyService();
}); 