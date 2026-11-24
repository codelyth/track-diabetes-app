import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';

import '../domain/glucose_reading.dart';

extension GlucoseLevelStyle on GlucoseLevel {
  Color get color {
    return switch (severity) {
      GlucoseSeverity.target => const Color(0xFF18764A),
      GlucoseSeverity.caution => const Color(0xFFA65500),
      GlucoseSeverity.alert => const Color(0xFFB42318),
    };
  }

  Color get backgroundColor {
    return switch (severity) {
      GlucoseSeverity.target => const Color(0xFFEAF7EF),
      GlucoseSeverity.caution => const Color(0xFFFFF2DF),
      GlucoseSeverity.alert => const Color(0xFFFDECE9),
    };
  }

  IconData get icon {
    return switch (this) {
      GlucoseLevel.inTarget => Icons.check_circle_outline,
      GlucoseLevel.belowTarget ||
      GlucoseLevel.low ||
      GlucoseLevel.veryLow => Icons.arrow_downward_rounded,
      GlucoseLevel.high || GlucoseLevel.veryHigh => Icons.arrow_upward_rounded,
    };
  }
}

class GlucoseLevelBadge extends StatelessWidget {
  const GlucoseLevelBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  final GlucoseLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: level.backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: compact ? 14 : 17, color: level.color),
          const SizedBox(width: 5),
          Text(
            level.label,
            style: TextStyle(
              color: level.color,
              fontSize: AppTypography.badgeSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class GlucoseRangeNote extends StatelessWidget {
  const GlucoseRangeNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Genel referans: Açlık 80–130 mg/dL; '
      'öğün başlangıcından 1–2 saat sonraki tokluk '
      '70–179 mg/dL. 70’in altı düşük, 54’ün altı çok düşük, '
      '250’nin üstü çok yüksek olarak gösterilir. '
      'Kişisel hedefler doktorunuzun belirlediği aralığa göre değişebilir.',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: AppTypography.captionSize,
        height: 1.5,
      ),
    );
  }
}
