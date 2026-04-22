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

const double kClayDropdownRadius = 16;
const double kClayDropdownMenuMaxHeight = 320;

const _kClayDropdownLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w800,
  color: kClaySub,
);

const _kClayDropdownTextStyle = TextStyle(
  color: kClayPrimary,
  fontWeight: FontWeight.w800,
  fontSize: 14,
);

BoxDecoration clayDropdownDecoration({bool compact = false}) {
  return BoxDecoration(
    color: compact ? const Color(0xFFF7F8FD) : const Color(0xFFECEFF8),
    borderRadius: BorderRadius.circular(kClayDropdownRadius),
    border: Border.all(color: const Color(0xFFDDE3F0)),
    boxShadow: compact
        ? [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.28),
              offset: const Offset(2, 3),
              blurRadius: 8,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 6,
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFFB8C0DC).withValues(alpha: 0.52),
              offset: const Offset(4, 5),
              blurRadius: 13,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-3, -3),
              blurRadius: 9,
            ),
          ],
  );
}

class ClayDropdownField<T> extends StatelessWidget {
  const ClayDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.initialValue,
    this.icon,
    this.hintText,
    this.helperText,
    this.validator,
    this.compact = false,
    this.enabled = true,
  }) : assert(value == null || initialValue == null);

  final String label;
  final T? value;
  final T? initialValue;
  final IconData? icon;
  final String? hintText;
  final String? helperText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedValue = value ?? initialValue;
    final verticalPadding = compact ? 12.0 : 15.0;
    final field = DropdownButtonFormField<T>(
      initialValue: selectedValue,
      items: _premiumItems(items),
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      menuMaxHeight: kClayDropdownMenuMaxHeight,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(kClayDropdownRadius),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: kClaySub,
        size: 24,
      ),
      style: _kClayDropdownTextStyle.copyWith(fontSize: compact ? 13 : 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: kClayHeroStart, size: compact ? 18 : 20),
        filled: true,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 13 : 16,
          vertical: verticalPadding,
        ),
        labelStyle: _kClayDropdownLabelStyle,
        hintStyle: const TextStyle(
          color: kClaySub,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: const TextStyle(
          color: kClaySub,
          fontWeight: FontWeight.w600,
        ),
        errorMaxLines: 2,
      ),
    );

    return Container(
      width: double.infinity,
      decoration: clayDropdownDecoration(compact: compact),
      child: field,
    );
  }

  List<DropdownMenuItem<T>> _premiumItems(List<DropdownMenuItem<T>> source) {
    return source
        .map(
          (item) => DropdownMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            alignment: item.alignment,
            onTap: item.onTap,
            child: DefaultTextStyle.merge(
              style: _kClayDropdownTextStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: item.child,
            ),
          ),
        )
        .toList();
  }
}

class ClaySearchDropdownField<T> extends StatelessWidget {
  const ClaySearchDropdownField({
    super.key,
    required this.label,
    required this.entries,
    required this.onSelected,
    this.selectedValue,
    this.hintText,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final T? selectedValue;
  final String? hintText;
  final IconData? icon;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?>? onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;
        return Container(
          width: double.infinity,
          decoration: clayDropdownDecoration(),
          child: DropdownMenu<T>(
            key: ValueKey<Object?>(
              Object.hash(selectedValue, entries.length, enabled),
            ),
            width: width,
            menuHeight: kClayDropdownMenuMaxHeight,
            initialSelection: selectedValue,
            enabled: enabled,
            enableFilter: true,
            enableSearch: true,
            requestFocusOnTap: true,
            label: Text(label),
            hintText: hintText,
            leadingIcon: icon == null
                ? null
                : Icon(icon, color: kClayHeroStart, size: 20),
            trailingIcon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kClaySub,
            ),
            selectedTrailingIcon: const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: kClaySub,
            ),
            textStyle: _kClayDropdownTextStyle,
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              labelStyle: _kClayDropdownLabelStyle,
              hintStyle: TextStyle(
                color: kClaySub,
                fontWeight: FontWeight.w600,
              ),
            ),
            menuStyle: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
              surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
              elevation: const WidgetStatePropertyAll(10),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kClayDropdownRadius),
                ),
              ),
              side: const WidgetStatePropertyAll(
                BorderSide(color: Color(0xFFE6EAF6)),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 6),
              ),
              maximumSize: WidgetStatePropertyAll(
                Size(width, kClayDropdownMenuMaxHeight),
              ),
            ),
            dropdownMenuEntries: entries,
            onSelected: enabled ? onSelected : null,
          ),
        );
      },
    );
  }
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
      final confirmColor = destructive ? const Color(0xFFB91C1C) : accentColor;
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
                    ? const Color(0xFFFFF1F2)
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
