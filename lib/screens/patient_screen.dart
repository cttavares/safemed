import 'package:flutter/material.dart';

import 'result_screen.dart';

class PatientScreen extends StatefulWidget {
  final String? prescriptionText;
  const PatientScreen({super.key, this.prescriptionText});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  int age = 65;
  bool renal = false;
  bool hepatic = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient data')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Age'),
                Expanded(
                  child: Slider(
                    value: age.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: age.toString(),
                    onChanged: (v) => setState(() => age = v.toInt()),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              title: const Text('Renal disease'),
              value: renal,
              onChanged: (v) => setState(() => renal = v!),
            ),
            CheckboxListTile(
              title: const Text('Hepatic disease'),
              value: hepatic,
              onChanged: (v) => setState(() => hepatic = v!),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(
                      prescriptionText: widget.prescriptionText ?? '',
                      age: age,
                      renal: renal,
                      hepatic: hepatic,
                    ),
                  ),
                );
              },
              child: const Text('Analyze'),
            ),
          ],
        ),
      ),
    );
  }
}
