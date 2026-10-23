import 'package:flutter/material.dart';

class OperationActionButton extends StatelessWidget {
  const OperationActionButton({
    required this.icon,
    required this.tooltip,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.onPressed,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isEnabled
            ? backgroundColor
            : backgroundColor.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isEnabled ? borderColor : borderColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: iconColor.withValues(alpha: 0.15),
          highlightColor: iconColor.withValues(alpha: 0.08),
          child: Semantics(
            button: true,
            label: tooltip,
            enabled: isEnabled,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 48),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(color: iconColor, size: 24),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
