import 'package:flutter/material.dart';

const String _nbsp = '\u00A0';

String nonBreakingUiText(Object? value) {
  return (value?.toString() ?? '').trim().replaceAll(RegExp(r'\s+'), _nbsp);
}

class ResponsiveScale {
  const ResponsiveScale._(this.width);

  final double width;

  static ResponsiveScale of(BuildContext context) {
    return ResponsiveScale._(MediaQuery.sizeOf(context).width);
  }

  bool get isCompactPhone => width <= 360;
  bool get isLargePhone => width >= 430;

  double font(double base) {
    if (isCompactPhone) {
      return base * 0.92;
    }
    if (isLargePhone) {
      return base * 1.02;
    }
    return base;
  }

  double gap(double base) {
    if (isCompactPhone) {
      return base * 0.85;
    }
    if (isLargePhone) {
      return base * 1.05;
    }
    return base;
  }
}

class OneLineScaleText extends StatelessWidget {
  const OneLineScaleText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.alignment = Alignment.centerLeft,
    this.keepTogether = true,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Alignment alignment;
  final bool keepTogether;

  @override
  Widget build(BuildContext context) {
    final displayText = keepTogether ? nonBreakingUiText(text) : text;
    final textWidget = Text(
      displayText,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      textAlign: textAlign,
      style: style,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth.isInfinite) {
          return Text(
            displayText,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: style,
          );
        }

        return ClipRect(
          child: Align(
            alignment: alignment,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: alignment,
              child: textWidget,
            ),
          ),
        );
      },
    );
  }
}
