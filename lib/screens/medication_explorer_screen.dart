import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/medication_match.dart';
import '../services/medication_explorer_service.dart';
import '../services/ocr_service.dart';
import 'scanner/ocr_screen.dart';

class MedicationExplorerScreen extends StatefulWidget {
  const MedicationExplorerScreen({super.key});

  @override
  State<MedicationExplorerScreen> createState() => _MedicationExplorerScreenState();
}

class _MedicationExplorerScreenState extends State<MedicationExplorerScreen> {
  final _controller = MobileScannerController(
    returnImage: true,
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 600,
  );
  final _ocr = OcrService();
  final _service = MedicationExplorerService();
  final _speech = SpeechToText();
  final _queryController = TextEditingController();

  late final File _ocrTempFile;
  DateTime _lastOcrAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busyOcr = false;
  bool _liveOcrEnabled = true;
  bool _isListening = false;

  String _lastBarcode = '';
  String _lastOcrSnippet = '';
  List<MedicationMatch> _matches = const [];

  @override
  void initState() {
    super.initState();
    final tempDir = Directory.systemTemp.createTempSync('safemed_ocr');
    _ocrTempFile = File('${tempDir.path}/frame.jpg');
  }

  @override
  void dispose() {
    _queryController.dispose();
    _speech.stop();
    _controller.dispose();
    _ocr.dispose();
    try {
      _ocrTempFile.deleteSync();
    } catch (_) {}
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final value = barcodes.first.rawValue ?? barcodes.first.displayValue ?? '';
      if (value.isNotEmpty) {
        _handleBarcode(value);
      }
    }

    if (!_liveOcrEnabled) return;
    final bytes = capture.image;
    if (bytes == null) return;
    final now = DateTime.now();
    if (_busyOcr || now.difference(_lastOcrAt).inMilliseconds < 1200) {
      return;
    }

    _busyOcr = true;
    _lastOcrAt = now;
    _runOcr(bytes);
  }

  Future<void> _runOcr(List<int> bytes) async {
    try {
      await _ocrTempFile.writeAsBytes(bytes, flush: true);
      final text = await _ocr.recognizeTextFromFile(_ocrTempFile);
      final trimmed = text.trim();
      if (!mounted || trimmed.isEmpty) return;
      _handleOcrText(trimmed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _lastOcrSnippet = 'OCR failed to read text.');
    } finally {
      _busyOcr = false;
    }
  }

  void _handleBarcode(String value) {
    if (_lastBarcode == value) return;
    _lastBarcode = value;

    final matches = _service.searchBarcode(value);
    if (matches.isNotEmpty) {
      _mergeMatches(matches);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleOcrText(String text) {
    final matches = _service.searchText(text, source: 'ocr');
    if (matches.isNotEmpty) {
      _mergeMatches(matches);
    }

    final snippet = text.replaceAll(RegExp(r'\s+'), ' ');
    if (mounted) {
      setState(() {
        _lastOcrSnippet = snippet.length > 120 ? '${snippet.substring(0, 120)}...' : snippet;
      });
    }
  }

  void _mergeMatches(List<MedicationMatch> newMatches) {
    final map = {for (final m in _matches) m.name: m};
    for (final m in newMatches) {
      map[m.name] = m;
    }
    final list = map.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    setState(() => _matches = list);
  }

  void _searchFromInput() {
    final text = _queryController.text.trim();
    if (text.isEmpty) return;
    final matches = _service.searchText(text, source: 'manual');
    if (matches.isNotEmpty) {
      _mergeMatches(matches);
    } else {
      setState(() => _matches = const []);
    }
  }

  Future<void> _captureOcrPhoto() async {
    final String? recognizedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const OcrScreen()),
    );

    if (recognizedText == null || recognizedText.trim().isEmpty) return;
    _handleOcrText(recognizedText);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available || !mounted) return;

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        if (text.isEmpty || !mounted) return;
        _queryController.text = text;
        _queryController.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
        if (result.finalResult) {
          _searchFromInput();
          setState(() => _isListening = false);
        }
      },
    );
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Explorer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _StatusCard(
                    barcode: _lastBarcode,
                    ocrSnippet: _lastOcrSnippet,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                        onPressed: _toggleListening,
                        tooltip: _isListening ? 'Stop listening' : 'Speak symptoms or a medication',
                      ),
                      IconButton(
                        icon: const Icon(Icons.document_scanner),
                        onPressed: _captureOcrPhoto,
                        tooltip: 'Capture label for OCR',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          decoration: const InputDecoration(
                            labelText: 'Type symptoms or medication name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _searchFromInput,
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Live OCR'),
                    subtitle: const Text('Recognize medication names from the camera preview.'),
                    value: _liveOcrEnabled,
                    onChanged: (value) {
                      setState(() => _liveOcrEnabled = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _matches.isEmpty
                        ? const _EmptyState()
                        : ListView.separated(
                            itemCount: _matches.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final match = _matches[index];
                              return _MatchCard(match: match);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String barcode;
  final String ocrSnippet;

  const _StatusCard({
    required this.barcode,
    required this.ocrSnippet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              barcode.isEmpty ? 'No barcode detected yet.' : 'Barcode: $barcode',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              ocrSnippet.isEmpty ? 'OCR is waiting for a readable label.' : 'OCR: $ocrSnippet',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Point the camera at a medication label or describe a symptom to see matches.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MedicationMatch match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aliasText = match.aliases.isEmpty
        ? 'No common aliases found.'
        : 'Aliases: ${match.aliases.take(4).join(', ')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(match.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(match.reason, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(aliasText, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
