import 'dart:async';

import 'package:flutter/material.dart';

class BusyActionButton extends StatefulWidget {
  const BusyActionButton({
    super.key,
    required this.onPressed,
    required this.builder,
  });

  final FutureOr<void> Function() onPressed;
  final Widget Function(
    BuildContext context,
    bool busy,
    Future<void> Function() handlePressed,
  )
  builder;

  @override
  State<BusyActionButton> createState() => _BusyActionButtonState();
}

class _BusyActionButtonState extends State<BusyActionButton> {
  bool _busy = false;

  Future<void> _handlePressed() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await Future<void>.sync(widget.onPressed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _busy, _handlePressed);
  }
}
