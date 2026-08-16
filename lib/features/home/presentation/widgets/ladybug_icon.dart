import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LadybugIcon extends StatelessWidget {
  final double size;

  const LadybugIcon({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * (25 / 26),
      height: size,
      child: SvgPicture.asset(
        'assets/icons/ladybug.fill.svg',
        fit: BoxFit.contain,
      ),
    );
  }
}
