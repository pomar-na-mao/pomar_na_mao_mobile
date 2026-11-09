import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/authentication_repository.dart';

abstract interface class AuthenticationRemoteDataSource {
  bool get hasActiveSession;

  Future<void> signIn({required String email, required String password});
}

class SupabaseAuthenticationRemoteDataSource
    implements AuthenticationRemoteDataSource {
  const SupabaseAuthenticationRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  bool get hasActiveSession => _client.auth.currentSession != null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        throw const AuthenticationFailure(
          'Não foi possível iniciar uma sessão autenticada.',
        );
      }
    } on AuthException catch (error) {
      throw AuthenticationFailure(_friendlyMessage(error.message));
    } on AuthenticationFailure {
      rethrow;
    } catch (_) {
      throw const AuthenticationFailure(
        'Não foi possível autenticar. Verifique sua conexão e tente novamente.',
      );
    }
  }
}

String _friendlyMessage(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('invalid login credentials') ||
      normalized.contains('invalid credentials')) {
    return 'E-mail ou senha inválidos.';
  }
  if (normalized.contains('email not confirmed')) {
    return 'Confirme seu e-mail antes de entrar.';
  }
  if (normalized.contains('rate limit') || normalized.contains('too many')) {
    return 'Muitas tentativas. Aguarde um momento e tente novamente.';
  }
  return 'Não foi possível autenticar. Verifique os dados e tente novamente.';
}
