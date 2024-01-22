import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

final firebaseAuthInstance = FirebaseAuth.instance;
final firebaseFirestoreInstance = FirebaseFirestore.instance;

class Auth extends StatefulWidget {
  const Auth({Key? key}) : super(key: key);

  @override
  _AuthState createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  final _formKey = GlobalKey<FormState>();
  var _isLogin = true;
  var _email = '';
  var _password = '';
  var _username = '';

  void _submit() async {
    _formKey.currentState!.save();

    if (_isLogin) {
      // Giriş Sayfası
      try {
        final userCredentials = await firebaseAuthInstance
            .signInWithEmailAndPassword(email: _email, password: _password);
        print(userCredentials);
      } on FirebaseAuthException catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message ?? "Giriş Başarısız")));
      }
    } else {
      // Kayıt Sayfası
      try {
        final userCredentials = await firebaseAuthInstance
            .createUserWithEmailAndPassword(email: _email, password: _password);
        print(userCredentials);
        firebaseFirestoreInstance
            .collection("users")
            .doc(userCredentials.user!.uid)
            .set({'email': _email, 'name': _username, 'imageUrl': null});
      } on FirebaseAuthException catch (error) {
        // Hata mesajı göster..
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message ?? "Kayıt başarısız.")));
      }
    }
  }

  void signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth =
          await googleUser!.authentication;
      final googleCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth!.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await firebaseAuthInstance.signInWithCredential(googleCredential);
      print(userCredential);

      // Google'dan gelen kullanıcı bilgilerini Firestore'a kaydetmek
      firebaseFirestoreInstance
          .collection("users")
          .doc(userCredential.user!.uid)
          .set({
        'email': userCredential.user!.email,
        'name': userCredential.user!.displayName, // Kullanıcının adını alıyoruz
        'imageUrl': userCredential
            .user!.photoURL, // Kullanıcının profil resmini alıyoruz
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                color: Color.fromARGB(115, 55, 219, 225),
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: "E-posta"),
                          autocorrect: false,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {},
                          onSaved: (newValue) {
                            _email = newValue!;
                          },
                        ),
                        TextFormField(
                          decoration: const InputDecoration(labelText: "Şifre"),
                          autocorrect: false,
                          obscureText: true,
                          onSaved: (newValue) {
                            _password = newValue!;
                          },
                        ),
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: "Kullanıcı Adı"),
                          onSaved: (newValue) {
                            _username = newValue!;
                          },
                        ),
                        SizedBox(
                          height: 25,
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _submit();
                          },
                          child: Text(_isLogin ? "Giriş Yap" : "Kayıt Ol"),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                            });
                          },
                          child: Text(_isLogin
                              ? "Kayıt Sayfasına Git"
                              : "Giriş Sayfasına Git"),
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 35, right: 35),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Color.fromARGB(221, 255, 255, 255),
                            ),
                            onPressed: () {
                              signInWithGoogle();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  "assets/icon.png",
                                  width: 30,
                                  height: 30,
                                ),
                                Text("Google ile giriş yap"),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
