import 'package:flutter/material.dart';

/// Opens a form or selector using all of the device's available safe area.
Future<T?> showFullHeightFormModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final screenSize = MediaQuery.sizeOf(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints.tightFor(width: screenSize.width),
    builder: (modalContext) => SizedBox.expand(child: builder(modalContext)),
  );
}
