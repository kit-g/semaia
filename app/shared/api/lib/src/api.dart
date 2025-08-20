import 'dart:async';
import 'dart:convert';

import 'package:dart_http_sse/client/sse_client.dart';
import 'package:dart_http_sse/enum/request_method_type_enum.dart';
import 'package:dart_http_sse/model/sse_request.dart';
import 'package:dart_http_sse/model/sse_response.dart';
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart';
import 'package:semaia_models/semaia_models.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

abstract final class _Config {
  static const connectors = '/api/connectors';
  static const chats = '/api/chats';
  static const threads = '/api/threads';

  static String connector(String connectorId) {
    return '${_Config.connectors}/$connectorId';
  }

  static String inspect(String connectorId) {
    return '${_Config.connector(connectorId)}/inspect';
  }

  static String chat(String chatId) {
    return '${_Config.chats}/$chatId';
  }

  static String messages(String chatId) {
    return '${_Config.chat(chatId)}/messages';
  }
}

final _logger = Logger('Api');

final class Api
    with Requests
    implements
        ChatService,
        ConnectorService, //
        HeaderAuthenticatedService,
        QueryService {
  Api._();

  static final Api instance = Api._();

  @override
  Map<String, String>? defaultHeaders;

  @override
  late String gateway;

  @override
  http.Client? get client => null;

  factory Api({required String gateway}) {
    instance.gateway = gateway;
    return instance;
  }

  /// This is how CloudFront expects requests
  /// if the backend is authorized with an OAC
  Map<String, String> _override(Map<String, String>? headers, Json? body) {
    final hash = sha256.convert(utf8.encode(jsonEncode(body))).toString();
    return {'x-amz-content-sha256': hash, ...?headers};
  }

  @override
  Future<Response> post(String endpoint, {Map<String, String>? headers, Json? body, Map<String, dynamic>? query}) {
    if (body != null) {
      return super.post(endpoint, headers: _override(headers, body), body: body, query: query);
    }
    return super.post(endpoint, headers: headers, body: body, query: query);
  }

  @override
  Future<Response> put(String endpoint, {Map<String, String>? headers, Json? body}) {
    if (body != null) {
      return super.put(endpoint, headers: _override(headers, body), body: body);
    }
    return super.put(endpoint, headers: headers, body: body);
  }

  @override
  void authenticate(Map<String, String> headers) {
    instance.defaultHeaders = headers;
  }

  @override
  Future<SqlQueryResult> sendQuery(String connectorId, String query) async {
    final (json, status) = await post('${_Config.connector(connectorId)}/query', body: {'query': query});
    return switch (status) {
      < 300 => SqlQueryResult.fromJson(json),
      502 => throw ExcessiveQuery(),
      _ => throw ArgumentError(json),
    };
  }

  @override
  Future<DbStructure> inspect(String connectorId) async {
    final (json, _) = await get(_Config.inspect(connectorId));
    return DbStructure.fromJson(json);
  }

  @override
  Future<DbRoutine> getRoutineDefinition(String connectorId, String schema, String routine) async {
    final (json, _) = await get(
      _Config.inspect(connectorId),
      query: {'type': 'routine', 'schema': schema, 'routine': routine},
    );
    return DbRoutine.fromJson(json);
  }

  @override
  Future<DbTrigger> getTriggerDefinition(String connectorId, String schema, String table, String trigger) async {
    final (json, _) = await get(
      _Config.inspect(connectorId),
      query: {'type': 'trigger', 'schema': schema, 'table': table, 'trigger': trigger},
    );
    return DbTrigger.fromJson(json);
  }

  @override
  Future<bool> renameThread(String threadId, String name) async {
    final (json, _) = await put('${_Config.threads}/$threadId', body: {'name': name});
    return json['success'] == true;
  }

  @override
  Future<Connector> createConnector(Connector connector) async {
    final (json, _) = await post(_Config.connectors, body: connector.toMap());
    return switch (json) {
      {'connector': Map m} => Connector.fromJson(m),
      _ => throw ArgumentError(json),
    };
  }

  @override
  Future<void> deleteConnector(String id) {
    return delete('${_Config.connectors}/$id');
  }

  @override
  Future<Connector> getConnector(String id) async {
    final (json, _) = await get('${_Config.connectors}/$id');
    return switch (json) {
      {'connector': Map m} => Connector.fromJson(m),
      _ => throw ArgumentError(json),
    };
  }

  @override
  Future<Iterable<Connector>?> listConnectors() async {
    final (json, _) = await get(_Config.connectors);
    return switch (json) {
      {'connectors': List? l} => l?.map((each) => Connector.fromJson(each)),
      _ => null,
    };
  }

  @override
  Future<Connector> updateConnector(Connector connector) async {
    final (json, _) = await put(_Config.connector(connector.id!), body: connector.toMap());
    return switch (json) {
      {'connector': Map m} => Connector.fromJson(m),
      _ => throw ArgumentError(json),
    };
  }

  @override
  Stream<String?> explainDatabase(String connectorId) {
    final body = <String, dynamic>{};
    final headers = _override(streamHeaders(), body);
    return _sendStreamRequest(
      Uri.https(gateway, '${_Config.connector(connectorId)}/explain'),
      body: body,
      headers: headers,
      converter: (event) {
        _logger.info('event: ${event.event} ${event.data}');
        return switch (event) {
          SSEResponse(event: 'token', data: {'t': String token}) => token,
          SSEResponse(event: 'done') => null,
          _ => throw ArgumentError(event),
        };
      },
    );
  }

  Map<String, String> streamHeaders() {
    return {
      ..._streamHeaders,
      'Authorization': ?defaultHeaders?['Authorization'],
    };
  }

  @override
  Stream<({String? token, String? chatId})> startChat({
    required String connectorId,
    required String prompt,
    required String query,
  }) {
    var body = {
      'prompt': prompt,
      'query': query,
    };

    return _sendStreamRequest<({String? token, String? chatId})>(
      Uri.https(gateway, '${_Config.connector(connectorId)}/chats'),
      headers: _override(streamHeaders(), body),
      body: body,
      converter: (event) {
        _logger.info('event: ${event.event} ${event.data}');
        return switch (event) {
          SSEResponse(event: 'stored', data: {'chat_id': String chatId}) => (token: null, chatId: chatId),
          SSEResponse(event: 'token', data: {'t': String token}) => (token: token, chatId: null),
          SSEResponse(event: 'done') => (token: null, chatId: null),
          _ => (token: null, chatId: null),
        };
      },
    );
  }

  @override
  Future<Iterable<Chat>?> getChats() async {
    final (json, _) = await get(_Config.chats);
    return switch (json) {
      {'chats': List? l} => [...?l?.map((each) => Chat.fromJson(each))],
      _ => null,
    };
  }

  @override
  Future<void> deleteChat(String chatId) => delete(_Config.chat(chatId));

  @override
  Stream<String?> sendMessageToChat({required String chatId, required String message}) {
    final body = {'message': message};
    final headers = _override(streamHeaders(), body);
    return _sendStreamRequest<String?>(
      Uri.https(gateway, _Config.messages(chatId)),
      headers: headers,
      body: body,
      converter: (event) {
        _logger.info('event: ${event.event} ${event.data}');
        return switch (event) {
          SSEResponse(event: 'token', data: {'t': String token}) => token,
          SSEResponse(event: 'done') => null,
          _ => throw ArgumentError(event),
        };
      },
    );
  }
}

void _errorHandler(dynamic error) {
  _logger.severe("API error: $error");
}

Stream<T> _sendStreamRequest<T>(
  Uri uri, {
  required T Function(SSEResponse) converter,
  Map<String, dynamic>? body,
  Map<String, String>? headers,
}) {
  final sseClient = SSEClient();

  final request = SSERequest(
    requestType: RequestMethodType.post,
    url: uri.toString(),
    headers: headers,
    body: body,
    onData: (_) {},
    onError: _errorHandler,
    onDone: () {
      _logger.info("Stream closed");
      sseClient.close(connectionId: 'connectionId');
    },
    retry: true,
  );
  return sseClient.connect("connectionId", request).map<T>(converter);
}

const _streamHeaders = {
  'Accept': 'text/event-stream',
  'Content-Type': 'application/json',
  'Cache-Control': 'no-cache',
  'Connection': 'keep-alive',
};
