import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MeetingAnalyzerApp());
}

class MeetingAnalyzerApp extends StatelessWidget {
  const MeetingAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meeting Analyzer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}
