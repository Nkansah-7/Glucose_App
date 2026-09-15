import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/glucose_reading.dart';

/// Colored segment strip showing class-over-time with distinct gray gap blocks
/// for reading breaks / disconnect intervals.
class TimelineStrip extends StatelessWidget {
  const TimelineStrip({
    super.key,
    required this.readings,
    required this.window,
    required this.now,
  });

  final List<GlucoseReading> readings; // ascending by timestamp
  final Duration window;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text('Not enough data yet', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      );
    }
    final start = now.subtract(window);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 46,
            child: CustomPaint(
              painter: _TimelinePainter(readings: readings, start: start, span: window),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (k) {
            final t = start.add(window * (k / 4));
            return Text(_formatTick(t, window), style: const TextStyle(fontSize: 10, color: Color(0xFF9AA2AF)));
          }),
        ),
      ],
    );
  }

  static String _formatTick(DateTime t, Duration window) {
    final hours = window.inHours;
    if (hours <= 12) return DateFormat('HH:mm').format(t);
    if (hours <= 48) return '${DateFormat('E').format(t)} ${t.hour.toString().padLeft(2, '0')}h';
    return DateFormat('d/M').format(t);
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.readings, required this.start, required this.span});

  final List<GlucoseReading> readings;
  final DateTime start;
  final Duration span;

  static const int _gapThresholdMinutes = 7;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF1F5F9));
    final spanMs = span.inMilliseconds.toDouble();

    for (var i = 0; i < readings.length; i++) {
      final current = readings[i];
      final x0 = ((current.timestamp.difference(start).inMilliseconds) / spanMs).clamp(0.0, 1.0);
      final left = x0 * size.width;

      if (i < readings.length - 1) {
        final next = readings[i + 1];
        final gapMinutes = next.timestamp.difference(current.timestamp).inMinutes;
        final x1 = ((next.timestamp.difference(start).inMilliseconds) / spanMs).clamp(0.0, 1.0);
        final right = x1 * size.width;

        if (gapMinutes > _gapThresholdMinutes) {
          // Draw normal reading block duration (~ 5 mins worth)
          final xNormal = ((current.timestamp.add(const Duration(minutes: 5)).difference(start).inMilliseconds) / spanMs).clamp(0.0, 1.0);
          final rightNormal = (xNormal * size.width).clamp(left + 1.0, right);

          canvas.drawRect(
            Rect.fromLTRB(left, 0, rightNormal, size.height),
            Paint()..color = AppColors.forClass(current.glucoseClass),
          );

          // Draw Disconnected / No Signal gray block for the remaining gap
          canvas.drawRect(
            Rect.fromLTRB(rightNormal, 0, right, size.height),
            Paint()..color = const Color(0xFFCBD5E1),
          );
        } else {
          canvas.drawRect(
            Rect.fromLTRB(left, 0, right.clamp(left + 0.5, size.width), size.height),
            Paint()..color = AppColors.forClass(current.glucoseClass),
          );
        }
      } else {
        canvas.drawRect(
          Rect.fromLTRB(left, 0, size.width, size.height),
          Paint()..color = AppColors.forClass(current.glucoseClass),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.readings != readings || oldDelegate.start != start || oldDelegate.span != span;
  }
}
