import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Returns current logged-in user (null if guest)
  User? get currentUser => _auth.currentUser;

  /// ✅ Real-time listener for login/logout/auth changes
  Stream<User?> authStateChanges() => _auth.idTokenChanges();

  // ──────────────────────────────────────────────
  // EMAIL & PASSWORD AUTH
  // ──────────────────────────────────────────────

  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.getIdToken(true);
    return credential;
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _auth.currentUser?.getIdToken(true);
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(name);
      await user.reload();
      await _auth.currentUser?.getIdToken(true);
    }
  }

  Future<void> reauthenticate(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  // ──────────────────────────────────────────────
  // GOOGLE SIGN-IN AUTH
  // ──────────────────────────────────────────────

  Future<User?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('Missing Google authentication tokens.');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();

        if (!doc.exists) {
          await docRef.set({
            'uid': user.uid,
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'phone': user.phoneNumber ?? '',
            'photoUrl': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'role': 'student',
            'premium': false,
          });
        }
      }

      return user;
    } catch (e) {
      throw Exception("Google Sign-In failed: ${e.toString()}");
    }
  }

  // ──────────────────────────────────────────────
  // PHONE AUTH (OTP LOGIN)
  // ──────────────────────────────────────────────

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(String error) onFailed,
    required Function() codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      // ✅ Safely detach from widget context (no rebuild crashes)
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            onFailed('Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onFailed(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          // ✅ ensure safe callback
          Future.microtask(() => codeSent(verificationId));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          Future.microtask(() => codeAutoRetrievalTimeout());
        },
      );
    } catch (e) {
      onFailed(e.toString());
    }
  }

  Future<UserCredential> signInWithOTP(
      String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: smsCode);
      final result = await _auth.signInWithCredential(credential);
      await result.user?.getIdToken(true);
      await result.user?.reload();
      return result;
    } catch (e) {
      throw Exception('OTP verification failed: $e');
    }
  }
}
