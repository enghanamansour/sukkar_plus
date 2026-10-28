import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format/ar_format.dart';
import '../theme/tokens.dart';

enum PointShape { circle, diamond }

class ChartSeries {
  const ChartSeries({required this.name, required this.color, required this.points, this.shape = PointShape.circle, this.dashed = false});
  final String name;
  final Color color;
  final List<ChartPoint> points;
  final PointShape shape;
  final bool dashed;
}

class ChartPoint {
  const ChartPoint(this.date, this.value, {this.note});
  final DateTime date;
  final double value;
  final String? note;
}

/// A small dated line chart on a single y-axis. Time runs in the reading
/// direction (right → left in RTL). Tap a point to inspect it; a table view
/// below the chart lists every point so identity never relies on colour.
class TrendChart extends StatefulWidget {
  const TrendChart({super.key, required this.series, required this.unit, this.height = 190, this.showTable = true});
  final List<ChartSeries> series;
  final String unit;
  final double height;
  final bool showTable;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  (int, int)? _selected;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final all = widget.series.expand((s) => s.points).toList();
    if (all.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final sel = _selected;
    final selPoint = sel == null ? null : widget.series[sel.$1].points[sel.$2];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.series.length > 1)
          Wrap(
            spacing: SpSpace.lg,
            runSpacing: SpSpace.xs,
            children: [
              for (final s in widget.series)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  CustomPaint(size: const Size(12, 12), painter: _MarkerPainter(s.color, s.shape)),
                  const SizedBox(width: 6),
                  Text(s.name, style: t.labelMedium),
                ]),
            ],
          ),
        const SizedBox(height: SpSpace.sm),
        LayoutBuilder(builder: (context, c) {
          final layout = _Layout(widget.series, Size(c.maxWidth, widget.height), rtl);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => setState(() => _selected = layout.hit(d.localPosition)),
            child: CustomPaint(
              size: Size(c.maxWidth, widget.height),
              painter: _TrendPainter(layout, widget.series, _selected, widget.unit),
            ),
          );
        }),
        if (selPoint != null)
          Padding(
            padding: const EdgeInsets.only(top: SpSpace.xs),
            child: Text(
              '${widget.series[sel!.$1].name}: ${ArFormat.number(selPoint.value, decimals: 2)}${widget.unit} — ${ArFormat.date(selPoint.date)}${selPoint.note == null ? '' : ' (${selPoint.note})'}',
              style: t.bodySmall?.copyWith(color: SpColors.ink),
            ),
          ),
        if (widget.showTable) ...[
          const SizedBox(height: SpSpace.sm),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('عرض القيم في جدول', style: t.labelLarge?.copyWith(color: SpColors.tealDeep)),
              children: [
                for (final s in widget.series)
                  for (final p in s.points)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(child: Text('${s.name} — ${ArFormat.date(p.date)}', style: t.bodySmall)),
                        Text('${ArFormat.number(p.value, decimals: 2)}${widget.unit}', style: t.titleSmall),
                      ]),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Layout {
  _Layout(this.series, this.size, this.rtl) {
    final all = series.expand((s) => s.points).toList();
    var minV = all.map((p) => p.value).reduce(math.min);
    var maxV = all.map((p) => p.value).reduce(math.max);
    final pad = math.max(0.3, (maxV - minV) * 0.25);
    minV -= pad;
    maxV += pad;
    yMin = minV;
    yMax = maxV;
    final dates = all.map((p) => p.date.millisecondsSinceEpoch).toList();
    tMin = dates.reduce(math.min).toDouble();
    tMax = dates.reduce(math.max).toDouble();
    if (tMax == tMin) {
      tMin -= 86400000 * 15;
      tMax += 86400000 * 15;
    }
  }

  final List<ChartSeries> series;
  final Size size;
  final bool rtl;
  late final double yMin, yMax, tMin, tMax;

  static const left = 36.0, right = 14.0, top = 10.0, bottom = 26.0;

  Rect get plot => Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

  Offset pos(ChartPoint p) {
    final fx = (p.date.millisecondsSinceEpoch - tMin) / (tMax - tMin);
    final x = rtl ? plot.right - fx * plot.width : plot.left + fx * plot.width;
    final y = plot.bottom - (p.value - yMin) / (yMax - yMin) * plot.height;
    return Offset(x, y);
  }

  (int, int)? hit(Offset o) {
    (int, int)? best;
    var bestD = 28.0; // hit target larger than the mark
    for (var s = 0; s < series.length; s++) {
      for (var i = 0; i < series[s].points.length; i++) {
        final d = (pos(series[s].points[i]) - o).distance;
        if (d < bestD) {
          bestD = d;
          best = (s, i);
        }
      }
    }
    return best;
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.l, this.series, this.selected, this.unit);
  final _Layout l;
  final List<ChartSeries> series;
  final (int, int)? selected;
  final String unit;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = l.plot;
    final grid = Paint()
      ..color = SpColors.border
      ..strokeWidth = 1;
    const ticks = 4;
    for (var i = 0; i <= ticks; i++) {
      final v = l.yMin + (l.yMax - l.yMin) * i / ticks;
      final y = plot.bottom - plot.height * i / ticks;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(canvas, ArFormat.number(v), Offset(2, y - 7), SpColors.inkMuted, 10);
    }
    // x labels: first and last date
    final all = series.expand((s) => s.points).toList()..sort((a, b) => a.date.compareTo(b.date));
    final first = all.first, last = all.last;
    for (final p in {first, last}) {
      final x = l.pos(p).dx;
      _text(canvas, ArFormat.shortDate(p.date), Offset(x - 22, plot.bottom + 6), SpColors.inkMuted, 10);
    }

    for (var s = 0; s < series.length; s++) {
      final ser = series[s];
      final pts = [...ser.points]..sort((a, b) => a.date.compareTo(b.date));
      if (pts.length > 1) {
        final path = Path()..moveTo(l.pos(pts.first).dx, l.pos(pts.first).dy);
        for (final p in pts.skip(1)) {
          path.lineTo(l.pos(p).dx, l.pos(p).dy);
        }
        final stroke = Paint()
          ..color = ser.color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        if (ser.dashed) {
          for (final metric in path.computeMetrics()) {
            var d = 0.0;
            while (d < metric.length) {
              canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), stroke);
              d += 10;
            }
          }
        } else {
          canvas.drawPath(path, stroke);
        }
      }
      for (var i = 0; i < ser.points.length; i++) {
        final o = l.pos(ser.points[i]);
        final isSel = selected != null && selected!.$1 == s && selected!.$2 == i;
        // 2 px surface ring keeps overlapping markers legible.
        _marker(canvas, o, isSel ? 7.5 : 6, SpColors.surface, ser.shape);
        _marker(canvas, o, isSel ? 5.5 : 4.5, ser.color, ser.shape);
      }
      // Direct label on the latest point only.
      final latest = pts.last;
      final lo = l.pos(latest);
      _text(canvas, '${ArFormat.number(latest.value)}$unit', Offset(lo.dx - 16, lo.dy - 22), SpColors.ink, 11, bold: true);
    }
  }

  void _marker(Canvas c, Offset o, double r, Color color, PointShape shape) {
    final p = Paint()..color = color;
    if (shape == PointShape.circle) {
      c.drawCircle(o, r, p);
    } else {
      final path = Path()
        ..moveTo(o.dx, o.dy - r - 1)
        ..lineTo(o.dx + r + 1, o.dy)
        ..lineTo(o.dx, o.dy + r + 1)
        ..lineTo(o.dx - r - 1, o.dy)
        ..close();
      c.drawPath(path, p);
    }
  }

  void _text(Canvas c, String s, Offset at, Color color, double size, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: spFontFamily, fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.selected != selected || old.series != series;
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter(this.color, this.shape);
  final Color color;
  final PointShape shape;
  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(size.width / 2, size.height / 2);
    final p = Paint()..color = color;
    if (shape == PointShape.circle) {
      canvas.drawCircle(o, 5, p);
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(o.dx, o.dy - 6)
            ..lineTo(o.dx + 6, o.dy)
            ..lineTo(o.dx, o.dy + 6)
            ..lineTo(o.dx - 6, o.dy)
            ..close(),
          p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
