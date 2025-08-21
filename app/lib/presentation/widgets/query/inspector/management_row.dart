part of 'lib.dart';

class _ManagementRow extends StatelessWidget {
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final VoidCallback onRefresh;
  final VoidCallback onAddDatasource;

  const _ManagementRow({
    required this.onCollapse,
    required this.onExpand,
    required this.onRefresh,
    required this.onAddDatasource,
  });

  @override
  Widget build(BuildContext context) {
    final L(:expandAll, :collapseAll, :refresh, :addDatasource) = L.of(context);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            tooltip: addDatasource,
            iconSize: 24,
            splashRadius: 12,
            onPressed: onAddDatasource,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            tooltip: collapseAll,
            iconSize: 24,
            splashRadius: 12,
            onPressed: onCollapse,
            icon: const Icon(Icons.unfold_less),
          ),
          IconButton(
            tooltip: expandAll,
            iconSize: 24,
            splashRadius: 12,
            onPressed: onExpand,
            icon: const Icon(Icons.unfold_more),
          ),
          IconButton(
            tooltip: refresh,
            iconSize: 24,
            splashRadius: 12,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
