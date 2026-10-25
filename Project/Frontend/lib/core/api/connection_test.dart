// ignore_for_file: avoid_print

import 'api_client.dart';

Future<void> testConnection() async {
  final api = ApiClient(); // your client
  final res = await api.get('/api/health', auth: false);
  print(' BACKEND OK: $res');
}
