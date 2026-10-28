import 'package:flutter/material.dart';
import 'package:sukkar_core/sukkar_core.dart';

import '../theme/tokens.dart';

/// White card with a hairline border and a restrained shadow.
class SpCard extends StatelessWidget {
  const SpCard({super.key, required this.child, this.padding = const EdgeInsets.all(SpSpace.lg), this.onTap, this.color, this.border = true});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SpRadius.card);
    return Container(
      decoration: BoxDecoration(
        color: color ?? SpColors.surface,
        borderRadius: radius,
        border: border ? Border.all(color: SpColors.border) : null,
        boxShadow: SpShadow.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Section title with an optional "view all" style action, as in the
/// reference layout ("نشاطك اليومي … عرض السجل").
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.subtitle});
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                if (subtitle != null) Text(subtitle!, style: t.bodySmall),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton.icon(
              onPressed: onAction,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

enum Tone { info, warning, critical, neutral, demo }

(Color, Color) toneColors(Tone t) => switch (t) {
      Tone.info => (SpColors.tealDeep, SpColors.infoSoft),
      Tone.warning => (SpColors.warning, SpColors.warningSoft),
      Tone.critical => (SpColors.critical, SpColors.criticalSoft),
      Tone.neutral => (SpColors.neutral, SpColors.neutralSoft),
      Tone.demo => (SpColors.demo, SpColors.demoSoft),
    };

/// Small status label: icon + text, never colour alone.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = Tone.neutral, this.icon});
  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SpRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: spFontFamily, fontSize: 11.5, fontWeight: FontWeight.w600, color: fg, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

/// Shows where a value came from (extracted / calculated / corrected /
/// entered) or that it is unavailable.
class OriginChip extends StatelessWidget {
  const OriginChip({super.key, required this.metric});
  final MetricValue? metric;

  @override
  Widget build(BuildContext context) {
    final m = metric;
    if (m == null || !m.isAvailable) {
      return const StatusChip(label: 'غير متاح', tone: Tone.neutral, icon: Icons.remove_circle_outline);
    }
    return switch (m.origin) {
      ValueOrigin.extractedFromReport => const StatusChip(label: 'مستخرج', tone: Tone.info, icon: Icons.description_outlined),
      ValueOrigin.calculatedFromReadings => const StatusChip(label: 'محسوب من القراءات', tone: Tone.info, icon: Icons.functions),
      ValueOrigin.calculatedFromMetrics => const StatusChip(label: 'محسوب', tone: Tone.info, icon: Icons.functions),
      ValueOrigin.userCorrected => const StatusChip(label: 'مصحّح يدويًا', tone: Tone.warning, icon: Icons.edit_outlined),
      ValueOrigin.userEntered => const StatusChip(label: 'مُدخل يدويًا', tone: Tone.neutral, icon: Icons.keyboard_outlined),
    };
  }
}

class SyntheticChip extends StatelessWidget {
  const SyntheticChip({super.key, this.show = true});
  final bool show;
  @override
  Widget build(BuildContext context) =>
      show ? const StatusChip(label: 'بيانات تجريبية', tone: Tone.demo, icon: Icons.science_outlined) : const SizedBox.shrink();
}

/// A note with an icon. Used for limitations, disclaimers and data warnings.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.tone = Tone.neutral, this.icon, this.title});
  final String text;
  final String? title;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = toneColors(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SpSpace.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SpRadius.inner)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _iconFor(tone), size: 18, color: fg),
          const SizedBox(width: SpSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: TextStyle(fontFamily: spFontFamily, fontWeight: FontWeight.w700, fontSize: 13.5, color: fg)),
                Text(text, style: const TextStyle(fontFamily: spFontFamily, fontSize: 13, height: 1.6, color: SpColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(Tone t) => switch (t) {
        Tone.info => Icons.info_outline,
        Tone.warning => Icons.warning_amber_rounded,
        Tone.critical => Icons.error_outline,
        Tone.neutral => Icons.info_outline,
        Tone.demo => Icons.science_outlined,
      };
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpSpace.xl, horizontal: SpSpace.lg),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: SpColors.tealSoft, shape: BoxShape.circle),
            child: Icon(icon, color: SpColors.tealDeep),
          ),
          const SizedBox(height: SpSpace.md),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: SpSpace.xs),
          Text(message, style: t.bodySmall, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: SpSpace.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'جارٍ التحميل…'});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6)),
            const SizedBox(height: SpSpace.md),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

/// Label on the start side, value on the end side.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({super.key, required this.label, required this.value, this.trailing, this.emphasize = false});
  final String label;
  final String value;
  final Widget? trailing;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(label, style: t.bodyMedium?.copyWith(color: SpColors.inkSecondary))),
          const SizedBox(width: SpSpace.sm),
          Expanded(
            flex: 4,
            child: Text(value,
                textAlign: TextAlign.end,
                style: emphasize ? t.titleSmall : t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (trailing != null) ...[const SizedBox(width: SpSpace.sm), trailing!],
        ],
      ),
    );
  }
}

/// Small metric with an icon, used in the home summary card (mirrors the
/// reference layout's time/distance/calories row).
class MiniMetric extends StatelessWidget {
  const MiniMetric({super.key, required this.icon, required this.color, required this.label, required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: SpSpace.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontFamily: spFontFamily, fontSize: 11.5, color: SpColors.inkSecondary)),
              Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: spFontFamily, fontSize: 13.5, fontWeight: FontWeight.w700, color: SpColors.ink)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page scaffold with standard padding and an optional bottom action.
class SpPage extends StatelessWidget {
  const SpPage({super.key, required this.title, required this.children, this.bottom, this.actions});
  final String title;
  final List<Widget> children;
  final Widget? bottom;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, SpSpace.xxl),
        children: children,
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(SpSpace.page, SpSpace.sm, SpSpace.page, SpSpace.md),
              child: bottom!,
            ),
    );
  }
}

class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, required String confirmLabel, bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(fontFamily: spFontFamily, height: 1.6)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: SpColors.critical) : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontFamily: spFontFamily))));
}
