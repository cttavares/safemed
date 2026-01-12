import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _recognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> recognizeTextFromFile(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
