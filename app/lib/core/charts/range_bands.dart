import 'package:flutter/material.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../format/ar_format.dart';
import '../theme/tokens.dart';

class BandSpec {
  const BandSpec(this.key, this.label, this.range, this.color);
  final MetricKey key;
  final String label;
  final String range;
  final Color color;
}

/// Ordered from very high to very low, matching AGP report convention.
const bandSpecs = [
  BandSpec(MetricKey.timeVeryHigh, 'مرتفع جدًا', 'أعلى من 250', SpColors.bandVeryHigh),
  BandSpec(MetricKey.timeHigh, 'مرتفع', '181–250', SpColors.bandHigh),
  BandSpec(MetricKey.timeInRange, 'ضمن النطاق', '70–180', SpColors.bandInRange),
  BandSpec(MetricKey.timeLow, 'منخفض', '54–69', SpColors.bandLow),
  BandSpec(MetricKey.timeVeryLow, 'منخفض جدًا', 'أقل من 54', SpColors.bandVeryLow),
];

/// Horizontal 100 % strip. Segments are separated by a 2 px surface gap and
/// the ends are rounded. Missing bands are not drawn (never treated as zero).
class RangeStrip extends StatelessWidget {
  const RangeStrip({super.key, required this.report, this.height = 12});
  final CgmReport report;
  final double height;

  @override
  Widget build(BuildContext context) {
    final values = [for (final b in bandSpecs.reversed) (b, report.verifiedValue(b.key))];
    final present = values.where((v) => v.$2 != null && v.$2! > 0).toList();
    if (present.length < values.length && values.any((v) => v.$2 == null)) {
      return Container(
        height: height,
        decoration: BoxDecoration(color: SpColors.neutralSoft, borderRadius: BorderRadius.circular(height)),
        alignment: Alignment.center,
        child: const Text('لا تتوفر كل الفئات لرسم الشريط', style: TextStyle(fontFamily: spFontFamily, fontSize: 10, color: SpColors.inkSecondary)),
      );
    }
    final total = present.fold<double>(0, (a, v) => a + v.$2!);
    return Semantics(
      label: [for (final v in values) '${v.$1.label} ${ArFormat.number(v.$2 ?? 0)}٪'].join('، '),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Row(
            textDirection: TextDirection.ltr, // low → high, left to right, like the printed AGP strip
            children: [
              for (var i = 0; i < present.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: (present[i].$2! / total * 1000).round().clamp(1, 1000),
                  child: Container(color: present[i].$1.color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Legend table for the bands: colour swatch, name, range, value and the
/// general reference target when applicable.
class RangeLegend extends StatelessWidget {
  const RangeLegend({super.key, required this.report, required this.targets});
  final CgmReport report;
  final TargetSet targets;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final b in bandSpecs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: b.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: SpSpace.sm),
                Expanded(child: Text('${b.label} (${b.range})', style: t.bodyMedium)),
                if (targets[b.key] != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: SpSpace.sm),
                    child: Text('الهدف العام: ${targets[b.key]!.textAr}', style: t.labelSmall),
                  ),
                Text(ArFormat.metric(report.metrics[b.key]), style: t.titleSmall),
              ],
            ),
          ),
      ],
    );
  }
}
