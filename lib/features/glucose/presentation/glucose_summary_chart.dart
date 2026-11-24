import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/glucose_reading.dart';
import 'glucose_level_badge.dart';

class GlucoseSummaryChart extends StatelessWidget {
  const GlucoseSummaryChart({super.key, required this.readings});

  final List<GlucoseReading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Bu dönemde grafik için ölçüm yok.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    final sorted = List<GlucoseReading>.of(readings)
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final average =
        sorted.fold<double>(0, (sum, reading) => sum + reading.valueMgDl) /
        sorted.length;

    final targetCount = sorted.where((reading) {
      return reading.level.severity == GlucoseSeverity.target;
    }).length;

    final cautionCount = sorted.where((reading) {
      return reading.level.severity == GlucoseSeverity.caution;
    }).length;

    final alertCount = sorted.where((reading) {
      return reading.level.severity == GlucoseSeverity.alert;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              '${sorted.length} kayıtlı ölçüm. '
              'Ortalama ${average.toStringAsFixed(1)} mg/dL. '
              '$targetCount hedefte, '
              '$cautionCount turuncu grupta, '
              '$alertCount düşük veya çok yüksek grupta. '
              'Ayrıntılar Kayıtlar ekranında.',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _GlucoseChartPainter(
                  readings: sorted,
                  average: average,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _ChartLegend(
              label: 'Hedefte',
              color: GlucoseLevel.inTarget.color,
              icon: Icons.circle,
            ),
            _ChartLegend(
              label: 'Hedef dışı',
              color: GlucoseLevel.high.color,
              icon: Icons.diamond,
            ),
            _ChartLegend(
              label: 'Düşük / çok yüksek',
              color: GlucoseLevel.veryHigh.color,
              icon: Icons.square,
            ),
            const _ChartLegend(
              label: 'Ortalama',
              color: AppColors.primary,
              dashed: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          sorted.length == 1
              ? 'Tek ölçüm noktası gösteriliyor.'
              : 'Çizgiler yalnızca kayıtlı ölçümleri birleştirir.',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.label,
    required this.color,
    this.icon = Icons.circle,
    this.dashed = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          Text(
            '┄',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          )
        else
          Icon(icon, size: 10, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _GlucoseChartPainter extends CustomPainter {
  const _GlucoseChartPainter({required this.readings, required this.average});

  final List<GlucoseReading> readings;
  final double average;

  String _two(int value) => value.toString().padLeft(2, '0');

  String _time(DateTime value) {
    final date = value.toLocal();

    return '${_two(date.hour)}:${_two(date.minute)}';
  }

  String _date(DateTime value) {
    final date = value.toLocal();

    return '${_two(date.day)}.${_two(date.month)}';
  }

  void _text(
    Canvas canvas,
    String text,
    Offset position, {
    double align = 0,
    Color color = AppColors.muted,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    painter.paint(
      canvas,
      Offset(position.dx - painter.width * align, position.dy),
    );

    painter.dispose();
  }

  void _drawPoint(Canvas canvas, Offset point, GlucoseReading reading) {
    final level = reading.level;
    final fill = Paint()..color = level.color;
    final border = Paint()..color = Colors.white;

    switch (level.severity) {
      case GlucoseSeverity.target:
        canvas.drawCircle(point, 5, border);
        canvas.drawCircle(point, 3.5, fill);
        break;

      case GlucoseSeverity.caution:
        final outer = Path()
          ..moveTo(point.dx, point.dy - 6)
          ..lineTo(point.dx + 6, point.dy)
          ..lineTo(point.dx, point.dy + 6)
          ..lineTo(point.dx - 6, point.dy)
          ..close();

        final inner = Path()
          ..moveTo(point.dx, point.dy - 4.5)
          ..lineTo(point.dx + 4.5, point.dy)
          ..lineTo(point.dx, point.dy + 4.5)
          ..lineTo(point.dx - 4.5, point.dy)
          ..close();

        canvas.drawPath(outer, border);
        canvas.drawPath(inner, fill);
        break;

      case GlucoseSeverity.alert:
        canvas.drawRect(
          Rect.fromCenter(center: point, width: 10, height: 10),
          border,
        );

        canvas.drawRect(
          Rect.fromCenter(center: point, width: 7, height: 7),
          fill,
        );
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty || size.width <= 70) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final plot = Rect.fromLTRB(44, 10, size.width - 12, size.height - 30);

    final values = readings
        .map((reading) => reading.valueMgDl.toDouble())
        .toList(growable: false);

    final minimum = values.reduce((a, b) => math.min(a, b));
    final maximum = values.reduce((a, b) => math.max(a, b));

    final step = math.max(
      20.0,
      ((maximum - minimum) / 4 / 10).ceilToDouble() * 10,
    );

    var minY = (minimum / step).floorToDouble() * step;
    var maxY = (maximum / step).ceilToDouble() * step;

    if (minY == maxY) {
      minY = math.max(0.0, minY - step);
      maxY += step;
    }

    double yFor(double value) {
      return plot.bottom - ((value - minY) / (maxY - minY)) * plot.height;
    }

    final firstTime = readings.first.measuredAt.millisecondsSinceEpoch;
    final lastTime = readings.last.measuredAt.millisecondsSinceEpoch;
    final timeSpan = lastTime - firstTime;

    double xFor(GlucoseReading reading) {
      if (timeSpan == 0) return plot.center.dx;

      return plot.left +
          ((reading.measuredAt.millisecondsSinceEpoch - firstTime) / timeSpan) *
              plot.width;
    }

    final gridPaint = Paint()
      ..color = AppColors.lavender
      ..strokeWidth = 1;

    final ticks = ((maxY - minY) / step).round();

    for (var i = 0; i <= ticks; i++) {
      final value = minY + i * step;
      final y = yFor(value);

      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

      _text(
        canvas,
        value.toStringAsFixed(0),
        Offset(plot.left - 8, y - 7),
        align: 1,
      );
    }

    final averagePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.4;

    final averageY = yFor(average);

    for (double x = plot.left; x < plot.right; x += 10) {
      canvas.drawLine(
        Offset(x, averageY),
        Offset(math.min(x + 5, plot.right), averageY),
        averagePaint,
      );
    }

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final points = readings
        .map((reading) {
          return Offset(xFor(reading), yFor(reading.valueMgDl.toDouble()));
        })
        .toList(growable: false);

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, linePaint);

    for (var index = 0; index < readings.length; index++) {
      _drawPoint(canvas, points[index], readings[index]);
    }

    final firstDate = readings.first.measuredAt.toLocal();
    final lastDate = readings.last.measuredAt.toLocal();

    final sameDay = DateUtils.isSameDay(firstDate, lastDate);

    if (timeSpan == 0) {
      _text(
        canvas,
        _time(firstDate),
        Offset(plot.center.dx, plot.bottom + 8),
        align: 0.5,
      );
    } else {
      _text(
        canvas,
        sameDay ? _time(firstDate) : _date(firstDate),
        Offset(plot.left, plot.bottom + 8),
      );

      _text(
        canvas,
        sameDay ? _time(lastDate) : _date(lastDate),
        Offset(plot.right, plot.bottom + 8),
        align: 1,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlucoseChartPainter oldDelegate) {
    return oldDelegate.readings != readings || oldDelegate.average != average;
  }
}
