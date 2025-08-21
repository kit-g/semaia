import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/androidstudio.dart';
export 'package:flutter_code_editor/flutter_code_editor.dart' show CodeController;
export 'package:highlight/languages/pgsql.dart' show pgsql;

class CodeEditor extends StatelessWidget {
  const CodeEditor({
    super.key,
    required this.codeController,
    this.enabled = true,
    this.contextMenuBuilder,
  });

  final CodeController codeController;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CodeTheme(
      data: CodeThemeData(
        styles: androidstudioTheme,
      ),
      child: Theme(
        data: ThemeData.dark(),
        child: CodeField(
          contextMenuBuilder: contextMenuBuilder,
          enabled: enabled,
          textStyle: const TextStyle(fontFamily: 'Mono'),
          controller: codeController,
          expands: true,
        ),
      ),
    );
  }
}
