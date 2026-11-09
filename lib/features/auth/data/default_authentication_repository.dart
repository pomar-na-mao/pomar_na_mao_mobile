import '../domain/authentication_repository.dart';
import 'authentication_remote_data_source.dart';

class DefaultAuthenticationRepository implements AuthenticationRepository {
  const DefaultAuthenticationRepository(this._remoteDataSource);

  final AuthenticationRemoteDataSource _remoteDataSource;

  @override
  bool get isAuthenticated => _remoteDataSource.hasActiveSession;

  @override
  Future<void> signIn({required String email, required String password}) =>
      _remoteDataSource.signIn(email: email, password: password);
}
