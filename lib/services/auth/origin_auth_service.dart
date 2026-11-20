import 'package:firebase_auth/firebase_auth.dart';

class OriginAuthService {
  OriginAuthService._();

  static final instance = OriginAuthService._();
  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> createAccount(String email, String password) async {
    final current = _auth.currentUser;
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    if (current?.isAnonymous == true) {
      await current!.linkWithCredential(credential);
    } else {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}
