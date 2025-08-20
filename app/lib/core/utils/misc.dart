import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

mixin AfterLayoutMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (mounted) {
          afterFirstLayout(context);
        }
      },
    );
  }

  void afterFirstLayout(BuildContext context);
}

void copyToClipboard(String content) {
  Clipboard.setData(ClipboardData(text: content));
}

List<T> insertBetween<T>(List<T> list, T element) {
  if (list.isEmpty) return list;

  return list.expand((item) sync* {
    yield item;
    if (item != list.last) yield element;
  }).toList();
}
