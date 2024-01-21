import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase/models/message.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

final firebaseAuthInstance = FirebaseAuth.instance;
final firebaseStorageInstance = FirebaseStorage.instance;
final FirebaseFireStoreInstance = FirebaseFirestore.instance;
final fcm = FirebaseMessaging.instance;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final messageController = TextEditingController();
  final DateFormat formatter = DateFormat('hh:mm dd/MM/yyyy');
  File? _pickedFile;
  String? _imageUrl;
  DateTime? date;

  @override
  void initState() {
    _requestNotificationPermission();
    _getUserImage();
    super.initState();
  }

  void _requestNotificationPermission() async {
    NotificationSettings notificationSettings = await fcm.requestPermission();

    if (notificationSettings.authorizationStatus ==
        AuthorizationStatus.denied) {
      // bildirimlere izin verilmedi
    } else {
      String? token = await fcm.getToken();

      if (token == null) {
        // kullanıcıya bir uyarı göster..
      }
      _updateTokenInDb(token!);

      await fcm.subscribeToTopic("chat");

      fcm.onTokenRefresh.listen((token) {
        _updateTokenInDb(token);
      }).onError((error) {});
    }
  }

  void _updateTokenInDb(String token) async {
    await FirebaseFireStoreInstance.collection("users")
        .doc(firebaseAuthInstance.currentUser!.uid)
        .update({'fcm': token});
  }

  void _getUserImage() async {
    final user = firebaseAuthInstance.currentUser;
    final document =
        FirebaseFireStoreInstance.collection("users").doc(user!.uid);
    final docSnapshot = await document.get();
    setState(() {
      _imageUrl = docSnapshot.get("imageUrl");
    });
  }

  Future<String> _getUserEmail(String userId) async {
    final document = FirebaseFireStoreInstance.collection("users").doc(userId);
    final docSnapshot = await document.get();

    print(docSnapshot.get('email'));

    return docSnapshot.get('email');
  }

  Future<List<Message>> _getMessages() async {
    final document =
        await FirebaseFireStoreInstance.collection("messages").get();
    final messagesList = document.docs
        .map((e) => Message.fromJson(e.data()))
        .toList(); // mesajlar listesinin dokumentlerini mapleyerek jsonların datasını listelenmesini saglar.

    messagesList.sort(
      (a, b) {
        return a.date.compareTo(
            b.date); // a datasını compare et b ninki ile sıralar(karsılastır).
      }, //eğer a geçerli ise a yı işleme aldıktan sonra b yi işleme alır.
    );

    return messagesList;
  }

  void _pickImage() async {
    final image = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 150);

    if (image != null) {
      setState(() {
        _pickedFile = File(image.path);
      });
    }
  }

  void _upload() async {
    final user = firebaseAuthInstance.currentUser;
    final ref = firebaseStorageInstance.ref().child("images").child(
        "${user!.uid}.jpg"); // referansı storage instance ın ref in child değerine ulaşarak kontrol eder veriyi getirir.(resimi)

    await ref.putFile(
        _pickedFile!); // ref de tuttugun dosyasının picked file ina ulas.

    final url = await ref.getDownloadURL();
    final document =
        FirebaseFireStoreInstance.collection("users").doc(user.uid);
    await document.update({'imageUrl': url}); // fotograf güncelleme

    // document.update => verilen değeri ilgili dökümanda günceller!
  }

  void _submitMessage() async {
    //mesaj gönderme kısmı
    final user = firebaseAuthInstance.currentUser;
    date = DateTime.now();

    try {
      FirebaseFireStoreInstance.collection("messages").doc().set({
        'message': messageController.text,
        'date': date,
        'userId': user!.uid
      });
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message!)));
    }
    messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ChatApp",
          style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            onPressed: () {
              firebaseAuthInstance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      foregroundImage:
                          _imageUrl == null ? null : NetworkImage(_imageUrl!),
                    ),
                    TextButton(
                        onPressed: () {
                          _pickImage();
                        },
                        child: Text(
                          "Resim Seç",
                          style: TextStyle(
                              color: Color.fromARGB(255, 44, 154, 167),
                              fontWeight: FontWeight.bold),
                        )),
                    _pickedFile != null
                        ? ElevatedButton(
                            onPressed: () {
                              _upload();
                            },
                            child: Text("Resim Yükle"))
                        : Container(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: Color.fromARGB(255, 45, 216, 207),
                      border: Border.all(
                          width: 1, color: Color.fromARGB(255, 0, 0, 0)),
                      borderRadius: BorderRadius.circular(8.0)),
                  height: MediaQuery.of(context).size.height * 0.65,
                  width: MediaQuery.of(context).size.width * 0.90,
                  child: FutureBuilder(
                    future: _getMessages(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            if (snapshot.data![index].userId ==
                                firebaseAuthInstance.currentUser!.uid) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: 6, top: 6),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    width: MediaQuery.of(context).size.width *
                                        0.50,
                                    margin: EdgeInsets.all(4.0),
                                    padding: EdgeInsets.all(4.0),
                                    decoration: BoxDecoration(
                                        color:
                                            Color.fromARGB(255, 241, 238, 238),
                                        border: Border.all(
                                            width: 1, color: Colors.black),
                                        borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(8.0),
                                            topLeft: Radius.circular(8.0),
                                            bottomLeft: Radius.circular(8.0))),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Text(
                                              snapshot.data![index].message,
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(
                                                style: TextStyle(fontSize: 10),
                                                formatter
                                                    .format(DateTime
                                                        .fromMillisecondsSinceEpoch(
                                                            snapshot
                                                                .data![index]
                                                                .date
                                                                .millisecondsSinceEpoch))
                                                    .toString()),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(left: 6, top: 6),
                                  child: Container(
                                    width: MediaQuery.of(context).size.width *
                                        0.50,
                                    margin: EdgeInsets.all(3.0),
                                    padding: EdgeInsets.all(3.0),
                                    decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                            255, 223, 222, 222),
                                        border: Border.all(
                                            width: 1, color: Colors.black),
                                        borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(8.0),
                                            topLeft: Radius.circular(8.0),
                                            bottomRight: Radius.circular(8.0))),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            FutureBuilder(
                                              future: _getUserEmail(
                                                  snapshot.data![index].userId),
                                              builder: (context, value) {
                                                if (value.hasData) {
                                                  return Text(
                                                    value.data!,
                                                    style:
                                                        TextStyle(fontSize: 10),
                                                  );
                                                } else if (value.hasError) {
                                                  return Text(
                                                    "Yanlış bir şey var !",
                                                    style:
                                                        TextStyle(fontSize: 10),
                                                  );
                                                }
                                                return Text(
                                                  "Yükleniyor",
                                                  style:
                                                      TextStyle(fontSize: 10),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              snapshot.data![index].message,
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Text(
                                                style: TextStyle(fontSize: 10),
                                                formatter
                                                    .format(DateTime
                                                        .fromMillisecondsSinceEpoch(
                                                            snapshot
                                                                .data![index]
                                                                .date
                                                                .millisecondsSinceEpoch))
                                                    .toString()),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      } else if (snapshot.hasError) {
                        return const Text("Yanlış bir şey var !");
                      }
                      return const CircularProgressIndicator();
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(
                    20.0), // Daha büyük bir iç kenar boşluğu ekledik.
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        decoration: const InputDecoration(
                          hintText: 'Yeni bir mesaj girin...',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                width: 4.0,
                                color: Color.fromARGB(255, 45, 216, 207)),
                            borderRadius:
                                BorderRadius.all(Radius.circular(8.0)),
                          ),
                        ),
                        keyboardType: TextInputType
                            .text, // Klavye türünü metin olarak güncelledik.
                      ),
                    ),
                    SizedBox(
                      width: 5.0, // Daha büyük bir boşluk ekledik.
                    ),
                    CircleAvatar(
                        backgroundColor: Color.fromARGB(255, 45, 216,
                            207), // Daha belirgin bir renk seçtik.
                        child: IconButton(
                          onPressed: () {
                            _submitMessage();
                          },
                          icon: Icon(
                            Icons.send,
                            color: Colors
                                .white, // Gönderme düğmesinin rengini beyaz yaptık.
                          ),
                        ))
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
