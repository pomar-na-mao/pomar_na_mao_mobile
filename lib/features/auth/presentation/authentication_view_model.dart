import 'package:flutter/foundation.dart';

import '../domain/authentication_repository.dart';

class AuthenticationViewModel extends ChangeNotifier {
  AuthenticationViewModel(this._repository);

  final AuthenticationRepository _repository;

  bool _authenticating = false;
  String? _error;

  bool get isAuthenticated => _repository.isAuthenticated;
  bool get authenticating => _authenticating;
  String? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      _setError('Informe um e-mail válido.');
      return false;
    }
    if (password.isEmpty) {
      _setError('Informe a senha.');
      return false;
    }

    _authenticating = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.signIn(email: normalizedEmail, password: password);
      if (!_repository.isAuthenticated) {
        _error = 'Não foi possível iniciar uma sessão autenticada.';
        return false;
      }
      return true;
    } on AuthenticationFailure catch (failure) {
      _error = failure.message;
      return false;
    } catch (_) {
      _error = 'Não foi possível autenticar. Verifique sua conexão e tente novamente.';
      return false;
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
