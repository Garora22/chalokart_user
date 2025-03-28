import 'package:firebase_database/firebase_database.dart';

class UserModel {
  String? phone;
  String? email;
  String? name;
  String? id;
  String? wallet_amount;

  UserModel({this.phone, this.email, this.name, this.id, this.wallet_amount});

  UserModel.fromSnapshot(DataSnapshot snap) {
    phone = (snap.value as dynamic)["phone"];
    name = (snap.value as dynamic)["name"];
    email = (snap.value as dynamic)["email"];
    wallet_amount = (snap.value as dynamic)["wallet_amount"];
    id = snap.key;
  }
}
