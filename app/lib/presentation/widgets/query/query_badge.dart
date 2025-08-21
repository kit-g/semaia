import 'package:flutter/material.dart';
import 'package:semaia_language/semaia_language.dart';
import 'package:semaia_models/semaia_models.dart';

class QueryBadge extends StatelessWidget {
  final SqlQueryResult queryResult;
  final VoidCallback onRefresh;
  final VoidCallback onShare;
  final VoidCallback onExport;

  const QueryBadge({
    super.key,
    required this.queryResult,
    required this.onRefresh,
    required this.onShare,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(
      colorScheme: ColorScheme(:secondary, :onSecondary),
      primaryTextTheme: TextTheme(:labelSmall),
    ) = Theme.of(context);
    final L(:share, :rerunQuery, :exportToCsv) = L.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: secondary,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Tooltip(
              message: queryResult.query.trim(),
              child: Text(
                queryResult.query.replaceAll(RegExp(r'\s+'), ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelSmall?.copyWith(color: onSecondary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRefresh,
            child: Tooltip(
              message: rerunQuery,
              child: Icon(
                Icons.refresh,
                size: 20,
                color: onSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onShare,
            child: Tooltip(
              message: share,
              child: Icon(
                Icons.ios_share,
                size: 20,
                color: onSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onExport,
            child: Tooltip(
              message: exportToCsv,
              child: Icon(
                Icons.download_for_offline,
                size: 20,
                color: onSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
