import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/profile_api.dart';
import '../../../core/storage/token_storage.dart';
import 'landing_view.dart';
import '../../profile/viewmodel/profile_viewmodel.dart';
import '../../../HomeShell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final TokenStorage _tokenStorage = TokenStorage();

  bool _checkingSession = true;
  bool _hasValidSession = false;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    try {
      final token = await _tokenStorage.readToken();

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        setState(() {
          _hasValidSession = false;
          _checkingSession = false;
        });

        return;
      }

      final apiClient = ApiClient();
      final profileApi = ProfileApi(apiClient);

      // Verify token with backend.
      await profileApi.getMyProfile();

      if (!mounted) return;

      // Load user profile into Provider.
      await context.read<ProfileViewModel>().loadProfile();

      if (!mounted) return;

      setState(() {
        _hasValidSession = true;
        _checkingSession = false;
      });
    } catch (_) {
      await _tokenStorage.clearToken();

      if (!mounted) return;

      setState(() {
        _hasValidSession = false;
        _checkingSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasValidSession) {
      return const HomeShell();
    }

    return const LandingView();
  }
}