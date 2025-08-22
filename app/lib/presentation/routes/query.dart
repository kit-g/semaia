import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:semaia/presentation/widgets/query/inspector/lib.dart';
import 'package:semaia_api/semaia_api.dart';
import 'package:semaia_language/semaia_language.dart';
import 'package:semaia_models/semaia_models.dart';
import 'package:semaia_state/semaia_state.dart';
import 'package:semaia/core/pluto/export.dart';
import 'package:semaia/core/utils/misc.dart';
import 'package:semaia/core/utils/visual.dart';
import 'package:semaia/presentation/navigation/router.dart';
import 'package:semaia/presentation/widgets/query/code_editor.dart';
import 'package:semaia/presentation/widgets/loader.dart';
import 'package:semaia/presentation/widgets/query/query_badge.dart';
import 'package:semaia/presentation/widgets/query/query_results.dart';
import 'package:semaia/presentation/widgets/query/threads.dart';

class RunQueryIntent extends Intent {}

class _QueryResult with ChangeNotifier {
  SqlQueryResult? _value;

  SqlQueryResult? get value => _value;

  set value(SqlQueryResult? value) {
    _value = value;
    notifyListeners();
  }
}

class _RunQueryIntent extends Intent {}

class QueryPage extends StatefulWidget {
  const QueryPage({super.key});

  @override
  State<QueryPage> createState() => _QueryPageState();
}

class _QueryPageState extends State<QueryPage> with AfterLayoutMixin<QueryPage> {
  final _queryResult = _QueryResult();
  final _queryLoader = ValueNotifier(false);
  final _dialogCodeController = CodeController(language: pgsql);
  final _codeController = CodeController(language: pgsql);
  final _inConversation = ValueNotifier(false);
  late PlutoGridStateManager _queryResultsStateManager;

  @override
  void initState() {
    super.initState();

    _codeController.addListener(_codeListener);
  }

  @override
  void dispose() {
    _queryResult.dispose();
    _queryLoader.dispose();
    _codeController
      ..removeListener(_codeListener)
      ..dispose();
    _dialogCodeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(
      colorScheme: ColorScheme(secondary: dividerColor),
    ) = Theme.of(
      context,
    );

    final queryConsoleShortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.enter, meta: true): _RunQueryIntent(),
    };

    final queryConsoleActions = <Type, Action<Intent>>{
      _RunQueryIntent: CallbackAction<_RunQueryIntent>(
        onInvoke: (_) {
          _runSelectedQueryOrDefault();
          return null;
        },
      ),
    };

    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 4,
        dividerPainter: DividerPainter(
          backgroundColor: dividerColor,
          animationEnabled: true,
        ),
      ),
      child: MultiSplitView(
        axis: Axis.horizontal,
        initialAreas: [
          Area(
            builder: (context, area) {
              return MultiSplitView(
                axis: Axis.vertical,
                initialAreas: [
                  Area(
                    builder: (context, area) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _inConversation,
                        builder: (_, inConversation, console) {
                          if (inConversation) {
                            return MultiSplitView(
                              axis: Axis.horizontal,
                              initialAreas: [
                                Area(
                                  builder: (_, __) => console!,
                                  flex: 5,
                                ),
                                Area(
                                  builder: (_, __) {
                                    return const ThreadsView();
                                  },
                                  flex: 3,
                                ),
                              ],
                            );
                          }
                          return console!;
                        },
                        child: Stack(
                          children: [
                            Shortcuts(
                              shortcuts: queryConsoleShortcuts,
                              child: Actions(
                                actions: queryConsoleActions,
                                child: Focus(
                                  child: CodeEditor(
                                    codeController: _codeController,
                                    contextMenuBuilder: (_, editableTextState) {
                                      return AdaptiveTextSelectionToolbar.buttonItems(
                                        anchors: editableTextState.contextMenuAnchors,
                                        buttonItems: [
                                          ContextMenuButtonItem(
                                            label: L.of(context).shareLink,
                                            onPressed: () {
                                              ContextMenuController.removeAny();

                                              final link = context.shareQuery(_codeController.selectedText);
                                              copyToClipboard(link);
                                              snack(context, L.of(context).copied);
                                            },
                                          ),
                                          ContextMenuButtonItem(
                                            label: L.of(context).runQueryAndStartThread,
                                            onPressed: () {
                                              ContextMenuController.removeAny();
                                              _inConversation.value = true;
                                              Chats.of(context)
                                                ..startEmptyThread(query: _codeController.selectedText.trim())
                                                ..selectedThread = emptyThreadId
                                                ..inListView = false;
                                            },
                                          ),
                                          ContextMenuButtonItem(
                                            label: L.of(context).runQuery,
                                            onPressed: () {
                                              ContextMenuController.removeAny();
                                              final query = _codeController.selectedText;
                                              _runQuery(query);
                                            },
                                          ),
                                          ...editableTextState.contextMenuButtonItems,
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _inConversation,
                                builder: (__, inConversation, _) {
                                  return _ManagementRow(
                                    onThreads: () => _inConversation.value = !_inConversation.value,
                                    open: inConversation,
                                  );
                                },
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: ListenableBuilder(
                                listenable: _queryLoader,
                                builder: (__, _) {
                                  return switch (_queryResult.value) {
                                    SqlQueryResult v => QueryBadge(
                                      queryResult: v,
                                      onRefresh: () => _runQuery(v.query),
                                      onShare: () {
                                        copyToClipboard(v.query);
                                        snack(context, L.of(context).copied);
                                      },
                                      onExport: () => exportToCsvFile(_queryResultsStateManager),
                                    ),
                                    null => const SizedBox(),
                                  };
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Area(
                    size: 400,
                    builder: (context, area) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _queryLoader,
                        builder: (context, loading, child) {
                          return Stack(
                            children: [
                              child!,
                              if (loading) const ExpandedLoader(),
                            ],
                          );
                        },
                        child: ListenableBuilder(
                          listenable: _queryResult,
                          builder: (__, _) {
                            return switch (_queryResult.value) {
                              SqlQueryResult v => QueryResultsView(
                                queryResult: v,
                                onGridManagerReady: (raw) => _queryResultsStateManager = raw,
                              ),
                              null => const SizedBox(),
                            };
                          },
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          Area(
            size: 350,
            builder: (context, area) {
              return Inspector(
                onDoubleTapTable: (table) {
                  _runQuery('SELECT * FROM ${table.schema}.${table.name} LIMIT 100;');
                },
                onDoubleTapTrigger: (connector, schema, table, trigger) {
                  if (connector.id case String connectorId) {
                    _getDefinition(
                      () => Api.instance.getTriggerDefinition(
                        connectorId,
                        schema.name,
                        table.name,
                        trigger.name,
                      ),
                    );
                    _showEditorDialog(context);
                  }
                },
                onDoubleTapRoutine: (connector, schema, routine) {
                  if (connector.id case String connectorId) {
                    _getDefinition(() => Api.instance.getRoutineDefinition(connectorId, schema.name, routine.name));
                    _showEditorDialog(context);
                  }
                },
                onDoubleTapConnector: (connector) {
                  DatabaseInspector.of(context).inspect(connector);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleError(dynamic error) {
    switch (error) {
      case ArgumentError e:
        switch (e.message) {
          case {'error': String error}:
            final L(copyToClipboard: copy) = L.of(context);
            snack(
              context,
              error,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: copy,
                onPressed: () {
                  copyToClipboard(error);
                },
              ),
            );
            _queryLoader.value = false;
        }
      case ExcessiveQuery():
        snack(context, L.of(context).excessiveQueryError);
        _queryLoader.value = false;
    }
  }

  Future<void> _runQuery(String query) async {
    _queryLoader.value = true;
    var connectorId = DatabaseInspector.of(context).selectedConnector?.id;
    if (connectorId == null) return;
    return Api.instance
        .sendQuery(connectorId, query)
        .then<void>(
          (result) {
            _queryResult.value = result;
            _queryLoader.value = false;
          },
        )
        .catchError(_handleError);
  }

  Future<void> _runSelectedQueryOrDefault() async {
    switch (_codeController) {
      case CodeController(:String selectedText) when selectedText.isNotEmpty:
        return _runQuery(selectedText);
      case CodeController(:String fullText) when fullText.isNotEmpty:
        switch (fullText.split(';')) {
          case [String query, ...]:
            return _runQuery(query);
          case _:
            return _runQuery(fullText);
        }
    }
  }

  Future<void> _getDefinition(Future<DbPart> Function() callback) async {
    _queryLoader.value = true;
    final dbPart = await callback();
    if (dbPart.definition case String definition) {
      _dialogCodeController.text = definition;
      _queryLoader.value = false;
    }
  }

  Future<void> _showEditorDialog(BuildContext context) async {
    final L(:copied, copyToClipboard: ctc, :close) = L.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: _queryLoader,
            builder: (context, loading, child) {
              return Stack(
                children: [
                  if (loading) const ExpandedLoader() else child!,
                ],
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                children: [
                  CodeEditor(
                    codeController: _dialogCodeController,
                    enabled: false,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: ctc,
                            onPressed: () {
                              Navigator.of(context).pop();
                              copyToClipboard(_dialogCodeController.fullText);
                              _dialogCodeController.clear();
                              snack(context, copied);
                            },
                            icon: const Icon(Icons.copy),
                          ),
                          IconButton(
                            tooltip: close,
                            onPressed: () {
                              Navigator.of(context).pop();
                              _dialogCodeController.clear();
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _codeListener() {
    Preferences.of(context).saveQuery(_codeController.fullText);
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _initializeCodeController(context);
  }

  Future<void> _initializeCodeController(BuildContext context) async {
    var prefs = Preferences.of(context);
    const maxAttempts = 40; // 20 seconds
    int attempts = 0;

    void init() {
      if (prefs.getQuery() case String query when query.isNotEmpty) {
        // there is an encoded shared chunk in the query param
        if (context.queryParameters case {'q': String q} when q.isNotEmpty) {
          _codeController.fullText = '$query\n--\n${Uri.decodeComponent(q)}';
        } else {
          _codeController.fullText = query;
        }
      } else {
        if (context.queryParameters case {'q': String q} when q.isNotEmpty) {
          _codeController.fullText = '--\n${Uri.decodeComponent(q)}';
        }
      }
    }

    Future<void> wait() => Future.delayed(const Duration(milliseconds: 50));

    while (!prefs.isInitialized && attempts < maxAttempts) {
      attempts++;
      await wait();
    }

    if (prefs.isInitialized) {
      return init();
    }
  }
}

extension on CodeController {
  String get selectedText {
    return fullText.substring(selection.start, selection.end);
  }
}

class _ManagementRow extends StatelessWidget {
  final VoidCallback onThreads;
  final bool open;

  const _ManagementRow({
    required this.onThreads,
    required this.open,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final L(:openThreads, :closeThreads) = L.of(context);
    return Container(
      height: 40,
      width: 42,
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            tooltip: open ? closeThreads : openThreads,
            iconSize: 24,
            splashRadius: 12,
            onPressed: onThreads,
            color: colorScheme.onSecondary,
            icon: switch (open) {
              true => const Badge(
                label: Text('X'),
                child: Icon(Icons.forum),
              ),
              false => const Icon(Icons.forum),
            },
          ),
        ],
      ),
    );
  }
}
