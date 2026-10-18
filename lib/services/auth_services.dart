import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_store.dart';

// thrown by setEventHubPassword with a message that is safe to show
class PasswordSetupException implements Exception {
  PasswordSetupException(this.message);
  final String message;

  @override
  String toString() => message;
}

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
        studentNumber: studentNumber, name: name, hasPassword: true);
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
    // empty "name" left behind by older sign-ups and remembers that
    // this account can log in with a password
    await saveUserToFirestore(result.user!, hasPassword: true);
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
    // — a brand new Google account is flagged as "no password yet",
    // existing profiles are never changed here
    bool alreadySaved = (await _readProfile(result.user!)).isNotEmpty;
    await saveUserToFirestore(
      result.user!,
      hasPassword: alreadySaved ? null : false,
    );

    return result;
  }

  // ------------------------------------------------------------
  // PROFILE COMPLETION (used after Google sign-in)
  // ------------------------------------------------------------

  // the document id used by older versions of the app (the email
  // address) — kept so nothing saved back then gets lost
  String _oldProfileId(User user) {
    String email = (user.email ?? '').toLowerCase().trim();
    return email.contains('@') ? email : '';
  }

  // read the profile of this student: the old email document first,
  // then the document keyed by the account id on top of it (the newer
  // one wins, but an empty value never wipes what was already saved)
  Future<Map<String, dynamic>> _readProfile(User user) async {
    CollectionReference users = FirebaseFirestore.instance.collection('users');

    Map<String, dynamic> data = {};

    String oldId = _oldProfileId(user);
    if (oldId.isNotEmpty) {
      DocumentSnapshot old = await users.doc(oldId).get();
      if (old.exists) data = Map<String, dynamic>.from(old.data() as Map);
    }

    DocumentSnapshot current = await users.doc(user.uid).get();
    if (current.exists) {
      Map<String, dynamic> newer = Map<String, dynamic>.from(current.data() as Map);
      newer.forEach((key, value) {
        bool empty = value == null || value.toString().trim().isEmpty;
        if (!empty) data[key] = value;
      });
    }

    return data;
  }

  // does the student already have a saved profile with a Student ID?
  // (returning users skip the profile form, new Google users don't)
  Future<bool> hasCompletedProfile(User user) async {
    Map<String, dynamic> data = await _readProfile(user);
    String studentNumber = (data['studentNumber'] ?? '').toString().trim();
    return studentNumber.isNotEmpty;
  }

  // does this email belong to an account that has no password login?
  // (Google-created accounts can only use "Continue with Google"
  //  until an EventHub password is added — the profile remembers
  //  whether a password exists, see saveUserToFirestore)
  Future<bool> isGoogleOnlyAccount(String email) async {
    String normalized = email.trim().toLowerCase();
    if (!normalized.contains('@')) return false;

    // the profile is keyed by the account id now, so the student is
    // searched for through the email address saved in the profile
    QuerySnapshot profiles =
        await FirebaseFirestore.instance.collection('users').get();

    for (DocumentSnapshot doc in profiles.docs) {
      Map<String, dynamic> data = Map<String, dynamic>.from(doc.data() as Map);
      String saved = (data['email'] ?? '').toString().trim().toLowerCase();
      if (saved == normalized || doc.id.toLowerCase() == normalized) {
        return data['hasPassword'] != true;
      }
    }
    return false; // no account saved for this email
  }

  // ------------------------------------------------------------
  // EVENTHUB PASSWORD FOR GOOGLE-CREATED ACCOUNTS
  // ------------------------------------------------------------

  // true when the signed in student uses Google only and has no
  // EventHub password yet (they can add one to use email/password too)
  bool currentUserNeedsPassword() {
    User? user = _auth.currentUser;
    if (user == null) return false;
    List<String> providers =
        user.providerData.map((info) => info.providerId).toList();
    return providers.contains('google.com') &&
        !providers.contains('password');
  }

  // set an EventHub password on an existing Google-created account.
  // Security: the student proves ownership with Google first (we never
  // ask for or store their Google password), then the new EventHub
  // password is saved to the same Firebase account — so no duplicate
  // account is created and both login methods work.
  Future<void> setEventHubPassword({
    required String expectedEmail,
    required String newPassword,
  }) async {
    String wanted = expectedEmail.trim().toLowerCase();

    // 1) confirm who the student is with Google
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw PasswordSetupException(
          'Google confirmation was cancelled. Nothing was changed.');
    }
    if (googleUser.email.trim().toLowerCase() != wanted) {
      throw PasswordSetupException(
          'That Google account does not match $wanted. Try again with the Google account you used for EventHub.');
    }

    // 2) fresh Google credentials for a secure re-check
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    User user;
    User? current = _auth.currentUser;
    if (current == null ||
        (current.email ?? '').trim().toLowerCase() != wanted) {
      // not signed in yet (or signed in as someone else):
      // sign in with the confirmed Google account
      UserCredential result = await _auth.signInWithCredential(credential);
      user = result.user!;
    } else {
      // already signed in: re-check the login before changing anything
      user = current;
      await user.reauthenticateWithCredential(credential);
    }

    // 3) save the new EventHub password (never the Google password)
    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);
      } else {
        rethrow;
      }
    }

    // remember that this account can now log in with a password too
    await saveUserToFirestore(user, hasPassword: true);
  }

  // save / update the student info in the users collection
  // (the document id is the account id / uid, so the console shows the
  //  same id that the registrations use; data that an older version
  //  saved under the email address is moved over first)
  Future<void> saveUserToFirestore(User user,
      {String studentNumber = '',
      String name = '',
      bool? hasPassword}) async {
    String email = (user.email ?? '').toLowerCase().trim();
    CollectionReference users = FirebaseFirestore.instance.collection('users');

    // 1) start with the profile that is already saved for this student:
    //    the document under the account id, plus the profile an older
    //    version saved under the email address. Starting from what is
    //    already there means a plain login never wipes the student
    //    number, the name or the password flag that was saved before
    Map<String, dynamic> data = await _readProfile(user);

    // 2) write the current info on top of it
    String displayName = name.isNotEmpty ? name : (user.displayName ?? '');
    if (displayName.trim().isEmpty) {
      displayName = (data['name'] ?? '').toString();
    }

    String savedPhoto = (data['photo'] ?? '').toString();
    String newPhoto = user.photoURL ?? '';
    String newEmail = user.email ?? '';

    data['name'] = displayName;
    data['email'] = newEmail.isNotEmpty ? newEmail : (data['email'] ?? '');
    data['photo'] = newPhoto.isNotEmpty ? newPhoto : savedPhoto;
    data['uid'] = user.uid;
    data['lastLogin'] = Timestamp.now();

    // only touch the student number when we actually have one,
    // so a plain login never wipes the saved value
    if (studentNumber.isNotEmpty) {
      data['studentNumber'] = studentNumber;
    }

    // remember whether this account can log in with a password
    // (null = leave the stored value alone)
    if (hasPassword != null) {
      data['hasPassword'] = hasPassword;
    }

    // 3) save it under the account id, then remove the old document so
    //    the same profile is not saved twice
    await users.doc(user.uid).set(data);

    if (email.isNotEmpty && email != user.uid) {
      DocumentSnapshot old = await users.doc(email).get();
      if (old.exists) await old.reference.delete();
    }
  }

  // logout
  Future<void> logout() async {
    await _auth.signOut();
    // also sign out of Google so the picker remembers nothing
    await GoogleSignIn().signOut();
    // forget the in-memory notification list (saved data stays
    // on the device and comes back for the same student)
    NotificationStore.instance.reset();
  }
}
