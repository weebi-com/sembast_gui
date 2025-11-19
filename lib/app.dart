import 'package:flutter/material.dart';
import 'package:sembast_cli_gui/screens/database_viewer_screen.dart';

class SembastCliApp extends StatelessWidget {
  const SembastCliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sembast Database Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DatabaseViewerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

