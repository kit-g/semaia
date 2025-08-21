import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:semaia_models/semaia_models.dart';

class QueryResultsView extends StatefulWidget {
  final SqlQueryResult queryResult;
  final void Function(PlutoGridStateManager)? onGridManagerReady;

  const QueryResultsView({
    super.key,
    required this.queryResult,
    this.onGridManagerReady,
  });

  @override
  State<QueryResultsView> createState() => _QueryResultsViewState();
}

class _QueryResultsViewState extends State<QueryResultsView> {
  late PlutoGridStateManager _stateManager;

  @override
  void dispose() {
    try {
      _stateManager.dispose();
    } catch (_) {
      //
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(
      :scaffoldBackgroundColor,
      primaryTextTheme: TextTheme(:labelSmall, :labelMedium),
      :colorScheme,
    ) = Theme.of(
      context,
    );

    var columns = _columns();
    var rows = _rows();
    try {
      _stateManager
        ..removeAllRows()
        ..removeColumns(_stateManager.columns)
        ..insertColumns(0, columns)
        ..appendRows(rows);
    } catch (_) {
      //
    }
    return PlutoGrid(
      columns: columns,
      rows: rows,
      onLoaded: (PlutoGridOnLoadedEvent event) {
        _stateManager = event.stateManager;
        widget.onGridManagerReady?.call(_stateManager);
      },
      configuration: PlutoGridConfiguration(
        style: PlutoGridStyleConfig(
          gridBackgroundColor: colorScheme.primaryContainer,
          rowColor: colorScheme.surface,
          cellTextStyle: labelSmall!.copyWith(color: colorScheme.tertiary),
          columnTextStyle: labelMedium!.copyWith(color: colorScheme.onPrimaryContainer),
          activatedColor: colorScheme.tertiaryContainer,
          rowHeight: 24,
          cellColorInEditState: colorScheme.inversePrimary,
          menuBackgroundColor: colorScheme.secondaryContainer,
        ),
      ),
    );
  }

  PlutoColumn _column(String column) {
    return PlutoColumn(
      title: column,
      field: column,
      type: const PlutoColumnTypeText(),
    );
  }

  List<PlutoColumn> _columns() {
    return widget.queryResult.columns.map<PlutoColumn>(_column).toList();
  }

  PlutoRow _row(SqlRow row) {
    return PlutoRow(
      cells: {
        for (var MapEntry(:key, :value) in row.values.entries) key: PlutoCell(value: value),
      },
    );
  }

  List<PlutoRow> _rows() {
    return widget.queryResult.rows.map<PlutoRow>(_row).toList();
  }
}
