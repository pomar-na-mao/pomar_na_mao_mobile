abstract interface class AuthenticationRepository {
  bool get isAuthenticated;

  Future<void> signIn({required String email, required String password});
}

class AuthenticationFailure implements Exception {
  const AuthenticationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
