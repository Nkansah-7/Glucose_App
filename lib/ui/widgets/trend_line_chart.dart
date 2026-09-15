import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/glucose_class.dart';
import '../../core/theme.dart';
import '../../models/glucose_reading.dart';

/// Interactive mg/dL trend line chart with pinch-to-zoom, panning,
/// inspection tooltip, and visual reading break / disconnect indicators.
class TrendLineChart extends StatefulWidget {
  const TrendLineChart({
    super.key,
    required this.readings,
    required this.window,
    required this.now,
    this.height = 200,
  });

  final List<GlucoseReading> readings; // ascending by timestamp
  final Duration window;
  final DateTime now;
  final double height;

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> {
  final TransformationController _transformationController = TransformationController();
  double _zoomScale = 1.0;
  GlucoseReading? _selectedReading;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _zoomScale).abs() > 0.05) {
      setState(() {
        _zoomScale = scale;
      });
    }
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _zoomScale = 1.0;
      _selectedReading = null;
    });
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale < 5.0) {
      final newScale = (currentScale * 1.35).clamp(1.0, 5.0);
      _transformationController.value = Matrix4.identity()..scale(newScale);
    }
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.0) {
      final newScale = (currentScale / 1.35).clamp(1.0, 5.0);
      _transformationController.value = Matrix4.identity()..scale(newScale);
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details, Size size, DateTime start) {
    if (widget.readings.isEmpty) return;

    final localPos = details.localPosition;
    final width = size.width;
    final spanMs = widget.window.inMilliseconds.toDouble();

    GlucoseReading? closest;
    double minDistance = double.infinity;

    for (final r in widget.readings) {
      final frac = (r.timestamp.difference(start).inMilliseconds / spanMs).clamp(0.0, 1.0);
      final rx = frac * width;
      final dist = (localPos.dx - rx).abs();
      if (dist < minDistance) {
        minDistance = dist;
        closest = r;
      }
    }

    setState(() {
      _selectedReading = (_selectedReading == closest && minDistance > 40) ? null : closest;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readings.length < 2) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('Not enough data yet', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      );
    }

    final start = widget.now.subtract(widget.window);

    // Count disconnect gaps (> 7 mins apart)
    int gapCount = 0;
    for (int i = 0; i < widget.readings.length - 1; i++) {
      if (widget.readings[i + 1].timestamp.difference(widget.readings[i].timestamp).inMinutes > 7) {
        gapCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Zoom toolbar header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (_zoomScale > 1.05) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_in, size: 14, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          '${_zoomScale.toStringAsFixed(1)}x Zoom',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (gapCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.power_off_outlined, size: 13, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          '$gapCount Reading ${gapCount == 1 ? "Break" : "Breaks"}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _zoomIn,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  tooltip: 'Zoom In',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  onPressed: _zoomOut,
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  tooltip: 'Zoom Out',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                if (_zoomScale > 1.05)
                  TextButton.icon(
                    onPressed: _resetZoom,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Floating tooltip card if a reading point is tapped
        if (_selectedReading != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 6,
                  backgroundColor: AppColors.forClass(_selectedReading!.glucoseClass),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedReading!.mgDl.round()} mg/dL',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${_selectedReading!.glucoseClass.label})',
                  style: TextStyle(color: AppColors.forClass(_selectedReading!.glucoseClass), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Icon(Icons.schedule, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  DateFormat('HH:mm').format(_selectedReading!.timestamp),
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _selectedReading = null),
                  child: const Icon(Icons.close, size: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Interactive trend chart viewport
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: widget.height,
            color: const Color(0xFFFAFAFC),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onTapDown: (details) => _handleTap(details, size, start),
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 5.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: CustomPaint(
                      painter: _TrendPainter(
                        readings: widget.readings,
                        start: start,
                        span: widget.window,
                        selectedReading: _selectedReading,
                      ),
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Chart Legend & Disconnect Guide
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 14, height: 3, color: AppColors.accent),
                const SizedBox(width: 4),
                const Text('Glucose Trend', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 14,
                  height: 10,
                  child: CustomPaint(painter: _DashedLineLegendPainter()),
                ),
                const SizedBox(width: 4),
                const Text('Break / Disconnect', style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w500)),
              ],
            ),
            const Text(
              'Pinch to zoom & pan',
              style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.readings,
    required this.start,
    required this.span,
    this.selectedReading,
  });

  final List<GlucoseReading> readings;
  final DateTime start;
  final Duration span;
  final GlucoseReading? selectedReading;

  static const double _axisMin = 40;
  static const double _axisMax = 260;
  static const int _gapThresholdMinutes = 7; // Gap > 7 mins is a break in reading

  double _yFor(double mgDl, double height) {
    final t = ((mgDl - _axisMin) / (_axisMax - _axisMin)).clamp(0.0, 1.0);
    return height - t * height;
  }

  double _xFor(DateTime t, double width) {
    final frac = (t.difference(start).inMilliseconds / span.inMilliseconds).clamp(0.0, 1.0);
    return frac * width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lowY = _yFor(GlucoseClass.lowCutMgDl.toDouble(), size.height);
    final highY = _yFor(GlucoseClass.highCutMgDl.toDouble(), size.height);

    // Shaded classification threshold bands
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, highY), Paint()..color = AppColors.high.withValues(alpha: 0.07));
    canvas.drawRect(Rect.fromLTRB(0, highY, size.width, lowY), Paint()..color = AppColors.normal.withValues(alpha: 0.05));
    canvas.drawRect(Rect.fromLTRB(0, lowY, size.width, size.height), Paint()..color = AppColors.low.withValues(alpha: 0.07));

    // Threshold lines
    final dashPaint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    _drawDashedHorizontalLine(canvas, lowY, size.width, dashPaint);
    _drawDashedHorizontalLine(canvas, highY, size.width, dashPaint);

    // Threshold text markers on left
    const textStyle = TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500);
    final tpHigh = TextPainter(text: const TextSpan(text: '180 High', style: textStyle), textDirection: TextDirection.ltr)..layout();
    tpHigh.paint(canvas, Offset(6, highY - 14));

    final tpLow = TextPainter(text: const TextSpan(text: '70 Low', style: textStyle), textDirection: TextDirection.ltr)..layout();
    tpLow.paint(canvas, Offset(6, lowY + 3));

    if (readings.isEmpty) return;

    // Line paints
    final solidLinePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final gapDashedPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final gapFillPaint = Paint()..color = const Color(0xFFFDE68A).withValues(alpha: 0.25);

    // Plot segments and detect breaks in reading
    Path currentPath = Path();
    bool pathHasPoints = false;

    for (var i = 0; i < readings.length; i++) {
      final r = readings[i];
      final x = _xFor(r.timestamp, size.width);
      final y = _yFor(r.mgDl, size.height);

      if (!pathHasPoints) {
        currentPath.moveTo(x, y);
        pathHasPoints = true;
      } else {
        final prev = readings[i - 1];
        final prevX = _xFor(prev.timestamp, size.width);
        final prevY = _yFor(prev.mgDl, size.height);
        final gapMinutes = r.timestamp.difference(prev.timestamp).inMinutes;

        if (gapMinutes > _gapThresholdMinutes) {
          // Finish and draw solid path up to prev
          canvas.drawPath(currentPath, solidLinePaint);
          currentPath = Path()..moveTo(x, y);

          // Draw gap highlight region (shaded disconnect zone)
          final gapRect = Rect.fromLTRB(prevX, 0, x, size.height);
          canvas.drawRect(gapRect, gapFillPaint);

          // Draw dashed break line bridging the gap
          _drawDashedLine(canvas, Offset(prevX, prevY), Offset(x, y), gapDashedPaint);

          // Draw vertical dashed lines at disconnect start & end
          final edgePaint = Paint()
            ..color = const Color(0xFFD97706).withValues(alpha: 0.4)
            ..strokeWidth = 1;
          _drawDashedLine(canvas, Offset(prevX, 0), Offset(prevX, size.height), edgePaint);
          _drawDashedLine(canvas, Offset(x, 0), Offset(x, size.height), edgePaint);

          // Draw "Break" text badge if gap width is sufficiently wide (> 24px)
          if ((x - prevX) > 24) {
            final gapCenter = (prevX + x) / 2;
            final gapTp = TextPainter(
              text: TextSpan(
                text: '⚡ ${gapMinutes}m Break',
                style: const TextStyle(fontSize: 9.5, color: Color(0xFFB45309), fontWeight: FontWeight.bold),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            gapTp.paint(canvas, Offset((gapCenter - gapTp.width / 2).clamp(0, size.width - gapTp.width), 12));
          }
        } else {
          currentPath.lineTo(x, y);
        }
      }

      // Draw point node circle
      canvas.drawCircle(
        Offset(x, y),
        2.5,
        Paint()..color = AppColors.forClass(r.glucoseClass),
      );
    }

    if (pathHasPoints) {
      canvas.drawPath(currentPath, solidLinePaint);
    }

    // Highlight selected reading if tapped
    if (selectedReading != null) {
      final sx = _xFor(selectedReading!.timestamp, size.width);
      final sy = _yFor(selectedReading!.mgDl, size.height);

      // Vertical guide line
      canvas.drawLine(
        Offset(sx, 0),
        Offset(sx, size.height),
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.5)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );

      // Glowing selection node
      canvas.drawCircle(
        Offset(sx, sy),
        7,
        Paint()..color = AppColors.accent.withValues(alpha: 0.3),
      );
      canvas.drawCircle(
        Offset(sx, sy),
        4.5,
        Paint()..color = AppColors.forClass(selectedReading!.glucoseClass),
      );
    }

    // Latest reading pulsing indicator
    final last = readings.last;
    final lx = _xFor(last.timestamp, size.width);
    final ly = _yFor(last.mgDl, size.height);
    canvas.drawCircle(
      Offset(lx, ly),
      4.5,
      Paint()..color = AppColors.forClass(last.glucoseClass),
    );
  }

  void _drawDashedHorizontalLine(Canvas canvas, double y, double width, Paint paint) {
    _drawDashedLine(canvas, Offset(0, y), Offset(width, y), paint);
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashWidth = 5.0, gapWidth = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final direction = (b - a) / total;
    var covered = 0.0;
    while (covered < total) {
      final start = a + direction * covered;
      final end = a + direction * (covered + dashWidth).clamp(0, total);
      canvas.drawLine(start, end, paint);
      covered += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.readings != readings ||
        oldDelegate.start != start ||
        oldDelegate.span != span ||
        oldDelegate.selectedReading != selectedReading;
  }
}

class _DashedLineLegendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD97706)
      ..strokeWidth = 1.6;
    const dashWidth = 3.0, gapWidth = 2.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset((x + dashWidth).clamp(0, size.width), size.height / 2), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
