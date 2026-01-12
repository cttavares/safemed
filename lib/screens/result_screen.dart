import 'package:flutter/material.dart';
import '../services/risk_engine.dart';

class ResultScreen extends StatelessWidget {
  final String prescriptionText;
  final int age;
  final bool renal;
  final bool hepatic;

  const ResultScreen({
    super.key,
    required this.prescriptionText,
    required this.age,
    required this.renal,
    required this.hepatic,
  });

  @override
  Widget build(BuildContext context) {
    final results = analyzePrescription(
      prescriptionText,
      age,
      renal,
      hepatic,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis result')),
      body: ListView.builder(
        itemCount: results.length,
        itemBuilder: (_, i) {
          final r = results[i];
          return Card(
            child: ListTile(
              title: Text(r.drug),
              subtitle: Text(r.message),
              trailing: Text(
                r.level,
                style: TextStyle(
                  color: r.level == 'RED'
                      ? Colors.red
                      : r.level == 'YELLOW'
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
