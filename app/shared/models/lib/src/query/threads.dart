import 'dart:collection';

import 'query.dart';

typedef ThreadId = String;

abstract interface class HasTimestamp {
  DateTime get createdAt;
}

/// A message in a chat with an LLM
/// Consists of an initial user prompt and LLM response
///
/// Starting bead in a chat will have an SQL query in it
abstract interface class Bead implements HasTimestamp {
  String get id;

  String get prompt;

  String get llmResponse;

  int get seq;

  BeadStatus get status;

  String? get sqlQuery;

  SqlQueryResult? get queryResult;

  set queryResult(SqlQueryResult? v);

  String? get errorMessage;

  double get temperature;

  String get model;

  factory Bead.fromJson(Map json) = _Bead.fromJson;

  factory Bead({
    required String id,
    required String threadId,
    String? userId,
    required String prompt,
    String llmResponse = '',
    DateTime? createdAt,
    int? seq,
    BeadStatus? status,
    String? sqlQuery,
    SqlQueryResult? queryResult,
    String? name,
    String? errorMessage,
    double? temperature,
    required String model,
  }) {
    return _Bead(
      id: id,
      prompt: prompt,
      llmResponse: llmResponse,
      createdAt: createdAt ?? DateTime.now(),
      seq: seq ?? 0,
      status: status ?? BeadStatus.success,
      sqlQuery: sqlQuery,
      queryResult: queryResult,
      errorMessage: errorMessage,
      temperature: temperature ?? .7,
      model: model,
    );
  }

  Bead copyWith({
    String? id,
    String? threadId,
    String? userId,
    String? prompt,
    String? llmResponse,
    DateTime? createdAt,
    int? seq,
    BeadStatus? status,
    String? sqlQuery,
    SqlQueryResult? queryResult,
    String? name,
    String? errorMessage,
    double? temperature,
  });

  String addChunk(String chunk);
}

class _Bead with Chunks implements Bead {
  @override
  final String id;
  @override
  final String prompt;
  @override
  final DateTime createdAt;
  @override
  final int seq;
  @override
  final BeadStatus status;
  @override
  final String? sqlQuery;
  @override
  SqlQueryResult? queryResult;
  @override
  final String? errorMessage;
  @override
  final double temperature;
  @override
  final String model;

  @override
  String _llmResponse;

  @override
  String get llmResponse => _llmResponse;

  _Bead({
    required this.id,
    required this.prompt,
    required String llmResponse,
    required this.createdAt,
    required this.seq,
    this.status = BeadStatus.success,
    this.sqlQuery,
    this.queryResult,
    this.errorMessage,
    double? temperature,
    required this.model,
  }) : temperature = temperature ?? 1.0,
       _llmResponse = llmResponse;

  factory _Bead.fromJson(Map json) {
    return switch (json) {
      {
        'id': var id,
        'message': String prompt,
        'response': String llmResponse,
        'created': String createdAt,
        'order': var seq,
        // 'temperature': num? temperature,
        'model': String model,
      } =>
        _Bead(
          id: id,
          prompt: prompt,
          llmResponse: llmResponse,
          createdAt: DateTime.parse(createdAt),
          seq: seq,
          status: BeadStatus.fromString(json['status'] ?? 'success'),
          sqlQuery: json['sqlQuery'],
          queryResult: switch (json['queryResult']) {
            Map m => SqlQueryResult.fromJson(m),
            _ => null,
          },
          errorMessage: json['errorMessage'],
          // temperature: temperature?.toDouble(),
          model: model,
        ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  Bead copyWith({
    String? id,
    String? threadId,
    String? userId,
    String? prompt,
    String? llmResponse,
    DateTime? createdAt,
    int? seq,
    BeadStatus? status,
    String? sqlQuery,
    SqlQueryResult? queryResult,
    String? name,
    String? errorMessage,
    double? temperature,
    String? model,
  }) {
    return _Bead(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      llmResponse: llmResponse ?? this.llmResponse,
      createdAt: createdAt ?? this.createdAt,
      seq: seq ?? this.seq,
      status: status ?? this.status,
      sqlQuery: sqlQuery ?? this.sqlQuery,
      queryResult: queryResult ?? this.queryResult,
      errorMessage: errorMessage ?? this.errorMessage,
      temperature: temperature ?? this.temperature,
      model: model ?? this.model,
    );
  }

  @override
  String toString() {
    return 'Bead: $id, Prompt: $prompt, Status: $status';
  }

  @override
  bool operator ==(Object other) {
    return other is Bead && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

abstract mixin class Chunks {
  abstract String _llmResponse;

  String addChunk(String chunk) {
    StringBuffer buffer = StringBuffer();
    buffer
      ..write(_llmResponse)
      ..write(chunk);
    _llmResponse = buffer.toString();
    return _llmResponse;
  }
}

enum BeadStatus {
  success('success'),
  error('error');

  const BeadStatus(String value);

  factory BeadStatus.fromString(String v) {
    return switch (v) {
      'success' => success,
      'error' => error,
      _ => throw ArgumentError(v),
    };
  }
}

/// A single LLM chat
abstract interface class Chat with Iterable<Bead> implements HasTimestamp, Comparable<HasTimestamp> {
  String get id;

  String? get name;

  @override
  DateTime get createdAt;

  void string(Bead bead);

  String? get initialQuery;

  factory Chat.fromJson(Map json) = _Chat.fromJson;

  factory Chat.start(Bead bead) => _Chat(beads: [bead], id: emptyThreadId);

  factory Chat.empty({String? id}) => _Chat(beads: [], id: id ?? emptyThreadId);

  Chat copyWith({String? name});
}

class _Chat with Iterable<Bead> implements Chat {
  final List<Bead> _beads;
  final ThreadId _id;
  final DateTime? _createdAt;
  final String? _name;
  final String? prompt;

  const _Chat({
    required List<Bead> beads,
    required ThreadId id,
    DateTime? createdAt,
    String? name,
    this.prompt,
  }) : _beads = beads,
       _id = id,
       _createdAt = createdAt,
       _name = name;

  @override
  String get id => _id;

  @override
  String? get name => _name ?? initialQuery;

  @override
  DateTime get createdAt => _createdAt ?? _beads.first.createdAt;

  @override
  String? get initialQuery => _beads.firstOrNull?.sqlQuery;

  factory _Chat.fromJson(Map json) {
    SqlQueryResult? r;
    try {
      r = SqlQueryResult.fromJson(json['query_results']);
    } catch (e) {
      r = null;
    }
    return switch (json) {
      {'id': String id, 'messages': List? l} => _Chat(
        beads: [...?l?.map((each) => Bead.fromJson(each))],
        id: id,
        prompt: json['prompt'],
      )..firstOrNull?.queryResult = r,
      {'id': String id, 'created': String created} => _Chat(
        beads: [],
        id: id,
        createdAt: DateTime.parse(created),
        name: json['name'] ?? json['llmResponse'] ?? json['prompt'],
      ),
      _ => throw ArgumentError(json),
    };
  }

  @override
  Iterator<Bead> get iterator => _beads.iterator;

  @override
  void string(Bead bead) => _beads.add(bead);

  @override
  int compareTo(HasTimestamp other) {
    return other.createdAt.compareTo(createdAt);
  }

  @override
  bool get isEmpty => every((bead) => bead is EmptyBead);

  @override
  Chat copyWith({String? name}) {
    return _Chat(
      beads: _beads,
      name: name ?? this.name,
      createdAt: createdAt,
      id: id,
    );
  }

  @override
  String toString() {
    return switch (name) {
      String n => 'Thread $n with $length beads',
      _ => 'Thread with $length beads',
    };
  }
}

const emptyThreadId = 'empty';

class EmptyBead with Chunks implements Bead {
  @override
  String _llmResponse;

  @override
  String get llmResponse => _llmResponse;

  @override
  Bead copyWith({
    String? id,
    String? threadId,
    String? userId,
    String? prompt,
    String? llmResponse,
    DateTime? createdAt,
    int? seq,
    BeadStatus? status,
    String? sqlQuery,
    SqlQueryResult? queryResult,
    String? name,
    String? errorMessage,
    double? temperature,
  }) {
    throw UnimplementedError();
  }

  @override
  DateTime get createdAt => _createdAt;

  @override
  String? get errorMessage => throw UnimplementedError();

  @override
  String get id => throw UnimplementedError();

  @override
  String get prompt => throw UnimplementedError();

  @override
  SqlQueryResult? get queryResult => null;

  @override
  int get seq => 0;

  @override
  final String sqlQuery;

  @override
  BeadStatus get status => throw UnimplementedError();

  @override
  double get temperature => throw UnimplementedError();

  final DateTime _createdAt;

  EmptyBead({required this.sqlQuery}) : _createdAt = DateTime.now(), _llmResponse = '';

  @override
  String get model => 'None';

  @override
  set queryResult(SqlQueryResult? v) {}
}
