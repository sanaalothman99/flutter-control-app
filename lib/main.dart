import 'package:flutter/material.dart';
import 'screens/start_page.dart';
void main() {
  runApp(MyApp());
}
class MyApp extends StatelessWidget{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      title: 'Remote Control App',
      home:  HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

