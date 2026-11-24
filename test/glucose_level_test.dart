import 'package:flutter_test/flutter_test.dart';
import 'package:track_diabetes/features/glucose/domain/glucose_reading.dart';

void main() {
  group('Glukoz seviye sınırları', () {
    for (final type in GlucoseType.values) {
      final cases = <(int, GlucoseLevel)>[
        (1, GlucoseLevel.veryLow),
        (53, GlucoseLevel.veryLow),
        (54, GlucoseLevel.low),
        (69, GlucoseLevel.low),
        (250, GlucoseLevel.high),
        (251, GlucoseLevel.veryHigh),
      ];

      for (final (value, expected) in cases) {
        test('${type.label}: $value mg/dL → ${expected.label}', () {
          expect(
            GlucoseLevel.evaluate(
              valueMgDl: value,
              type: type,
            ),
            expected,
          );
        });
      }
    }

    final fastingCases = <(int, GlucoseLevel)>[
      (70, GlucoseLevel.belowTarget),
      (79, GlucoseLevel.belowTarget),
      (80, GlucoseLevel.inTarget),
      (130, GlucoseLevel.inTarget),
      (131, GlucoseLevel.high),
    ];

    for (final (value, expected) in fastingCases) {
      test('Açlık hedef sınırı: $value', () {
        expect(
          GlucoseLevel.evaluate(
            valueMgDl: value,
            type: GlucoseType.fasting,
          ),
          expected,
        );
      });
    }

    final postMealCases = <(int, GlucoseLevel)>[
      (70, GlucoseLevel.inTarget),
      (130, GlucoseLevel.inTarget),
      (131, GlucoseLevel.inTarget),
      (179, GlucoseLevel.inTarget),
      (180, GlucoseLevel.high),
    ];

    for (final (value, expected) in postMealCases) {
      test('Tokluk hedef sınırı: $value', () {
        expect(
          GlucoseLevel.evaluate(
            valueMgDl: value,
            type: GlucoseType.postMeal,
          ),
          expected,
        );
      });
    }

    test('Düşük ölçümler kırmızı gruptadır', () {
      expect(
        GlucoseLevel.low.severity,
        GlucoseSeverity.alert,
      );

      expect(
        GlucoseLevel.veryLow.severity,
        GlucoseSeverity.alert,
      );
    });

    test('Geçersiz ölçüm hedefte olarak sınıflandırılmaz', () {
      expect(
        () => GlucoseLevel.evaluate(
          valueMgDl: 0,
          type: GlucoseType.fasting,
        ),
        throwsArgumentError,
      );
    });
  });
}