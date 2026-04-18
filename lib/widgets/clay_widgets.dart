import 'package:flutter/material.dart';

import 'responsive_text.dart';

const kClayBg = Color(0xFFECEFF8);
const kClayPrimary = Color(0xFF1A2561);
const kClaySub = Color(0xFF8A93B8);
const kClayHeroStart = Color(0xFF1A3A7A);
const kClayHeroEnd = Color(0xFF0D2460);

BoxDecoration clayCardDecoration({double radius = 20}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFB8C0DC).withValues(alpha: 0.75),
        offset: const Offset(6, 6),
        blurRadius: 16,
      ),
      const BoxShadow(
        color: Colors.white,
        offset: Offset(-5, -5),
        blurRadius: 12,
      ),
    ],
  );
}

class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 20.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: clayCardDecoration(radius: radius),
      child: child,
    );
  }
}

class ClaySubHeader extends StatelessWidget {
  const ClaySubHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB8C0DC).withValues(alpha: 0.65),
                      offset: const Offset(4, 4),
                      blurRadius: 10,
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      offset: Offset(-3, -3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: kClayPrimary,
                    ),
                    SizedBox(width: 4),
                    OneLineScaleText(
                      'Back',
                      style: TextStyle(
                        color: kClayPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: OneLineScaleText(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: kClayPrimary,
              ),
            ),
          ),
          ...(trailing == null ? const <Widget>[] : <Widget>[trailing!]),
        ],
      ),
    );
  }
}

class ClayDialogShell extends StatelessWidget {
  const ClayDialogShell({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.subtitle,
    this.icon,
    this.accentColor = kClayPrimary,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accentColor;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final iconTint = accentColor == kClayPrimary ? kClayPrimary : accentColor;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
        ),
        decoration: clayCardDecoration(radius: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: kClayPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kClayPrimary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(icon, color: iconTint, size: 22),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: kClayPrimary,
                          ),
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: kClaySub,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Row(children: actions),
            ),
          ],
        ),
      ),
    );
  }
}

class ClayDialogSection extends StatelessWidget {
  const ClayDialogSection({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
  });

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.trim().isNotEmpty) ...[
            Text(
              title!,
              style: const TextStyle(
                color: kClayPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: kClaySub,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

InputDecoration clayDialogInputDecoration({
  required String label,
  String? hintText,
  Widget? prefixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: Colors.white,
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(color: kClaySub, fontWeight: FontWeight.w700),
    hintStyle: const TextStyle(color: kClaySub, fontWeight: FontWeight.w600),
  );
}

Future<bool> showClayConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  Color accentColor = kClayPrimary,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final confirmColor = destructive ? const Color(0xFFAD5162) : accentColor;
      return ClayDialogShell(
        title: title,
        icon: icon,
        accentColor: confirmColor,
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: kClayPrimary,
                side: BorderSide(color: kClayPrimary.withValues(alpha: 0.18)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(cancelLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: confirmColor,
                backgroundColor: destructive
                    ? const Color(0xFFFFFBFC)
                    : const Color(0xFFF7F8FD),
                side: BorderSide(
                  color: confirmColor.withValues(
                    alpha: destructive ? 0.35 : 0.22,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(confirmLabel),
            ),
          ),
        ],
        child: ClayDialogSection(
          child: Text(
            message,
            style: const TextStyle(
              color: kClayPrimary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}
