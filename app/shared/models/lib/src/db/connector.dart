import 'dart:convert';

import '../query/inspect.dart';

abstract interface class Connector implements Comparable<Connector>, DbPart {
  String? get id;

  String get host;

  String get database;

  int get port;

  String get user;

  String get password;

  DbStructure? get structure;

  Map<String, dynamic> toMap();

  factory Connector({
    required String host,
    required String database,
    required int port,
    required String user,
    required String password,
    DbStructure? structure,
    String? name,
  }) {
    return _Connector(
      host: host,
      database: database,
      port: port,
      user: user,
      password: password,
      name: name,
    );
  }

  factory Connector.fromJson(Map json) {
    return _Connector(
      id: json['id'],
      host: json['host'],
      database: json['database'],
      port: switch (json['port']) {
        int port => port,
        String s => int.parse(s),
        _ => 5432,
      },
      user: json['user'],
      password: json['password'],
      name: json['name'],
      structure: switch (json['inspection']) {
        String s => DbStructure.fromJson(jsonDecode(s)),
        _ => null,
      },
    );
  }

  Connector copyWith({
    String? host,
    String? database,
    int? port,
    String? user,
    String? password,
    String? name,
  });
}

class _Connector implements Connector {
  @override
  final String? id;
  @override
  final String host;
  @override
  final String database;
  @override
  final int port;
  @override
  final String user;
  @override
  final String password;
  @override
  final DbStructure? structure;

  final String? _name;

  const _Connector({
    this.id,
    required this.host,
    required this.database,
    required this.port,
    required this.user,
    required this.password,
    this.structure,
    String? name,
  }) : _name = name;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': ?id,
      'host': host,
      'database': database,
      'port': port,
      'user': user,
      'password': password,
      'name': ?_name,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return switch ((id, other)) {
      (String id, Connector(id: String otherId)) => id == otherId,
      _ => false,
    };
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Connector(id: $id, host: $host, database: $database, port: $port, user: $user)';
  }

  @override
  String? get definition => null;

  @override
  String get name => _name ?? host;

  @override
  int compareTo(Connector other) {
    return switch ((id, other.id)) {
      (String id, String otherId) => otherId.compareTo(id),
      _ => 0,
    };
  }

  @override
  Connector copyWith({
    String? host,
    String? database,
    int? port,
    String? user,
    String? password,
    String? name,
  }) {
    return _Connector(
      id: id,
      host: host ?? this.host,
      database: database ?? this.database,
      port: port ?? this.port,
      user: user ?? this.user,
      password: password ?? this.password,
      name: name ?? _name,
    );
  }
}
