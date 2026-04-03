import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size,
    this.padding = 0,
    this.backgroundColor,
  });

  static const String assetPath = 'assets/images/hp_logo.webp';

  final double? size;
  final double padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    Widget logo = Padding(
      padding: EdgeInsets.all(padding),
      child: ClipOval(
        child: ColoredBox(
          color: Colors.white,
          child: Image.asset(assetPath, fit: BoxFit.cover),
        ),
      ),
    );

    if (backgroundColor != null) {
      logo = DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular((size ?? 40) / 2),
        ),
        child: logo,
      );
    }

    if (size == null) {
      return AspectRatio(aspectRatio: 1, child: logo);
    }

    return SizedBox(width: size, height: size, child: logo);
  }
}
