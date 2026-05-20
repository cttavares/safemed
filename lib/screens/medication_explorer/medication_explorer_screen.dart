import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/medication_match.dart';
import 'medication_explorer_camera_controller.dart';
import 'medication_match_engine.dart';
import '../scanner/bounding_box_painter.dart';
import '../scanner/ocr_screen.dart';
import '../../services/infarmed_related_services/drug_regist_service.dart';
import '../../services/infarmed_related_services/informative_bill_service.dart';

enum _ExplorerMode { camera, manual }

const Color _cameraAccent = Color(0xFFC9FCCA);
const Color _searchAccent = Color(0xFFC2BDF0);
const Color _cameraAccentDark = Color(0xFF2E6B4A);
const Color _searchAccentDark = Color(0xFF594A9E);

class MedicationExplorerScreen extends StatefulWidget {
  const MedicationExplorerScreen({super.key});

  @override
  State<MedicationExplorerScreen> createState() =>
      _MedicationExplorerScreenState();
}

class _MedicationExplorerScreenState extends State<MedicationExplorerScreen> {
  late final MedicationExplorerCameraController _camera;
  late final MedicationExplorerMatchEngine _matches;
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _queryController = TextEditingController();

  bool _isListening = false;
  String? _speechLocaleId;

  _ExplorerMode _mode = _ExplorerMode.camera;
  final FlutterTts _flutterTts = FlutterTts();
  String? _activeSpeechKey;
  bool _isSpeaking = false;
  int _speechRequestId = 0;

  @override
  void initState() {
    super.initState();
    _matches = MedicationExplorerMatchEngine();
    _camera = MedicationExplorerCameraController(
      onVisionTagsChanged: _matches.updateVisionTags,
    );
    _camera.addListener(_syncView);
    _matches.addListener(_syncView);
    unawaited(_camera.bootstrap());
    unawaited(_flutterTts.setLanguage('pt-PT'));
    unawaited(_flutterTts.setSpeechRate(0.5));
  }

  void _syncView() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectCameraMode() async {
    if (!mounted) return;
    setState(() {
      _mode = _ExplorerMode.camera;
      _isListening = false;
    });
    await _camera.setCameraEnabled(true);
  }

  Future<void> _selectManualMode() async {
    if (!mounted) return;
    setState(() {
      _mode = _ExplorerMode.manual;
      _isListening = false;
    });
    await _camera.setCameraEnabled(false);
    try {
      await _speech.stop();
    } catch (_) {}
  }

  void _searchFromInput() {
    final text = _queryController.text.trim();
    _matches.searchManual(text);
  }

  void _clearSearch() {
    _queryController.clear();
    _matches.clearManualSearch();
  }

  Future<void> _captureOcrPhoto() async {
    final String? recognizedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const OcrScreen()),
    );

    if (recognizedText == null || recognizedText.trim().isEmpty) return;
    _matches.updateOcrText(recognizedText);
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

  Future<void> _toggleCameraEnabled() async {
    await _camera.toggleCameraEnabled();
  }

  Future<void> _switchCamera() async {
    await _camera.switchCamera();
  }

  Future<void> _toggleTorch() async {
    await _camera.toggleTorch();
  }

  Future<void> _toggleLiveVision(bool value) async {
    await _camera.setLiveVisionEnabled(value);
  }

  void _enableCamera() {
    unawaited(_camera.setCameraEnabled(true));
  }

  @override
  void dispose() {
    _camera.removeListener(_syncView);
    _matches.removeListener(_syncView);
    _queryController.dispose();
    _speech.stop();
    unawaited(_flutterTts.stop());
    unawaited(_camera.disposeResources());
    _matches.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await _speakText(text, speechKey: text);
  }

  List<String> _splitSpeechText(String text, {int maxLength = 140}) {
    final normalized = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('•', '.')
        .trim();

    if (normalized.isEmpty) return const [];

    final chunks = <String>[];
    final sentences = normalized.split(RegExp(r'(?<=[\.!?])\s+'));

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length <= maxLength) {
        chunks.add(trimmed);
        continue;
      }

      final parts = trimmed.split(RegExp(r'(?<=[,;:])\s+'));
      var buffer = '';
      for (final part in parts) {
        final piece = part.trim();
        if (piece.isEmpty) continue;
        if (buffer.isEmpty) {
          buffer = piece;
          continue;
        }

        if ((buffer.length + piece.length + 1) > maxLength) {
          chunks.add(buffer);
          buffer = piece;
        } else {
          buffer = '$buffer $piece';
        }
      }

      if (buffer.isNotEmpty) {
        chunks.add(buffer);
      }
    }

    return chunks.isEmpty ? [normalized] : chunks;
  }

  Future<void> _stopSpeech() async {
    _speechRequestId++;
    _activeSpeechKey = null;
    if (mounted && _isSpeaking) {
      setState(() => _isSpeaking = false);
    }

    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  Future<void> _speakText(String text, {required String speechKey}) async {
    final chunks = _splitSpeechText(text);
    if (chunks.isEmpty) return;

    final requestId = ++_speechRequestId;
    _activeSpeechKey = speechKey;
    if (mounted) {
      setState(() => _isSpeaking = true);
    }

    try {
      await _flutterTts.stop();
      await _flutterTts.awaitSpeakCompletion(true);

      for (final chunk in chunks) {
        if (requestId != _speechRequestId) return;
        if (chunk.trim().isEmpty) continue;
        await _flutterTts.speak(chunk);
      }
    } catch (_) {
    } finally {
      if (requestId == _speechRequestId) {
        _activeSpeechKey = null;
        if (mounted) {
          setState(() => _isSpeaking = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _stopSpeech();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Medication Explorer'),
        actions: [
          IconButton(
            icon: Icon(
              _isSpeaking ? Icons.pause_circle_outline : Icons.volume_up,
            ),
            onPressed: _stopSpeech,
            tooltip: 'Parar fala',
          ),
          IconButton(
            icon: Icon(
              _camera.cameraEnabled ? Icons.videocam : Icons.videocam_off,
            ),
            onPressed: _toggleCameraEnabled,
            tooltip: _camera.cameraEnabled
                ? 'Desativar câmara'
                : 'Ativar câmara',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
            tooltip: 'Trocar câmara',
          ),
          IconButton(
            icon: Icon(_camera.torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
            tooltip: 'Flash',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ExplorerHeroCard(
                cameraEnabled: _camera.cameraEnabled,
                onToggleCamera: _selectCameraMode,
                onSearchWithoutCamera: _selectManualMode,
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 16),
              if (_mode == _ExplorerMode.camera) ...[
                _SectionHeader(
                  title: 'Câmara e OCR',
                  subtitle:
                      'Deteção de medicamentos, leitura de rótulos e inferência em tempo real.',
                  accent: _cameraAccent,
                  accentDark: _cameraAccentDark,
                  icon: Icons.camera_alt_outlined,
                ),
                const SizedBox(height: 12),
                _CameraPanel(
                  cameraController: _camera.cameraController,
                  cameraReady: _camera.cameraReady,
                  cameraEnabled: _camera.cameraEnabled,
                  visionReady: _camera.visionReady,
                  visionSupported: _camera.visionSupported,
                  visionStatus: _camera.visionStatus,
                  liveVisionEnabled: _camera.liveVisionEnabled,
                  onToggleLiveVision: _toggleLiveVision,
                  onCaptureOcrPhoto: _captureOcrPhoto,
                  onEnableCamera: _enableCamera,
                  onRefreshStream: _camera.refreshStream,
                  detections: _camera.detections,
                  frameSize: _camera.frameSize,
                  lastDetectedTags: _camera.lastDetectedTags,
                  accent: _cameraAccent,
                  accentDark: _cameraAccentDark,
                ),
              ],
              const SizedBox(height: 20),
              if (_mode == _ExplorerMode.manual) ...[
                _SectionHeader(
                  title: 'Pesquisa manual',
                  subtitle:
                      'Escreva, fale ou cole termos para procurar sintomas, nomes e substâncias ativas sem usar a câmara.',
                  accent: _searchAccent,
                  accentDark: _searchAccentDark,
                  icon: Icons.search,
                ),
                const SizedBox(height: 12),
                _SearchPanel(
                  controller: _queryController,
                  isListening: _isListening,
                  onSearch: _searchFromInput,
                  onSpeak: _toggleListening,
                  onClear: _clearSearch,
                  accent: _searchAccent,
                  accentDark: _searchAccentDark,
                  quickActions: const [
                    ('Febre', 'febre'),
                    ('Dor de cabeça', 'dor de cabeca'),
                    ('Azia', 'azia'),
                    ('Tosse', 'tosse'),
                  ],
                  onQuickSearch: (value) {
                    _queryController.text = value;
                    _searchFromInput();
                  },
                ),
              ],
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Compatibilidades',
                subtitle:
                    'Resultados combinados a partir da visão, OCR e pesquisa manual.',
                accent: theme.colorScheme.tertiaryContainer,
                accentDark: theme.colorScheme.tertiary,
                icon: Icons.checklist_outlined,
              ),
              const SizedBox(height: 12),
              if (_matches.matches.isEmpty)
                const _EmptyState()
              else
                ..._matches.matches.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MatchCard(
                      match: match,
                      onSpeakText: (text, key) => _speakText(text, speechKey: key),
                      onStopSpeech: _stopSpeech,
                      activeSpeechKey: _activeSpeechKey,
                      isSpeaking: _isSpeaking,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Color accentDark;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.accentDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: accent.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentDark.withOpacity(0.22)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accentDark.withOpacity(0.16),
            child: Icon(icon, size: 18, color: accentDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplorerHeroCard extends StatelessWidget {
  final bool cameraEnabled;
  final VoidCallback onToggleCamera;
  final VoidCallback onSearchWithoutCamera;

  const _ExplorerHeroCard({
    required this.cameraEnabled,
    required this.onToggleCamera,
    required this.onSearchWithoutCamera,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _cameraAccent.withOpacity(0.88),
            _searchAccent.withOpacity(0.74),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.surface,
                  child: Icon(
                    Icons.medical_services_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Exploração de medicamentos unificada',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use a visão para reconhecer embalagens, filtre com texto ou voz e compare rapidamente sintomas, nomes e substâncias ativas.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onToggleCamera,
                    style: cameraEnabled
                        ? ElevatedButton.styleFrom(
                            backgroundColor: _cameraAccent,
                            foregroundColor: _cameraAccentDark,
                          )
                        : ElevatedButton.styleFrom(
                            backgroundColor: _cameraAccent.withOpacity(0.50),
                            foregroundColor: _cameraAccentDark.withOpacity(
                              0.50,
                            ),
                          ),
                    icon: Icon(
                      cameraEnabled ? Icons.videocam : Icons.videocam_off,
                    ),
                    label: Text('Pesquisa inteligente com câmara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSearchWithoutCamera,
                    style: cameraEnabled
                        ? OutlinedButton.styleFrom(
                            foregroundColor: _searchAccentDark.withOpacity(
                              0.50,
                            ),
                            side: BorderSide(
                              color: _searchAccent.withOpacity(0.50),
                            ),
                          )
                        : OutlinedButton.styleFrom(
                            foregroundColor: _searchAccentDark,
                            side: BorderSide(color: _searchAccent),
                          ),
                    icon: const Icon(Icons.search),
                    label: const Text('Pesquisa manual'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPanel extends StatelessWidget {
  final CameraController? cameraController;
  final bool cameraReady;
  final bool cameraEnabled;
  final bool visionReady;
  final bool visionSupported;
  final String visionStatus;
  final bool liveVisionEnabled;
  final ValueChanged<bool> onToggleLiveVision;
  final VoidCallback onCaptureOcrPhoto;
  final VoidCallback onEnableCamera;
  final Future<void> Function() onRefreshStream;
  final List<Map<String, dynamic>> detections;
  final Size frameSize;
  final String lastDetectedTags;
  final Color accent;
  final Color accentDark;

  const _CameraPanel({
    required this.cameraController,
    required this.cameraReady,
    required this.cameraEnabled,
    required this.visionReady,
    required this.visionSupported,
    required this.visionStatus,
    required this.liveVisionEnabled,
    required this.onToggleLiveVision,
    required this.onCaptureOcrPhoto,
    required this.onEnableCamera,
    required this.onRefreshStream,
    required this.detections,
    required this.frameSize,
    required this.lastDetectedTags,
    required this.accent,
    required this.accentDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canShowPreview =
        cameraEnabled && cameraReady && cameraController != null;
    return Card(
      elevation: 0,
      color: accent.withOpacity(0.34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accentDark.withOpacity(0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Legenda da visão',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accentDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _StatusCard(
              accent: accentDark,
              visionStatus: visionStatus,
              detections: detections,
              tags: lastDetectedTags,
              cameraEnabled: cameraEnabled,
              liveVisionEnabled: liveVisionEnabled,
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: cameraController?.value.aspectRatio ?? 4 / 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (canShowPreview)
                      CameraPreview(cameraController!)
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withOpacity(0.82),
                              Colors.white.withOpacity(0.90),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam_off,
                                size: 54,
                                color: accentDark,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                cameraEnabled
                                    ? (cameraReady
                                          ? 'Câmara pronta'
                                          : 'A preparar a câmara...')
                                    : 'Câmara desativada',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                !visionSupported
                                    ? visionStatus
                                    : cameraEnabled
                                    ? 'A visualização fica aqui e os resultados aparecem sobrepostos.'
                                    : 'Pode continuar a pesquisar por texto ou voz.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: onEnableCamera,
                                child: Text(
                                  cameraEnabled
                                      ? 'Suspender câmara'
                                      : 'Ativar câmara',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (canShowPreview && liveVisionEnabled && visionReady)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return CustomPaint(
                              painter: YoloPainter(
                                detections: detections,
                                imageSize: frameSize,
                                screenSize: constraints.biggest,
                                boxColor: accentDark,
                                labelBackgroundColor: accentDark,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _LabeledActionButton(
                  icon: Icons.document_scanner,
                  label: 'OCR',
                  tooltip: 'Capturar rótulo para OCR',
                  onPressed: onCaptureOcrPhoto,
                  accent: accentDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Live Vision'),
                      selected: liveVisionEnabled,
                      onSelected: onToggleLiveVision,
                      avatar: Icon(
                        liveVisionEnabled
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 18,
                        color: liveVisionEnabled
                            ? accentDark
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      side: BorderSide(color: accentDark.withOpacity(0.18)),
                      backgroundColor: theme.colorScheme.surface.withOpacity(
                        0.75,
                      ),
                      selectedColor: accent.withOpacity(0.28),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRefreshStream,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar stream'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onSearch;
  final VoidCallback onSpeak;
  final VoidCallback onClear;
  final List<(String, String)> quickActions;
  final ValueChanged<String> onQuickSearch;
  final Color accent;
  final Color accentDark;

  const _SearchPanel({
    required this.controller,
    required this.isListening,
    required this.onSearch,
    required this.onSpeak,
    required this.onClear,
    required this.quickActions,
    required this.onQuickSearch,
    required this.accent,
    required this.accentDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: accent.withOpacity(0.36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accentDark.withOpacity(0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  decoration: InputDecoration(
                    labelText:
                        'Escreva sintomas, medicamento ou substância ativa',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: onClear,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSearch,
                    icon: const Icon(Icons.manage_search),
                    label: const Text('Procurar'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: onSpeak,
                  icon: Icon(isListening ? Icons.mic_off : Icons.mic),
                  label: Text(isListening ? 'Parar' : 'Falar'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Sugestões rápidas', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: quickActions
                  .map(
                    (action) => ActionChip(
                      label: Text(action.$1),
                      onPressed: () => onQuickSearch(action.$2),
                    ),
                  )
                  .toList(),
            ),
          ],
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
  final Color accent;

  const _LabeledActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withOpacity(0.24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent),
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
  final Color accent;
  final String visionStatus;
  final List<Map<String, dynamic>> detections;
  final String tags;
  final bool cameraEnabled;
  final bool liveVisionEnabled;

  const _StatusCard({
    required this.accent,
    required this.visionStatus,
    required this.detections,
    required this.tags,
    required this.cameraEnabled,
    required this.liveVisionEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detectionCount = detections.length;
    final detectionText = detectionCount == 0
        ? 'Aguardando deteções...'
        : '$detectionCount objeto(s) detetado(s)';
    return Card(
      color: theme.colorScheme.surface.withOpacity(0.92),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withOpacity(0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cameraEnabled ? detectionText : 'Câmara desativada',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(visionStatus, style: theme.textTheme.bodySmall),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Classes: $tags', style: theme.textTheme.bodySmall),
            ],
            if (!liveVisionEnabled) ...[
              const SizedBox(height: 2),
              Text('Live Vision pausado', style: theme.textTheme.bodySmall),
            ],
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
    return Center(
      child: Text(
        'Point the camera at a medication label or describe a symptom to see matches.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MedicationMatch match;
  final Future<void> Function(String text, String speechKey) onSpeakText;
  final Future<void> Function() onStopSpeech;
  final String? activeSpeechKey;
  final bool isSpeaking;

  const _MatchCard({
    required this.match,
    required this.onSpeakText,
    required this.onStopSpeech,
    required this.activeSpeechKey,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aliasText = match.aliases.isEmpty
        ? 'No common aliases found.'
        : 'Aliases: ${match.aliases.take(4).join(', ')}';
    final (label, color) = switch (match.source) {
      'vision' => ('Visão', _cameraAccentDark),
      'ocr' => ('OCR', Colors.deepOrange),
      'manual' => ('Manual', _searchAccentDark),
      'symptom' => ('Sintoma', Colors.teal),
      'barcode' => ('Barcode', Colors.indigo),
      _ => ('Match', theme.colorScheme.primary),
    };
    final entry = match.entryId != null ? drugRegistService.getEntryById(match.entryId!) : null;
    final bill = entry == null ? null : informativeBillService.resolveFor(entry);

    // derive first 3 therapeutic indications if available
    final indications = bill?.therapeuticIndications ?? <String>[];
    final firstThreeIndications = indications.isNotEmpty ? indications.take(3).toList() : <String>[];
    final speechBaseKey = match.entryId ?? match.name;
    final substanceSpeech = entry == null
      ? 'Substância ativa: ${match.name}'
      : bill?.minimumAge != null
        ? 'Substância ativa: ${entry.substanciaAtiva}. Idade mínima: ${bill!.minimumAge}.'
        : 'Substância ativa: ${entry.substanciaAtiva}.';

    Future<void> toggleSpeech(String suffix, String text) async {
      final key = '$speechBaseKey:$suffix';
      if (isSpeaking && activeSpeechKey == key) {
        await onStopSpeech();
      } else {
        await onSpeakText(text, key);
      }
    }

    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(match.name, style: theme.textTheme.titleMedium),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(label),
                  labelStyle: TextStyle(color: color),
                  side: BorderSide(color: color.withOpacity(0.24)),
                  backgroundColor: color.withOpacity(0.08),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Ler nome',
                  onPressed: () => toggleSpeech('name', match.name),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(match.reason, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(aliasText, style: theme.textTheme.bodySmall),
            if (firstThreeIndications.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Indicações: ${firstThreeIndications.join(', ')}', style: theme.textTheme.bodySmall),
            ],
              if (match.entryId != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Abrir no Infarmed',
                      onPressed: () async {
                        final entry = drugRegistService.getEntryById(match.entryId!);
                        final rawUrl = entry?.infoUrl ?? '';
                        if (rawUrl.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Link Infarmed indisponível.')),
                          );
                          return;
                        }

                        final uri = Uri.tryParse(rawUrl);
                        if (uri == null || !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('URL inválida')),
                          );
                          return;
                        }

                        try {
                          final launched = await url_launcher.launchUrl(
                            uri,
                            mode: url_launcher.LaunchMode.externalApplication,
                          );
                          if (!launched) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Não foi possível abrir o link.')),
                            );
                          }
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Não foi possível abrir o link.')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final entry = drugRegistService.getEntryById(
                          match.entryId!,
                        );
                        if (entry == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Detalhes não disponíveis.'),
                            ),
                          );
                          return;
                        }
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (ctx) {
                            final bill = informativeBillService.resolveFor(entry);
                            final titleStyle = theme.textTheme.titleLarge?.copyWith(
                              fontSize: 22,
                            );
                            final headingStyle = theme.textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                );
                            final boldStyle = TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            );
                            final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                            );
                            final titleSpeechKey = '$speechBaseKey:title';

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16.0,
                                18.0,
                                16.0,
                                24.0,
                              ),
                              child: SingleChildScrollView(
                                child: DefaultTextStyle.merge(
                                  style: bodyStyle ?? const TextStyle(fontSize: 15),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 25),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              entry.nomeComercial,
                                              style: titleStyle?.copyWith(
                                                color: const Color(
                                                  0xFF594A9E,
                                                ), // Roxo Deep Purple standard do Flutter
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22,
                                                letterSpacing:
                                                    -0.5, // Letras ligeiramente mais juntas dá um aspeto premium
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.pause_circle_outline,
                                              size: 22,
                                            ),
                                            tooltip: 'Parar fala',
                                            onPressed: () async {
                                              await onStopSpeech();
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Divider(
                                        thickness: 1,
                                        height: 1,
                                        color: const Color(
                                          0xFF594A9E,
                                        ).withOpacity(0.22),
                                      ),
                                      const SizedBox(height: 10),
                                      // Disclaimer sobre a precisão e link para o folheto
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Disclaimer: A informação apresentada é generalizada relativamente à substância ativa / DCI associada, não é 100% precisa e não substitui a consulta do folheto informativo oficial no INFOMED — recomenda-se vivamente consultar o folheto específico através do link de redirecionamento.',
                                              style: bodyStyle?.copyWith(
                                                fontStyle: FontStyle.italic,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.volume_up, size: 20),
                                            tooltip: 'Ler disclaimer',
                                            onPressed: () => toggleSpeech(
                                              'disclaimer',
                                              'Disclaimer: A informação apresentada é generalizada relativamente à substância ativa DCI associada, não é cem por cento precisa e não substitui a consulta do folheto informativo oficial no Infarmed. Recomenda-se vivamente consultar o folheto específico através do link de redirecionamento.',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // fiURL to open infomed page in browser
                                      if (entry.infoUrl.isNotEmpty)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton.icon(
                                            onPressed: () async {
                                              final raw = entry.infoUrl;
                                              final uri = Uri.tryParse(raw);
                                              if (uri == null || !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('URL inválida')),
                                                );
                                                return;
                                              }

                                              try {
                                                final launched = await url_launcher.launchUrl(
                                                  uri,
                                                  mode: url_launcher.LaunchMode.externalApplication,
                                                );
                                                if (!launched) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Não foi possível abrir o link: $raw')),
                                                  );
                                                }
                                              } catch (_) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Não foi possível abrir o link: $raw')),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.open_in_new),
                                            label: const Text('Ver no Infarmed'),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      Divider(
                                        thickness: 1,
                                        height: 1,
                                        color: const Color(
                                          0xFF594A9E,
                                        ).withOpacity(0.22),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Substância ativa: ${entry.substanciaAtiva}',
                                              style: boldStyle,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.volume_up, size: 20),
                                            tooltip: 'Ler substância ativa',
                                            onPressed: () => toggleSpeech('substance', substanceSpeech),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (bill.minimumAge != null)
                                        Text(
                                          'Idade mínima: ${bill.minimumAge}',
                                          style: boldStyle,
                                        ),
                                      const SizedBox(height: 10),
                                      Divider(
                                        thickness: 1,
                                        height: 1,
                                        color: const Color(
                                          0xFF594A9E,
                                        ).withOpacity(0.22),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(child: Text('Indicações terapêuticas', style: headingStyle)),
                                          IconButton(
                                            icon: const Icon(Icons.volume_up, size: 20),
                                            tooltip: 'Ler indicações',
                                            onPressed: () => toggleSpeech(
                                              'indications',
                                              bill.therapeuticIndications.isEmpty
                                                  ? 'Indicações terapêuticas não disponíveis.'
                                                  : 'Indicações terapêuticas. ${bill.therapeuticIndications.join('. ')}',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (bill.therapeuticIndications.isEmpty)
                                        Text('Não disponíveis', style: bodyStyle)
                                      else
                                        ...bill.therapeuticIndications.map(
                                          (t) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2.0,
                                            ),
                                            child: Text('• $t', style: bodyStyle),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(child: Text('Efeitos adversos (resumo)', style: headingStyle)),
                                            IconButton(
                                              icon: const Icon(Icons.volume_up, size: 20),
                                              tooltip: 'Ler efeitos adversos',
                                              onPressed: () {
                                                final adverseItems = bill.adverseReactions
                                                    .expand((a) => [...a.frequent, ...a.other])
                                                    .map((item) => item.trim())
                                                    .where((item) => item.isNotEmpty)
                                                    .toList();

                                                final parts = <String>[];
                                                if (adverseItems.isNotEmpty) {
                                                  parts.add('Efeitos adversos. ${adverseItems.join('. ')}');
                                                } else {
                                                  parts.add('Efeitos adversos não disponíveis.');
                                                }

                                                if ((bill.pregnancyNote ?? '').isNotEmpty) {
                                                  parts.add('Nota de gravidez: ${bill.pregnancyNote}');
                                                }
                                                if ((bill.breastfeedingNote ?? '').isNotEmpty) {
                                                  parts.add('Nota de amamentação: ${bill.breastfeedingNote}');
                                                }

                                                toggleSpeech('adverse', parts.join('. '));
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      if (bill.adverseReactions.isEmpty)
                                        Text('Não disponíveis', style: bodyStyle)
                                      else
                                        ...bill.adverseReactions.map(
                                          (a) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2.0,
                                            ),
                                            child: Text(
                                              a.frequent.isNotEmpty
                                                  ? a.frequent
                                                        .map(
                                                          (item) =>
                                                              '• ${item.trim()}',
                                                        )
                                                        .join('\n')
                                                  : a.other
                                                        .map(
                                                          (item) =>
                                                              '• ${item.trim()}',
                                                        )
                                                        .join('\n'),
                                              style: bodyStyle,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      Divider(
                                        thickness: 1,
                                        height: 1,
                                        color: const Color(
                                          0xFF594A9E,
                                        ).withOpacity(0.22),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(child: Text('Classificação de risco para gravidez e amamentação', style: headingStyle)),
                                          IconButton(
                                            icon: const Icon(Icons.volume_up, size: 20),
                                            tooltip: 'Ler classificação de risco',
                                            onPressed: () => toggleSpeech(
                                              'risk',
                                              [
                                                'Gravidez: ${bill.pregnancyRisk ?? ''}',
                                                if ((bill.pregnancyNote ?? '').isNotEmpty)
                                                  'Nota de gravidez: ${bill.pregnancyNote}',
                                                'Amamentação: ${bill.breastfeedingRisk ?? ''}',
                                                if ((bill.breastfeedingNote ?? '').isNotEmpty)
                                                  'Nota de amamentação: ${bill.breastfeedingNote}',
                                              ].join('. '),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Gravidez: ${bill.pregnancyRisk ?? ''}',
                                        style: boldStyle,
                                      ),
                                      if ((bill.pregnancyNote ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Nota: ${bill.pregnancyNote}',
                                          style: bodyStyle,
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        'Amamentação: ${bill.breastfeedingRisk ?? ''}',
                                        style: boldStyle,
                                      ),
                                      if ((bill.breastfeedingNote ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Nota: ${bill.breastfeedingNote}',
                                          style: bodyStyle,
                                        ),
                                      ],
                                      const SizedBox(height: 30),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: const Text('Detalhes'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
