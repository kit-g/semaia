abstract interface class DbPart {
  String get name;

  String? get definition;
}

abstract interface class DbStructure {
  List<DbDatabase> get databases;

  factory DbStructure.fromJson(Map json) = _DatabaseStructure.fromJson;

  factory DbStructure.empty() => const _DatabaseStructure(databases: []);

  void clear();
}

abstract interface class DbDatabase implements DbPart {
  List<DbSchema> get schemata;

  factory DbDatabase.fromJson(Map json) = _Database.fromJson;
}

abstract interface class DbSchema implements DbPart, Comparable<DbSchema> {
  List<DbTable>? get tables;

  List<DbRoutine>? get routines;

  String? get comment;

  factory DbSchema.fromJson(Map json) = _Schema.fromJson;
}

abstract interface class DbTable implements DbPart {
  String get schema;

  List<DbColumn> get columns;

  List<DbTrigger>? get triggers;

  String? get comment;

  factory DbTable.fromJson(Map json) = _Table.fromJson;
}

abstract interface class DbColumn implements DbPart {
  String get dataType;

  bool get isPrimaryKey;

  bool get isForeignKey;

  bool get isNullable;

  factory DbColumn.fromJson(Map json) = _Column.fromJson;
}

abstract interface class DbTrigger implements DbPart {
  String get runsWhen;

  String get executesProcedure;

  @override
  String? get definition;

  String? get comment;

  factory DbTrigger.fromJson(Map json) = _Trigger.fromJson;
}

abstract interface class DbRoutine implements DbPart {
  List<String>? get args;

  String get returnType;

  String? get comment;

  factory DbRoutine.fromJson(Map json) = _Routine.fromJson;
}

class _DatabaseStructure implements DbStructure {
  @override
  final List<DbDatabase> databases;

  const _DatabaseStructure({required this.databases});

  factory _DatabaseStructure.fromJson(Map json) {
    return switch (json) {
      {'databases': List databases} => _DatabaseStructure(
        databases: databases.map((e) => DbDatabase.fromJson(e as Map)).toList(),
      ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  void clear() {
    databases.clear();
  }
}

class _Database implements DbDatabase {
  @override
  final String name;
  @override
  final List<DbSchema> schemata;

  const _Database({
    required this.name,
    required this.schemata,
  });

  factory _Database.fromJson(Map json) {
    return switch (json) {
      {
        'databaseName': String name,
        'schemata': List? schemata,
      } =>
        _Database(
          name: name,
          schemata: schemata?.map((e) => DbSchema.fromJson(e as Map)).toList() ?? [],
        ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DbDatabase && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String? get definition => null;
}

class _Schema implements DbSchema {
  @override
  final String name;
  @override
  final List<DbTable>? tables;
  @override
  final List<DbRoutine>? routines;
  @override
  final String? comment;

  const _Schema({
    required this.name,
    required this.tables,
    required this.routines,
    required this.comment,
  });

  factory _Schema.fromJson(Map json) {
    return switch (json) {
      {
        'schemaName': String name,
        'tables': List? tables,
        'routines': List? routines,
      } =>
        _Schema(
          name: name,
          tables: tables?.map((e) => DbTable.fromJson(e as Map)).toList(),
          routines: routines?.map((e) => DbRoutine.fromJson(e as Map)).toList(),
          comment: json['comment'],
        ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  int compareTo(DbSchema other) {
    return name.compareTo(other.name);
  }

  @override
  bool operator ==(Object other) {
    return other is DbSchema && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String? get definition => null;
}

class _Table implements DbTable {
  @override
  final String name;
  @override
  final String schema;
  @override
  final List<DbColumn> columns;
  @override
  final List<DbTrigger>? triggers;
  @override
  final String? comment;

  const _Table({
    required this.name,
    required this.columns,
    required this.triggers,
    required this.schema,
    required this.comment,
  });

  factory _Table.fromJson(Map json) {
    return switch (json) {
      {
        'tableName': String name,
        'columns': List columns,
        'triggers': List? triggers,
        'schema': String schema,
      } =>
        _Table(
          name: name,
          columns: columns.map((e) => DbColumn.fromJson(e as Map)).toList(),
          triggers: triggers?.map((e) => DbTrigger.fromJson(e as Map)).toList(),
          schema: schema,
          comment: json['comment'],
        ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DbTable && other.name == name && other.schema == schema;
  }

  @override
  int get hashCode => Object.hash(name, schema);

  @override
  String? get definition => null;
}

class _Column implements DbColumn {
  @override
  final String name;
  @override
  final String dataType;
  @override
  final bool isPrimaryKey;
  @override
  final bool isForeignKey;
  @override
  final bool isNullable;

  const _Column({
    required this.name,
    required this.dataType,
    required this.isPrimaryKey,
    required this.isForeignKey,
    required this.isNullable,
  });

  factory _Column.fromJson(Map json) {
    return switch (json) {
      {
        'columnName': String name,
        'dataType': String dataType,
        'isPrimaryKey': bool? isPrimaryKey,
        'isForeignKey': bool? isForeignKey,
        'isNullable': bool? isNullable,
      } =>
        _Column(
          name: name,
          dataType: dataType,
          isPrimaryKey: isPrimaryKey ?? false,
          isForeignKey: isForeignKey ?? false,
          isNullable: isNullable ?? false,
        ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DbColumn && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String? get definition => null;
}

class _Trigger implements DbTrigger {
  @override
  final String name;
  @override
  final String runsWhen;
  @override
  final String executesProcedure;
  @override
  final String? definition;
  @override
  final String? comment;

  const _Trigger({
    required this.name,
    required this.runsWhen,
    required this.executesProcedure,
    this.definition,
    required this.comment,
  });

  factory _Trigger.fromJson(Map json) {
    return switch (json) {
      {
        'triggerName': String name,
        'runsWhen': String runsWhen,
        'executesProcedure': String executesProcedure,
      } =>
        _Trigger(
          name: name,
          runsWhen: runsWhen,
          executesProcedure: executesProcedure,
          definition: json['definition'],
          comment: json['comment'],
        ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DbTrigger &&
        other.name == name &&
        other.executesProcedure == executesProcedure &&
        other.runsWhen == runsWhen;
  }

  @override
  int get hashCode => Object.hash(name, executesProcedure, runsWhen);
}

class _Routine implements DbRoutine {
  @override
  final String name;
  @override
  final List<String>? args;
  @override
  final String returnType;
  @override
  final String? definition;
  @override
  final String? comment;

  const _Routine({
    required this.name,
    required this.args,
    required this.returnType,
    this.definition,
    required this.comment,
  });

  factory _Routine.fromJson(Map json) {
    return switch (json) {
      {
        'routineName': String routineName,
        'args': List? args,
        'returnType': String returnType,
      } =>
        _Routine(
          name: routineName,
          args: args?.map((each) => each.toString()).toList(),
          returnType: returnType,
          definition: json['definition'],
          comment: json['comment'],
        ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DbRoutine && other.name == name && other.returnType == returnType;
  }

  @override
  int get hashCode => Object.hash(name, returnType);
}
