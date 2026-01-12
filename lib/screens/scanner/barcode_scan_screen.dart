import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;

          final value = barcodes.first.rawValue;
          if (value == null || value.isEmpty) return;

          _done = true;
          Navigator.pop(context, value); // returns barcode string
        },
      ),
    );
  }
}
