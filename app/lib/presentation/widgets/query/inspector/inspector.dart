part of 'lib.dart';

class Inspector extends StatefulWidget {
  const Inspector({
    super.key,
    required this.onDoubleTapConnector,
    required this.onDoubleTapTable,
    required this.onDoubleTapRoutine,
    required this.onDoubleTapTrigger,
  });

  final void Function(Connector) onDoubleTapConnector;
  final void Function(Connector, DbTable) onDoubleTapTable;
  final void Function(Connector, DbSchema, DbRoutine) onDoubleTapRoutine;
  final void Function(Connector, DbSchema, DbTable, DbTrigger) onDoubleTapTrigger;

  @override
  State<Inspector> createState() => _InspectorState();
}

class _InspectorState extends State<Inspector> with LoadingState {
  TreeViewController? _controller;

  @override
  Widget build(BuildContext context) {
    final root = TreeNode<_DbTreeNode>.root();
    return Container(
      margin: const EdgeInsets.only(left: 4),
      color: Theme.of(context).scaffoldBackgroundColor,
      width: 200,
      child: Column(
        children: [
          _ManagementRow(
            onCollapse: () {
              for (var child in root.children.values) {
                if (child case ITreeNode node) {
                  _controller?.collapseNode(node);
                }
              }
            },
            onExpand: () => _controller?.expandAllChildren(root),
            onRefresh: () {
              DatabaseInspector.of(context).init();
            },
            onAddDatasource: () => _onAddDataSource(context),
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: loader,
              builder: (_, loading, _) {
                final structure = DatabaseInspector.watch(context);
                final DatabaseInspector(:isInitialized, :isEmpty) = structure;

                if (!isInitialized || loading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (isEmpty) {
                  return const Center(
                    child: Text('No database connections'),
                  );
                }

                return TreeView.simpleTyped<_DbTreeNode, TreeNode<_DbTreeNode>>(
                  showRootNode: false,
                  expansionIndicatorBuilder: (_, node) {
                    return ChevronIndicator.rightDown(
                      tree: node,
                      alignment: Alignment.centerLeft,
                    );
                  },
                  indentation: const Indentation(width: 12),
                  builder: (_, node) {
                    return _Item(
                      node: node,
                      onDoubleTapTable: widget.onDoubleTapTable,
                      onDoubleTapRoutine: widget.onDoubleTapRoutine,
                      onDoubleTapTrigger: widget.onDoubleTapTrigger,
                      onDoubleTapConnector: widget.onDoubleTapConnector,
                      onExplainDatabase: (connector) {
                        _explainDatabase(context, connector);
                      },
                      onEditConnector: (connector) {
                        _onAddDataSource(context, editable: connector);
                      },
                      onDeleteConnector: (connector) {
                        structure.delete(connector);
                      },
                      onRefreshConnector: (connector) async {
                        startLoading();
                        try {
                          await structure.inspect(connector);
                        } finally {
                          stopLoading();
                        }
                      },
                      onCollapse: () {
                        _controller?.collapseNode(node);
                      },
                      onExpand: () {
                        _controller?.expandAllChildren(node);
                      },
                    );
                  },
                  onTreeReady: (controller) {
                    _controller = controller;
                    _controller?.expandAllChildren(root);
                  },
                  tree: root
                    ..addAll(
                      structure.map<TreeNode<_DbTreeNode>>(
                        (connector) {
                          final databaseNodes =
                              structure[connector]?.databases.where((db) => !db.isEmpty).map(
                                (db) {
                                  final schemaNodes = db.schemata.map(
                                    (schema) {
                                      return TreeNode<_DbTreeNode>(
                                        data: _DbTreeNode(
                                          name: schema.name,
                                          part: schema,
                                        ),
                                      )..addAll(schema.tableAndRoutineNodes());
                                    },
                                  );

                                  return TreeNode<_DbTreeNode>(
                                    data: _DbTreeNode(
                                      name: db.name,
                                      part: db,
                                    ),
                                  )..addAll(schemaNodes);
                                },
                              ) ??
                              [];

                          return TreeNode<_DbTreeNode>(
                            data: _DbTreeNode(
                              name: connector.name,
                              part: connector,
                            ),
                          )..addAll(databaseNodes);
                        },
                      ).toList(),
                    ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddDataSource(BuildContext context, {Connector? editable}) async {
    return showDialog(
      context: context,
      builder: (context) {
        String? validator(String? value) {
          return (value?.isEmpty ?? true) ? L.of(context).cannotBeEmpty : null;
        }

        final formKey = GlobalKey<FormState>();
        String name = editable?.name ?? '';
        String host = editable?.host ?? '';
        int port = editable?.port ?? 5432;
        String user = editable?.user ?? '';
        String password = editable?.password ?? '';
        String dbName = editable?.database ?? '';

        return AlertDialog(
          title: Text(L.of(context).addDatasource),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                spacing: 8,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    initialValue: name,
                    decoration: InputDecoration(labelText: L.of(context).connectorName),
                    onSaved: (value) => name = value ?? '',
                    validator: validator,
                  ),
                  TextFormField(
                    initialValue: host,
                    decoration: InputDecoration(labelText: L.of(context).host),
                    onSaved: (value) => host = value ?? '',
                    validator: validator,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: L.of(context).port),
                    keyboardType: TextInputType.number,
                    initialValue: port.toString(),
                    onSaved: (value) => port = int.tryParse(value ?? '') ?? 5432,
                    validator: (value) {
                      return switch (value) {
                        String s when int.tryParse(s) != null => null,
                        _ => L.of(context).invalidNumber,
                      };
                    },
                  ),
                  TextFormField(
                    initialValue: user,
                    decoration: InputDecoration(labelText: L.of(context).user),
                    onSaved: (value) => user = value ?? '',
                    validator: validator,
                  ),
                  TextFormField(
                    initialValue: password,
                    decoration: InputDecoration(labelText: L.of(context).password),
                    obscureText: true,
                    onSaved: (v) => password = v ?? '',
                    validator: validator, // password can be optional for some configurations
                  ),
                  TextFormField(
                    initialValue: dbName,
                    decoration: InputDecoration(labelText: L.of(context).database),
                    onSaved: (value) => dbName = value ?? '',
                    validator: validator,
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(L.of(context).cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(L.of(context).testConnection),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(L.of(context).add),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  final connector = switch (editable) {
                    Connector existing => existing.copyWith(
                      name: name,
                      host: host,
                      port: port,
                      user: user,
                      password: password,
                      database: dbName,
                    ),
                    null => Connector(
                      name: name,
                      host: host,
                      port: port,
                      user: user,
                      password: password,
                      database: dbName,
                    ),
                  };
                  Navigator.of(context).pop();

                  switch (editable) {
                    case Connector():
                      DatabaseInspector.of(context).edit(connector);
                    case null:
                      DatabaseInspector.of(context).add(connector);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _explainDatabase(BuildContext context, Connector connector) {
    return showDialog(
      context: context,
      barrierDismissible: false, // yes, correct
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final screenHeight = size.height;
        final screenWidth = size.width / 2;

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(L.of(context).explainDatabase),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 16.0, 8.0),
          content: SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: StreamingMarkdownView(
              stream: Api.instance.explainDatabase(connector.id!),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          actions: [
            TextButton(
              child: Text(L.of(context).close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  final TreeNode<_DbTreeNode> node;
  final void Function(Connector) onDoubleTapConnector;
  final void Function(Connector, DbTable) onDoubleTapTable;
  final void Function(Connector, DbSchema, DbRoutine) onDoubleTapRoutine;
  final void Function(Connector, DbSchema, DbTable, DbTrigger) onDoubleTapTrigger;
  final void Function(Connector) onEditConnector;
  final void Function(Connector) onDeleteConnector;
  final void Function(Connector) onRefreshConnector;
  final void Function(Connector) onExplainDatabase;
  final void Function()? onCollapse;
  final void Function()? onExpand;

  const _Item({
    required this.node,
    required this.onDoubleTapConnector,
    required this.onDoubleTapTable,
    required this.onDoubleTapTrigger,
    required this.onDoubleTapRoutine,
    required this.onEditConnector,
    required this.onDeleteConnector,
    required this.onRefreshConnector,
    required this.onExplainDatabase,
    this.onCollapse,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(
      textTheme: TextTheme(labelSmall: underscript, bodySmall: main),
    ) = Theme.of(
      context,
    );
    final L(:columns, :triggers, :tables, :routines) = L.of(context);

    Widget def() => Text(node.data!.name, style: main);

    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: SizedBox(
        height: _height(),
        child: ValueListenableBuilder<bool>(
          valueListenable: node.expansionNotifier,
          builder: (context, expanded, _) {
            return switch (node.data!.part) {
              Connector c => _connector(c, main: main),
              DbTable t => _table(t, main: main),
              DbColumn c => _column(c, main: main, secondary: underscript),
              DbTrigger t => _trigger(t, main: main, secondary: underscript),
              DbRoutine r => _routine(r, main: main, secondary: underscript),
              DbDatabase d => _database(d, main: main),
              null => switch (node.data!.name) {
                'columns' => _folder(context, columns, style: main, expanded: expanded),
                'triggers' => _folder(context, triggers, style: main, expanded: expanded),
                'tables' => _folder(context, tables, style: main, expanded: expanded),
                'routines' => _folder(context, routines, style: main, expanded: expanded),
                _ => def(),
              },
              _ => def(),
            };
          },
        ),
      ),
    );
  }

  double _height() {
    return switch (node.data?.part) {
      Connector() => 40,
      DbDatabase() => 28,
      _ => 20,
    };
  }

  Widget _database(DbDatabase db, {TextStyle? main}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          node.data!.name,
          style: main,
        ),
        if (db.schemata.isNotEmpty)
          Row(
            children: [
              _IconButton(
                onPressed: onCollapse,
                icon: Icons.unfold_less_rounded,
              ),
              _IconButton(
                onPressed: onExpand,
                icon: Icons.unfold_more_rounded,
              ),
            ],
          ),
      ],
    );
  }

  Widget _folder(BuildContext context, String label, {TextStyle? style, required bool expanded}) {
    return Row(
      children: [
        AnimatedCrossFade(
          firstChild: Icon(
            Icons.folder_open,
            size: 16,
            color: _secondaryColor(context),
          ),
          secondChild: Icon(
            Icons.folder,
            size: 16,
            color: _secondaryColor(context),
          ),
          crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 100),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }

  Widget _table(DbTable table, {TextStyle? main}) {
    return Tooltip(
      message: table.comment ?? '',
      child: Row(
        children: [
          const Icon(
            Icons.table_chart_outlined,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            node.data!.name,
            style: main,
          ),
        ],
      ),
    );
  }

  Widget _connector(Connector connector, {TextStyle? main}) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Builder(
        builder: (context) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  switch (Theme.of(context).brightness) {
                    Brightness.dark => const Vector(
                      Assets.postgres,
                      height: 14,
                      width: 14,
                    ),
                    Brightness.light => const Vector.ownColor(Assets.postgres, height: 14, width: 14),
                  },
                  const SizedBox(width: 4),
                  Text(
                    connector.name,
                    style: main,
                  ),
                ],
              ),
              Row(
                children: [
                  _IconButton(
                    onPressed: () => onExplainDatabase(connector),
                    icon: Icons.auto_awesome,
                    tooltip: L.of(context).explainDatabase,
                  ),
                  _IconButton(
                    onPressed: () => onRefreshConnector(connector),
                    icon: Icons.refresh,
                  ),
                  _IconButton(
                    onPressed: () => onEditConnector(connector),
                    icon: Icons.edit,
                  ),
                  _IconButton(
                    onPressed: () => onDeleteConnector(connector),
                    icon: Icons.delete_outline_rounded,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _column(DbColumn column, {TextStyle? main, TextStyle? secondary}) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Builder(
        builder: (context) {
          final L(:primaryKey, :foreignKey, :nonNullable) = L.of(context);
          final DbColumn(:isNullable, :isForeignKey, :isPrimaryKey, :name, :dataType) = column;

          String? tooltip;

          if (isPrimaryKey) {
            tooltip = primaryKey;
          } else if (isForeignKey) {
            tooltip = foreignKey;
          } else if (!isNullable) {
            tooltip = nonNullable;
          } else {
            tooltip = '';
          }

          return Row(
            children: [
              Tooltip(
                message: tooltip,
                child: Icon(
                  isNullable ? Icons.view_column_rounded : Icons.view_column_outlined,
                  color: _iconColor(context, column),
                  size: 16,
                ),
              ),
              const SizedBox(width: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: name,
                      style: main,
                    ),
                    _gap,
                    TextSpan(
                      text: dataType,
                      style: secondary,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _routine(DbRoutine routine, {TextStyle? main, TextStyle? secondary}) {
    var DbRoutine(:name, :args, :returnType) = routine;
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Tooltip(
        message: routine.comment ?? '',
        child: Row(
          children: [
            const Icon(
              Icons.functions,
              size: 16,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: name, style: main),
                      _gap,
                      TextSpan(text: '(${(args ?? []).join(', ')})', style: secondary),
                      _gap,
                      TextSpan(
                        text: ': $returnType',
                        style: secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trigger(DbTrigger trigger, {TextStyle? main, TextStyle? secondary}) {
    var DbTrigger(:name, :runsWhen, :runtimeType, :executesProcedure) = trigger;
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Tooltip(
        message: trigger.comment ?? '',
        child: Row(
          children: [
            const Icon(
              Icons.functions,
              size: 16,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: name, style: main),
                      _gap,
                      TextSpan(text: runsWhen, style: secondary),
                      _gap,
                      TextSpan(text: '→', style: secondary),
                      _gap,
                      TextSpan(
                        text: switch (executesProcedure.contains('EXECUTE FUNCTION ')) {
                          true => executesProcedure.substring('EXECUTE FUNCTION '.length),
                          false => executesProcedure,
                        },
                        style: secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDoubleTap() {
    switch (node) {
      // tapping on a column allows us
      // to get the table info from the grandparent
      case TreeNode(
        data: _DbTreeNode(part: DbColumn()),
        parent: TreeNode(
          // table
          parent: TreeNode(
            data: _DbTreeNode(part: DbTable table),
            // tables folder
            parent: TreeNode(
              // schema
              parent: TreeNode(
                data: _DbTreeNode(part: DbSchema _),
                parent: TreeNode(
                  data: _DbTreeNode(part: DbDatabase _),
                  // connector
                  parent: TreeNode(
                    data: _DbTreeNode(part: Connector connector),
                  ),
                ),
              ),
            ),
          ),
        ),
      ):
        onDoubleTapTable(connector, table);
      // same with routines
      case TreeNode(
        data: _DbTreeNode(part: DbRoutine routine),
        // routines folder
        parent: TreeNode(
          // schema
          parent: TreeNode(
            data: _DbTreeNode(part: DbSchema schema),
            // database
            parent: TreeNode(
              data: _DbTreeNode(part: DbDatabase _),
              // connector
              parent: TreeNode(
                data: _DbTreeNode(part: Connector connector),
              ),
            ),
          ),
        ),
      ):
        onDoubleTapRoutine(connector, schema, routine);
      // with triggers we need to go two levels deeper:
      // trigger <- triggers <- table <- tables <- schema <- database <- connector
      case TreeNode(
        data: _DbTreeNode(part: DbTrigger trigger),
        // triggers folder
        parent: TreeNode(
          // table
          parent: TreeNode(
            data: _DbTreeNode(part: DbTable table),
            // tables folder
            parent: TreeNode(
              // schema
              parent: TreeNode(
                data: _DbTreeNode(part: DbSchema schema),
                // database
                parent: TreeNode(
                  data: _DbTreeNode(part: DbDatabase _),
                  // connector
                  parent: TreeNode(
                    data: _DbTreeNode(part: Connector connector),
                  ),
                ),
              ),
            ),
          ),
        ),
      ):
        onDoubleTapTrigger(connector, schema, table, trigger);
      case TreeNode(
        data: _DbTreeNode(part: Connector connector),
      ):
        onDoubleTapConnector(connector);
    }
  }
}
