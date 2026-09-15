import 'package:flutter/material.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _selectedIndex = 0;
  var _farmOpened = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Pomar na mão')));
  }
}
