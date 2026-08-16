import 'package:flutter/material.dart';

/// Simple country flag widget using emoji flags
class CountryFlagWidget extends StatelessWidget {
  final String countryCode;
  final double width;
  final double height;

  const CountryFlagWidget({
    super.key,
    required this.countryCode,
    this.width = 32,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = _getCountryEmoji(countryCode);
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: height * 0.8),
        ),
      ),
    );
  }

  String _getCountryEmoji(String countryCode) {
    // Convert country code to emoji flag
    // Country codes are 2 letters, convert to regional indicator symbols
    final codePoints = countryCode
        .toUpperCase()
        .split('')
        .map((char) => 0x1F1E6 + (char.codeUnitAt(0) - 0x41))
        .toList();

    if (codePoints.length == 2) {
      return String.fromCharCodes(codePoints);
    }

    // Fallback: return a globe emoji
    return '🌍';
  }
}
