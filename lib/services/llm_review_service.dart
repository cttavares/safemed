import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safemed/models/prescription_plan.dart';
import 'package:safemed/models/profile.dart';

class LlmReviewService {
  static const String _apiKeyPrefsKey = 'gemini_api_key';

  /// Retrieves the saved API key from SharedPreferences.
  static Future<String?> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPrefsKey);
  }

  /// Saves the API key to SharedPreferences.
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefsKey, apiKey);
  }

  /// Deletes the saved API key.
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPrefsKey);
  }

  /// Reviews the prescription plan using Gemini.
  static Future<String> reviewPlan(
    Profile profile,
    PrescriptionPlan plan,
    String apiKey,
  ) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final prompt = _buildPrompt(profile, plan);

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Nenhuma resposta recebida do modelo.';
    } catch (e) {
      throw Exception('Erro ao comunicar com a IA: $e');
    }
  }

  static String _buildPrompt(Profile profile, PrescriptionPlan plan) {
    final buffer = StringBuffer();
    
    buffer.writeln('Atua como um farmacêutico clínico experiente ou médico especializado na revisão de planos de medicação.');
    buffer.writeln('Avalia o seguinte plano de prescrição para este utente e diz se os medicamentos são adequados ao seu perfil de saúde.');
    buffer.writeln('Se achares que algum medicamento deve ser alterado (por dosagem incorreta, interações, idade, gravidez ou alergias), indica quais e justifica o porquê detalhadamente. Responde em Português de Portugal e usa formatação Markdown.');
    buffer.writeln('\n---');
    
    buffer.writeln('\n## Perfil do Utente');
    buffer.writeln('- **Idade:** ${profile.age} anos');
    
    final sexStr = profile.sex == BiologicalSex.male ? 'Masculino' : 'Feminino';
    buffer.writeln('- **Sexo:** $sexStr');
    
    if (profile.sex == BiologicalSex.female) {
      buffer.writeln('- **Grávida:** ${profile.isPregnant ? "Sim" : "Não"}');
    }
    
    buffer.writeln('- **Categoria:** ${profile.category.name}');
    
    if (profile.allergies.isNotEmpty) {
      buffer.writeln('- **Alergias:** ${profile.allergies.join(", ")}');
    } else {
      buffer.writeln('- **Alergias:** Nenhuma conhecida');
    }
    
    final conditions = <String>[];
    if (profile.renalDisease) conditions.add('Doença Renal');
    if (profile.hepaticDisease) conditions.add('Doença Hepática');
    if (profile.diabetes) conditions.add('Diabetes');
    if (profile.hypertension) conditions.add('Hipertensão');
    if (profile.asma) conditions.add('Asma');
    if (profile.dopc) conditions.add('DPOC');
    if (profile.healthIssues.trim().isNotEmpty) conditions.add(profile.healthIssues);

    if (conditions.isNotEmpty) {
      buffer.writeln('- **Condições/Doenças:** ${conditions.join(", ")}');
    } else {
      buffer.writeln('- **Condições/Doenças:** Nenhuma reportada');
    }

    buffer.writeln('\n## Plano de Medicação: ${plan.name}');
    
    if (plan.medications.isEmpty) {
      buffer.writeln('*Nenhum medicamento adicionado ainda.*');
    } else {
      for (final med in plan.medications) {
        buffer.writeln('\n### ${med.name}');
        if (med.dose.isNotEmpty) buffer.writeln('- **Dose:** ${med.dose}');
        
        if (med.intervalHours != null && med.firstDoseAt != null) {
          buffer.writeln('- **Agendamento:** A cada ${med.intervalHours} horas a partir de ${_formatDate(med.firstDoseAt!)}');
        } else if (med.times.isNotEmpty) {
          buffer.writeln('- **Horários Fixos:** ${med.times.join(", ")}');
        }
        
        if (med.notes.trim().isNotEmpty) {
          buffer.writeln('- **Notas:** ${med.notes}');
        }
      }
    }
    
    buffer.writeln('\n---');
    buffer.writeln('\nFaz uma análise clínica detalhada e apresenta as tuas conclusões.');
    return buffer.toString();
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
