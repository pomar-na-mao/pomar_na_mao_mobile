import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/auth/domain/authentication_repository.dart';
import 'package:pomar_na_mao_mobile/features/auth/presentation/authentication_view_model.dart';

class _FakeAuthenticationRepository implements AuthenticationRepository {
  bool authenticated = false;
  bool fail = false;
  String? receivedEmail;
  String? receivedPassword;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Future<void> signIn({required String email, required String password}) async {
    receivedEmail = email;
    receivedPassword = password;
    if (fail) {
      throw const AuthenticationFailure('E-mail ou senha inválidos.');
    }
    authenticated = true;
  }
}

void main() {
  test('validates credentials before calling the repository', () async {
    final repository = _FakeAuthenticationRepository();
    final viewModel = AuthenticationViewModel(repository);
    addTearDown(viewModel.dispose);

    expect(await viewModel.signIn(email: 'inválido', password: ''), isFalse);
    expect(viewModel.error, 'Informe um e-mail válido.');
    expect(repository.receivedEmail, isNull);
  });

  test('authenticates and exposes the active session', () async {
    final repository = _FakeAuthenticationRepository();
    final viewModel = AuthenticationViewModel(repository);
    addTearDown(viewModel.dispose);

    expect(
      await viewModel.signIn(
        email: ' operador@pomar.com ',
        password: 'segredo',
      ),
      isTrue,
    );
    expect(viewModel.isAuthenticated, isTrue);
    expect(repository.receivedEmail, 'operador@pomar.com');
    expect(repository.receivedPassword, 'segredo');
    expect(viewModel.error, isNull);
  });

  test('keeps authentication errors available for the dialog', () async {
    final repository = _FakeAuthenticationRepository()..fail = true;
    final viewModel = AuthenticationViewModel(repository);
    addTearDown(viewModel.dispose);

    expect(
      await viewModel.signIn(
        email: 'operador@pomar.com',
        password: 'incorreta',
      ),
      isFalse,
    );
    expect(viewModel.error, 'E-mail ou senha inválidos.');
    expect(viewModel.authenticating, isFalse);
  });
}
