import 'package:csv/csv.dart';
import 'package:flutter/cupertino.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'abstract_export.dart';

/// Csv exporter for PlutoGrid
@protected
class PlutoGridDefaultCsvExport extends AbstractTextExport<String> {
  const PlutoGridDefaultCsvExport({
    this.fieldDelimiter,
    this.textDelimiter,
    this.textEndDelimiter,
    this.eol,
  }) : super();

  final String? fieldDelimiter;
  final String? textDelimiter;
  final String? textEndDelimiter;
  final String? eol;

  /// [state] PlutoGrid's PlutoGridStateManager.
  @override
  String export(PlutoGridStateManager state) {
    String toCsv = const ListToCsvConverter().convert(
      [
        getColumnTitles(state),
        ...mapStateToListOfRows(state),
      ],
      fieldDelimiter: fieldDelimiter,
      textDelimiter: textDelimiter,
      textEndDelimiter: textEndDelimiter,
      delimitAllFields: true,
      eol: eol,
    );
    return toCsv;
  }
}
