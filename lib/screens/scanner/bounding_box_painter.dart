import 'package:flutter/material.dart';

class YoloPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size imageSize;
  final Size screenSize;
  final Color boxColor;
  final Color labelBackgroundColor;

  YoloPainter({
    required this.detections,
    required this.imageSize,
    required this.screenSize,
    this.boxColor = const Color(0xFF2E6B4A),
    this.labelBackgroundColor = const Color(0xFF2E6B4A),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = labelBackgroundColor
      ..style = PaintingStyle.fill;

    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;

    for (var detection in detections) {
      final box = detection['box'];
      if (box is! List || box.length < 4) continue;

      final double x = (box[0] as num).toDouble() * scaleX;
      final double y = (box[1] as num).toDouble() * scaleY;
      final double w = ((box[2] as num).toDouble() - (box[0] as num).toDouble()) *
          scaleX;
      final double h = ((box[3] as num).toDouble() - (box[1] as num).toDouble()) *
          scaleY;

        final confidence = ((box[4] as num).toDouble().clamp(0.0, 1.0) * 100)
          .toStringAsFixed(0);
        final label = '${detection['tag'] ?? 'unknown'} $confidence%';

      final rect = Rect.fromLTWH(x, y, w, h).deflate(1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        paint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 5);
      final labelWidth = textPainter.width + labelPadding.horizontal;
      final labelHeight = textPainter.height + labelPadding.vertical;
      final labelX = x.clamp(0.0, screenSize.width - labelWidth);
      final labelY = (y - labelHeight - 4).clamp(0.0, screenSize.height - labelHeight);

      final labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelX, labelY, labelWidth, labelHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(labelRect, fillPaint);
      textPainter.paint(
        canvas,
        Offset(labelX + labelPadding.left, labelY + labelPadding.top),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}