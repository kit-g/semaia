import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class StreamingMarkdownView extends StatefulWidget {
  const StreamingMarkdownView({super.key, required this.stream});

  final Stream<String?> stream;

  @override
  State<StreamingMarkdownView> createState() => _StreamingMarkdownViewState();
}

class _StreamingMarkdownViewState extends State<StreamingMarkdownView> {
  final _buffer = StringBuffer();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _buffer.write(snapshot.data);
        }

        if (_buffer.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating analysis...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'An error occurred while streaming the analysis:\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 60.0),
            child: MarkdownBody(
              selectable: true,
              data: _buffer.toString(),
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
                codeblockDecoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
