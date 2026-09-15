import 'package:flutter/material.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  static const _backgroundColor = Color.fromARGB(255, 239, 250, 198);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Inventário'),
      ),
      body: Center(child: Text('Inventário')),
    );
  }
}
