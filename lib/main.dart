import 'package:flutter/material.dart';
import 'package:keepy/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Firebase.initializeApp() 등 초기화 코드가 들어갈 자리
  runApp(const KeepyApp());
}