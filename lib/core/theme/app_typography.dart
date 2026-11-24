import 'package:flutter/material.dart';

/// Uygulamadaki yazı boyutlarının tek kaynağı.
/// Telefonun erişilebilirlik için seçilen yazı ölçeği ayrıca uygulanır.
class AppTypography {
  AppTypography._();

  static const double captionSize = 14;
  static const double bodySize = 16;
  static const double bodyLargeSize = 18;
  static const double cardTitleSize = 18;
  static const double sectionTitleSize = 20;
  static const double pageTitleSize = 24;
  static const double metricCompactSize = 28;
  static const double metricSize = 32;
  static const double badgeSize = 14;
  static const double chartLabelSize = 14;
  static const double buttonSize = 18;
  static const double navigationLabelSize = 14;

  static const caption = TextStyle(fontSize: captionSize, height: 1.4);
  static const body = TextStyle(fontSize: bodySize, height: 1.45);
  static const button = TextStyle(
    fontSize: buttonSize,
    fontWeight: FontWeight.w600,
  );
  static const cardTitle = TextStyle(
    fontSize: cardTitleSize,
    fontWeight: FontWeight.w600,
  );
  static const sectionTitle = TextStyle(
    fontSize: sectionTitleSize,
    fontWeight: FontWeight.w700,
  );
  static const pageTitle = TextStyle(
    fontSize: pageTitleSize,
    fontWeight: FontWeight.w700,
  );

  static const textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: metricSize, fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontSize: metricSize, fontWeight: FontWeight.w700),
    displaySmall: TextStyle(fontSize: metricSize, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(fontSize: metricSize, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(
      fontSize: metricSize,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: TextStyle(
      fontSize: metricCompactSize,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: pageTitle,
    titleMedium: cardTitle,
    titleSmall: TextStyle(fontSize: bodySize, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: bodyLargeSize, height: 1.45),
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: TextStyle(fontSize: captionSize, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: captionSize, fontWeight: FontWeight.w500),
  );
}
