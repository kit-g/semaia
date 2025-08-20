import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'csv.dart';

String exportCsv(
  PlutoGridStateManager state, {
  String? fieldDelimiter,
  String? textDelimiter,
  String? textEndDelimiter,
  String? eol,
}) {
  var plutoGridCsvExport = PlutoGridDefaultCsvExport(
    fieldDelimiter: fieldDelimiter,
    textDelimiter: textDelimiter,
    textEndDelimiter: textEndDelimiter,
    eol: eol,
  );

  return plutoGridCsvExport.export(state);
}

void exportToCsvFile(PlutoGridStateManager tableManager) {
  String pad(int i) => '$i'.padLeft(2, '0');
  final lines = exportCsv(tableManager);
  final bytes = const Utf8Encoder().convert(lines);
  final DateTime(:year, :month, :day, :hour, :minute) = DateTime.now();
  final name = '$year-${pad(month)}-${pad(day)}-${pad(hour)}-${pad(minute)}';
  FileSaver.instance.saveFile(
    name: name,
    fileExtension: 'csv',
    mimeType: MimeType.csv,
    bytes: bytes,
  );
}
