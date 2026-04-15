import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/medication_match.dart';
import '../services/medication_explorer_service.dart';
import '../services/ocr_service.dart';
import 'scanner/ocr_screen.dart';

enum _ExplorerMode { choose, camera, textSearch }

class MedicationExplorerScreen extends StatefulWidget {
  const MedicationExplorerScreen({super.key});

  @override
  State<MedicationExplorerScreen> createState() =>
      _MedicationExplorerScreenState();
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
  String? _speechLocaleId;
  _ExplorerMode _mode = _ExplorerMode.choose;

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
      final value =
          barcodes.first.rawValue ?? barcodes.first.displayValue ?? '';
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
        _lastOcrSnippet = snippet.length > 120
            ? '${snippet.substring(0, 120)}...'
            : snippet;
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

  void _openCameraMode() {
    setState(() {
      _mode = _ExplorerMode.camera;
    });
  }

  void _openTextMode() {
    setState(() {
      _mode = _ExplorerMode.textSearch;
    });
  }

  void _backToChooser() {
    setState(() {
      _mode = _ExplorerMode.choose;
      _isListening = false;
    });
    _speech.stop();
  }

  Future<String?> _resolveSpeechLocaleId() async {
    if (_speechLocaleId != null) {
      return _speechLocaleId;
    }

    try {
      final locales = await _speech.locales();
      const preferredLocales = ['pt_BR', 'pt_PT'];

      for (final preferred in preferredLocales) {
        for (final locale in locales) {
          if (locale.localeId == preferred) {
            _speechLocaleId = locale.localeId;
            return _speechLocaleId;
          }
        }
      }

      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('pt')) {
          _speechLocaleId = locale.localeId;
          return _speechLocaleId;
        }
      }
    } catch (_) {}

    try {
      final systemLocale = await _speech.systemLocale();
      _speechLocaleId = systemLocale?.localeId;
    } catch (_) {}

    return _speechLocaleId;
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

    final localeId = await _resolveSpeechLocaleId();
    setState(() => _isListening = true);
    await _speech.listen(
      localeId: localeId,
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
          if (_mode != _ExplorerMode.choose)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _backToChooser,
              tooltip: 'Voltar',
            ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
            tooltip: 'Trocar câmara',
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: _toggleTorch,
            tooltip: 'Flash',
          ),
        ],
      ),
      body: switch (_mode) {
        _ExplorerMode.choose => _buildChooserView(context),
        _ExplorerMode.camera => _buildCameraView(context),
        _ExplorerMode.textSearch => _buildTextSearchView(context),
      },
    );
  }

  Widget _buildChooserView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Como quer procurar?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Escolha entre usar a câmara para detetar medicamentos ou usar texto/voz para procurar sintomas, nome do medicamento e substâncias ativas.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _ChoiceCardButton(
                    icon: Icons.camera_alt,
                    title: 'Usar câmara',
                    description:
                        'Detetar códigos de barras e texto de embalagens em tempo real.',
                    onPressed: _openCameraMode,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _ChoiceCardButton(
                    icon: Icons.keyboard_voice,
                    title: 'Escrever ou falar',
                    description:
                        'Procurar por sintomas, nome do medicamento ou substâncias ativas.',
                    onPressed: _openTextMode,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
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
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _LabeledActionButton(
                      icon: Icons.document_scanner,
                      label: 'OCR',
                      tooltip: 'Capturar rótulo para OCR',
                      onPressed: _captureOcrPhoto,
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Live OCR'),
                  subtitle: const Text(
                    'Recognize medication names from the camera preview.',
                  ),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
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
    );
  }

  Widget _buildTextSearchView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    labelText: 'Escreva sintomas, medicamento ou substância ativa',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _searchFromInput,
                icon: const Icon(Icons.search),
                label: const Text('Procurar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _LabeledActionButton(
                icon: _isListening ? Icons.mic_off : Icons.mic,
                label: _isListening ? 'Parar' : 'Falar',
                tooltip: _isListening
                    ? 'Parar reconhecimento de voz'
                    : 'Falar sintomas, medicamento ou substância ativa',
                onPressed: _toggleListening,
              ),
            ],
          ),
          const SizedBox(height: 12),
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
    );
  }
}

class _ChoiceCardButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onPressed;

  const _ChoiceCardButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  const _LabeledActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String barcode;
  final String ocrSnippet;

  const _StatusCard({required this.barcode, required this.ocrSnippet});

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
              barcode.isEmpty
                  ? 'No barcode detected yet.'
                  : 'Barcode: $barcode',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              ocrSnippet.isEmpty
                  ? 'OCR is waiting for a readable label.'
                  : 'OCR: $ocrSnippet',
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
