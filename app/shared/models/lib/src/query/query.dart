abstract interface class SqlRow {
  Map<String, dynamic> get values;

  factory SqlRow.fromJson(Map<String, dynamic> json, List<String> columns) = _Row.fromJson;

  Map<String, dynamic> toJson();

  dynamic operator [](String columnName);
}

abstract interface class SqlQueryResult {
  String get query;

  List<String> get columns;

  List<SqlRow> get rows;

  factory SqlQueryResult.fromJson(Map json) = _SqlQueryResult.fromJson;

  Map<String, dynamic> toJson();
}

class _Row implements SqlRow {
  @override
  final Map<String, dynamic> values;

  const _Row({required this.values});

  factory _Row.fromJson(Map json, List<String> columns) {
    final values = {for (var column in columns) column: json[column]};
    return _Row(values: values);
  }

  @override
  Map<String, dynamic> toJson() => values;

  @override
  dynamic operator [](String columnName) {
    return values[columnName];
  }

  @override
  String toString() {
    return values.toString();
  }
}

class _SqlQueryResult implements SqlQueryResult {
  @override
  final String query;
  @override
  final List<String> columns;
  @override
  final List<SqlRow> rows;

  const _SqlQueryResult({
    required this.columns,
    required this.rows,
    required this.query,
  });

  factory _SqlQueryResult.fromJson(Map json) {
    return switch (json) {
      {
        'columns': List columns,
        'rows': List rows,
        'query': String query,
      } =>
        _SqlQueryResult(
          query: query,
          columns: List<String>.from(columns),
          rows: rows.map((rowJson) => _Row.fromJson(rowJson, List<String>.from(columns))).toList(),
        ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'columns': columns,
      'rows': rows.map((row) => row.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return '$query\n$rows';
  }
}

class QueryError implements Exception {}

class ExcessiveQuery extends QueryError {}
