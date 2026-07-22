import 'package:flutter/material.dart';

class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key, this.onPressed, this.buttonKey});

  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final callback =
        onPressed ?? (canPop ? () => Navigator.of(context).maybePop() : null);
    if (callback == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        key: buttonKey,
        onPressed: callback,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('رجوع'),
      ),
    );
  }
}

class AppBarBackButton extends StatelessWidget {
  const AppBarBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final callback = onPressed ?? () => Navigator.of(context).maybePop();
    return TextButton.icon(
      onPressed: callback,
      icon: const Icon(Icons.arrow_forward_rounded),
      label: const Text('رجوع'),
    );
  }
}
