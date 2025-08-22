import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';
import 'package:semaia_language/semaia_language.dart';
import 'package:semaia_models/semaia_models.dart';
import 'package:semaia_state/semaia_state.dart';
import 'package:semaia/core/pluto/export.dart';
import 'package:semaia/core/utils/misc.dart';
import 'package:semaia/core/utils/visual.dart';
import 'package:semaia/presentation/widgets/loader.dart';
import 'package:semaia/presentation/widgets/query/query_results.dart';
import 'package:semaia/presentation/widgets/query/temperature_slider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ThreadsView extends StatefulWidget {
  const ThreadsView({super.key});

  @override
  State<ThreadsView> createState() => _ThreadsViewState();
}

class _ThreadsViewState extends State<ThreadsView> {
  final _loads = ValueNotifier(false);
  final _scrollController = ItemScrollController();

  @override
  void dispose() {
    _loads.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<Chats, bool>(
      selector: (_, provider) => provider.inListView,
      builder: (_, isListView, listView) {
        if (isListView) return listView!;
        return Selector<Chats, (bool, Chat)?>(
          selector: (_, provider) {
            return provider.thread(provider.selectedThread);
          },
          builder: (__, state, _) {
            if (state == null) return const SizedBox();
            final (initialized, thread) = state;
            if (!initialized) return const Loader();
            return _DetailView(
              onBack: () => Chats.of(context).inListView = true,
              thread: thread,
              loader: _loads,
              scrollController: _scrollController,
            );
          },
        );
      },
      child: _ListView(
        onTapThread: (thread) {
          _loads.value = true;
          Chats.of(context)
            ..inListView = false
            ..selectedThread = thread.id
            ..getThread(thread.id).then(
              (_) {
                _loads.value = false;
              },
            );
        },
        onEditThread: (thread, text) {
          Chats.of(context).renameThread(thread.id, text);
        },
      ),
    );
  }
}

class _DetailView extends StatefulWidget {
  final VoidCallback onBack;
  final Chat thread;
  final ValueNotifier<bool> loader;
  final ItemScrollController scrollController;

  const _DetailView({
    required this.onBack,
    required this.thread,
    required this.loader,
    required this.scrollController,
  });

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> with AfterLayoutMixin {
  late final ValueNotifier<int> _heartbeat;

  @override
  Widget build(BuildContext context) {
    final beads = Chats.watch(context).thread(widget.thread.id)!.$2.toList();
    return Column(
      children: [
        _ManagementRow(onBack: widget.onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ScrollablePositionedList.builder(
              itemScrollController: widget.scrollController,
              itemCount: beads.length,
              itemBuilder: (_, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _BeadItem(bead: beads[index]),
                );
              },
            ),
          ),
        ),
        _EditField(
          loader: widget.loader,
          thread: widget.thread,
          onResponse: () {},
        ),
      ],
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _heartbeat = Chats.of(context).heartbeat;
    _heartbeat.addListener(_scrollListener);
  }

  void _scrollListener() {
    final chats = Chats.of(context);
    final thread = chats.thread(chats.selectedThread)?.$2;
    if (thread == null) return;
    widget.scrollController.scrollTo(
      index: thread.length - 1,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _heartbeat.removeListener(_scrollListener);

    super.dispose();
  }
}

class _EditField extends StatelessWidget {
  final ValueNotifier<bool> loader;
  final Chat thread;
  final VoidCallback onResponse;

  const _EditField({
    required this.loader,
    required this.thread,
    required this.onResponse,
  });

  @override
  Widget build(BuildContext context) {
    final L(:askAI) = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);
    final controller = TextEditingController();
    return ValueListenableBuilder<bool>(
      valueListenable: loader,
      builder: (context, loading, _) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, v, _) {
            var enabled = !loading && controller.value.text.trim().isNotEmpty;
            return TextField(
              enabled: !loading,
              maxLines: 3,
              minLines: 1,
              controller: controller,
              decoration: InputDecoration(
                filled: true,
                hintText: askAI,
                suffixIcon: switch (loading) {
                  true => const SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(),
                  ),
                  false => Transform.rotate(
                    angle: -math.pi / 8,
                    child: IconButton(
                      tooltip: askAI,
                      onPressed: switch (enabled) {
                        false => null,
                        true => () => _onSubmit(context, controller),
                      },
                      icon: Icon(
                        Icons.send_rounded,
                        color: enabled ? colorScheme.primary : colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                },
              ),
            );
          },
        );
      },
    );
  }

  void _onSubmit(BuildContext context, TextEditingController controller) {
    loader.value = true;
    final connector = DatabaseInspector.of(context).selectedConnector;
    final prompt = controller.text.trim();
    Future<void> call = switch (thread.toList()) {
      [EmptyBead()] => Chats.of(context).initializeThread(prompt: prompt, connectorId: connector!.id!),
      _ => Chats.of(context).addToThread(thread.id, prompt: prompt),
    };
    call
        .then(
          (_) {
            loader.value = false;
            Future.delayed(const Duration(milliseconds: 50), onResponse);
          },
        )
        .catchError(
          (error) {
            if (context.mounted) {
              loader.value = false;
              snackOnError(context, error);
            }
          },
        );
  }
}

class _ListView extends StatelessWidget {
  final void Function(Chat) onTapThread;
  final void Function(Chat, String) onEditThread;

  const _ListView({
    required this.onTapThread,
    required this.onEditThread,
  });

  @override
  Widget build(BuildContext context) {
    final threads = Chats.watch(context).toList()..sort();
    final L(:threadsEmptyStateTitle, :threadsEmptyStateBody) = L.of(context);
    if (threads.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              threadsEmptyStateTitle,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              threadsEmptyStateBody,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: threads.length,
      itemBuilder: (_, index) {
        final thread = threads[index];
        return _ThreadItem(
          thread: thread,
          onTap: onTapThread,
          onEdit: onEditThread,
        );
      },
    );
  }
}

class _BeadItem extends StatefulWidget {
  final Bead bead;

  const _BeadItem({
    required this.bead,
  });

  @override
  State<_BeadItem> createState() => _BeadItemState();
}

class _BeadItemState extends State<_BeadItem> {
  late PlutoGridStateManager stateManager;

  @override
  Widget build(BuildContext context) {
    final L(copyToClipboard: copy, :copied, :exportToCsv) = L.of(context);
    return Column(
      children: [
        _OwnMessage(bead: widget.bead),
        const SizedBox(height: 8),
        if (widget.bead.queryResult case SqlQueryResult result) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: QueryResultsView(
              queryResult: result,
              onGridManagerReady: (v) => stateManager = v,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => exportToCsvFile(stateManager),
              child: Tooltip(
                message: exportToCsv,
                child: const Icon(
                  Icons.download_for_offline_outlined,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
        Builder(
          builder: (context) {
            try {
              return Column(
                children: [
                  SelectionArea(
                    child: MarkdownBody(
                      data: widget.bead.llmResponse,
                      selectable: false,
                    ),
                  ),
                  Tooltip(
                    message: copy,
                    child: GestureDetector(
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            Icons.copy,
                            size: 16,
                          ),
                        ),
                      ),
                      onTap: () {
                        copyToClipboard(widget.bead.llmResponse);
                        snack(context, copied);
                      },
                    ),
                  ),
                ],
              );
            } on UnimplementedError {
              return const SizedBox.shrink();
            }
          },
        ),
      ],
    );
  }
}

class _OwnMessage extends StatelessWidget {
  final Bead bead;

  const _OwnMessage({required this.bead});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :primaryTextTheme, :textTheme) = Theme.of(context);
    Color color;
    try {
      color = Chats.temperatureColor(bead.temperature);
    } on UnimplementedError {
      color = Chats.temperatureColor(.7);
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: LayoutBuilder(
          builder: (context, box) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * .7),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceDim,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Builder(
                      builder: (context) {
                        try {
                          return SelectableText(bead.prompt);
                        } on UnimplementedError {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                    if (bead.sqlQuery case String query)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              query,
                              textAlign: TextAlign.start,
                              style: primaryTextTheme.bodySmall?.copyWith(color: colorScheme.onPrimary),
                            ),
                            Tooltip(
                              message: L.of(context).copyToClipboard,
                              child: GestureDetector(
                                onTap: () {
                                  copyToClipboard(query);
                                  snack(context, L.of(context).copied);
                                },
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Icon(
                                    Icons.copy,
                                    color: colorScheme.onPrimary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Selector<Chats, double>(
                      selector: (_, provider) => provider.currentTemperature,
                      builder: (context, temp, _) {
                        try {
                          return Text(
                            L.of(context).temperatureLabel(bead.temperature),
                            style: textTheme.labelSmall,
                          );
                        } on UnimplementedError {
                          return Text(
                            L.of(context).temperatureLabel(temp),
                            style: textTheme.labelSmall,
                          );
                        }
                      },
                    ),
                    switch (bead.model) {
                      'None' => Selector<Chats, String>(
                        selector: (_, provider) => provider.model.value,
                        builder: (_, model, __) {
                          return Text(
                            L.of(context).modelLabel(model),
                            style: textTheme.labelSmall,
                          );
                        },
                      ),
                      _ => Text(
                        L.of(context).modelLabel(bead.model),
                        style: textTheme.labelSmall,
                      ),
                    },
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ManagementRow extends StatelessWidget {
  final VoidCallback onBack;

  const _ManagementRow({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final L(:toListView, :temperatureDefinition) = L.of(context);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: toListView,
            iconSize: 24,
            splashRadius: 12,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Selector<Chats, LLM>(
            selector: (_, provider) => provider.model,
            builder: (context, model, _) {
              return DropdownButton<LLM>(
                items: LLM.values.map(
                  (m) {
                    return DropdownMenuItem<LLM>(
                      value: m,
                      child: Text(m.value),
                    );
                  },
                ).toList(),
                value: model,
                onChanged: (v) {
                  if (v != null) {
                    Chats.of(context).model = v;
                  }
                },
              );
            },
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 40),
            child: Selector<Chats, (double, Color)>(
              selector: (_, provider) => (provider.currentTemperature, provider.currentTemperatureColor),
              builder: (context, params, _) {
                final (temp, color) = params;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TemperatureSlider(
                    onChanged: (v) => Chats.of(context).currentTemperature = v,
                    temperature: temp,
                    color: color,
                  ),
                );
              },
            ),
          ),
          Tooltip(
            message: temperatureDefinition,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.help_outline_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadItem extends StatefulWidget {
  final Chat thread;
  final void Function(Chat) onTap;
  final void Function(Chat, String) onEdit;

  const _ThreadItem({
    required this.thread,
    required this.onTap,
    required this.onEdit,
  });

  @override
  State<_ThreadItem> createState() => _ThreadItemState();
}

class _ThreadItemState extends State<_ThreadItem> {
  final _editing = ValueNotifier(false);
  final _controller = TextEditingController();

  @override
  void dispose() {
    _editing.dispose();
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:edit, :delete, :save, :close) = L.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _editing,
      builder: (context, editing, child) {
        if (editing) {
          return TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.thread.name,
              filled: true,
              suffix: SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: close,
                      onPressed: () => _editing.value = false,
                      icon: const Icon(Icons.close),
                    ),
                    IconButton(
                      tooltip: save,
                      onPressed: () {
                        _editing.value = false;
                        if (_controller.text.trim() case String s when s.isNotEmpty) {
                          widget.onEdit(widget.thread, s);
                        }
                      },
                      icon: const Icon(Icons.done),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return child!;
      },
      child: ListTile(
        onTap: () => widget.onTap(widget.thread),
        title: Text(
          switch (widget.thread.name) {
            String name when name.isNotEmpty => name,
            _ => widget.thread.createdAt.formatted,
          },
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 80,
          child: Row(
            children: [
              IconButton(
                tooltip: edit,
                onPressed: () {
                  _editing.value = true;
                  if (widget.thread case Chat(:String name, :String? initialQuery) when name != initialQuery) {
                    _controller.text = name;
                  }
                },
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: delete,
                onPressed: () => _onDelete(context),
                icon: const Icon(Icons.delete_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDelete(BuildContext context) {
    final L(:deleteThread, :cannotBeUndone, :delete, :cancel) = L.of(context);
    showAdaptiveDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(deleteThread),
          content: Text(cannotBeUndone),
          actions: <Widget>[
            TextButton(
              child: Text(cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(delete),
              onPressed: () {
                Navigator.of(context).pop();
                Chats.of(context).deleteThread(widget.thread.id);
              },
            ),
          ],
        );
      },
    );
  }
}

String _pad(int i) => '$i'.padLeft(2, '0');

extension on DateTime {
  String get formatted {
    return '${_pad(year)}-${_pad(month)}-${_pad(day)}';
  }
}
