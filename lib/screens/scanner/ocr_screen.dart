import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _picker = ImagePicker();
  final _ocr = OcrService();

  bool _busy = false;
  String _text = '';

  Future<void> _takePhotoAndOcr() async {
    final img = await _picker.pickImage(source: ImageSource.camera);
    if (img == null) return;

    setState(() => _busy = true);
    try {
      final text = await _ocr.recognizeTextFromFile(File(img.path));
      final trimmed = text.trim();
      if (!mounted) return;
      if (trimmed.isNotEmpty) {
        Navigator.pop(context, trimmed);
        return;
      }
      setState(() => _text = text);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR Prescription')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FilledButton(
              onPressed: _busy ? null : _takePhotoAndOcr,
              child: const Text('Take photo and read text'),
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_text.isEmpty ? 'No text yet.' : _text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
