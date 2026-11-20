import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class OriginAuthService {
  OriginAuthService._();

  static final instance = OriginAuthService._();
  final _auth = FirebaseAuth.instance;
  Future<void>? _googleSignInInitialization;

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

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    final current = _auth.currentUser;

    if (kIsWeb) {
      if (current?.isAnonymous == true) {
        await current!.linkWithPopup(provider);
      } else {
        await _auth.signInWithPopup(provider);
      }
      return;
    }

    _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
    await _googleSignInInitialization;
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    if (current?.isAnonymous == true) {
      await current!.linkWithCredential(credential);
    } else {
      await _auth.signInWithCredential(credential);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}
