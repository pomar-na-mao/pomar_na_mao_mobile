import 'package:flutter/material.dart';

class FarmView extends StatefulWidget {
  const FarmView({super.key});

  @override
  State<FarmView> createState() => _FarmViewState();
}

class _FarmViewState extends State<FarmView> {
  static const _backgroundColor = Color.fromARGB(255, 239, 250, 198);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: const Icon(Icons.eco),
        title: const Text('Fazenda'),
      ),
      body: Center(child: Text('Fazenda')),
    );
  }
}
