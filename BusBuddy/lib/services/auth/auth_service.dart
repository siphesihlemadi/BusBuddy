import 'auth_provider.dart';
import 'auth_user.dart';
import 'firebase_auth_provider.dart';

class AuthService implements AuthProvider {
  final AuthProvider provider;
  const AuthService(this.provider);

  factory AuthService.firebase() => AuthService(FirebaseAuthProvider());

  @override
  Future<AuthUser?> createUser({
    required String fullName,
    required String email,
    required String password,
  }) =>
      provider.createUser(
        fullName: fullName,
        email: email,
        password: password,
      );
  @override
  AuthUser? get currentUser => provider.currentUser;

  @override
  Future<AuthUser?> logIn({
    required String email,
    required String password,
  }) =>
      provider.logIn(
        email: email,
        password: password,
      );

  @override
  Future<void> logOut() => provider.logOut();

  @override
  Future<void> sendEmailVerification() => provider.sendEmailVerification();

  @override
  Future<void> initialize() => provider.initialize();

  @override
  Future<void> deleteUser({required String password}) =>
      provider.deleteUser(password: password);

  @override
  Future<void> resetPassword({required String email}) =>
      provider.resetPassword(email: email);
}
