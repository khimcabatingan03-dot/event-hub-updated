import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // register new student
  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
    required String studentNumber,
  }) async {
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // save the full name to the account
    await result.user!.updateDisplayName(name);
    // also save the student info in Firestore
    // (the name is passed in directly, because the user object still
    //  returns the empty name it had when the account was created)
    await saveUserToFirestore(result.user!,
        studentNumber: studentNumber, name: name);
    return result;
  }

  // login
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    UserCredential result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // refresh the student info in Firestore — this also fills in the
    // empty "name" left behind by older sign-ups
    await saveUserToFirestore(result.user!);
    return result;
  }

  // login using a Google account
  Future<UserCredential?> signInWithGoogle() async {
    // ask the user to pick a Google account
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    // user cancelled the picker
    if (googleUser == null) return null;

    // get the login details from Google
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // use them to sign in to Firebase
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential result = await _auth.signInWithCredential(credential);

    // save the student info in Firestore (only the first time)
    await saveUserToFirestore(result.user!);

    return result;
  }

  // save / update the student info in the users collection
  // (the document id is the readable email, so the console stays clean;
  //  accounts without an email fall back to the account id)
  Future<void> saveUserToFirestore(User user,
      {String studentNumber = '', String name = ''}) async {
    String email = (user.email ?? '').toLowerCase().trim();
    String id = email.contains('@') ? email : user.uid;

    String displayName = name.isNotEmpty ? name : (user.displayName ?? '');

    Map<String, dynamic> data = {
      'name': displayName,
      'email': user.email ?? '',
      'photo': user.photoURL ?? '',
      'lastLogin': Timestamp.now(),
    };

    // only touch the student number when we actually have one,
    // so a plain login never wipes the saved value
    if (studentNumber.isNotEmpty) {
      data['studentNumber'] = studentNumber;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .set(data, SetOptions(merge: true));
  }

  // logout
  Future<void> logout() async {
    await _auth.signOut();
    // also sign out of Google so the picker remembers nothing
    await GoogleSignIn().signOut();
  }
}
