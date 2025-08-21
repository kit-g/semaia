part of 'lib.dart';

const _gap = WidgetSpan(child: SizedBox(width: 4));

extension on DbSchema {
  Iterable<TreeNode<_DbTreeNode>> routineNodes() {
    if (routines == null) return [];
    return routines!.map(
      (routine) {
        return TreeNode<_DbTreeNode>(
          data: _DbTreeNode(
            name: routine.name,
            part: routine,
            // iconColor: secondary,
          ),
        );
      },
    );
  }

  Iterable<TreeNode<_DbTreeNode>> tableNodes() {
    if (tables == null) return [];
    return tables!.map(
      (table) {
        return TreeNode<_DbTreeNode>(
          data: _DbTreeNode(name: table.name, part: table),
        )..addAll(
          [
            if (table.columns.isNotEmpty)
              TreeNode(
                data: const _DbTreeNode(name: 'columns'),
              )..addAll(table.columnNodes()),
            if (table.triggers?.isNotEmpty ?? false)
              TreeNode(
                data: const _DbTreeNode(name: 'triggers'),
              )..addAll(table.triggerNodes() ?? []),
          ],
        );
      },
    );
  }

  Iterable<TreeNode<_DbTreeNode>> tableAndRoutineNodes() {
    return [
      if (tables?.isNotEmpty ?? false)
        TreeNode(
          data: const _DbTreeNode(name: 'tables'),
        )..addAll(tableNodes()),
      if (routines?.isNotEmpty ?? false)
        TreeNode<_DbTreeNode>(
          data: const _DbTreeNode(name: 'routines'),
        )..addAll(routineNodes()),
    ];
  }
}

extension on DbTable {
  Iterable<TreeNode<_DbTreeNode>> columnNodes() {
    return columns.map(
      (column) {
        return TreeNode<_DbTreeNode>(
          data: _DbTreeNode(
            name: column.name,
            part: column,
          ),
        );
      },
    );
  }

  Iterable<TreeNode<_DbTreeNode>>? triggerNodes() {
    return triggers?.map(
      (trigger) {
        return TreeNode<_DbTreeNode>(
          data: _DbTreeNode(
            name: trigger.name,
            part: trigger,
          ),
        );
      },
    );
  }
}

Color? _iconColor(BuildContext context, DbColumn? column) {
  return switch (column) {
    DbColumn(:var isPrimaryKey) when isPrimaryKey => _primaryColor(context),
    DbColumn(:var isForeignKey) when isForeignKey => _secondaryColor(context),
    _ => null,
  };
}

Color _secondaryColor(BuildContext context) {
  return switch (Theme.of(context).brightness) {
    Brightness.light => const Color(0xFF000080),
    Brightness.dark => const Color(0xFF87CEFA),
  };
}

Color? _primaryColor(BuildContext context) {
  return switch (Theme.of(context).brightness) {
    Brightness.dark => const Color(0xFFFFD700),
    Brightness.light => const Color(0xFFB8860B),
  };
}
