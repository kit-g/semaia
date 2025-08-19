import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:semaia_models/semaia_models.dart';

class DatabaseInspector with ChangeNotifier, Iterable<Connector> implements SignOutStateSentry {
  final _dbs = <Connector, DbStructure?>{};
  final ConnectorService _connectorService;
  bool isInitialized = false;
  final QueryService _queryService;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  Connector? _selectedConnector;

  Connector? get selectedConnector => _selectedConnector;

  set selectedConnector(Connector? value) {
    _selectedConnector = value;
    notifyListeners();
  }

  DatabaseInspector({
    required QueryService queryService,
    required ConnectorService connectorService,
    this.onError,
  }) : _queryService = queryService,
       _connectorService = connectorService;

  @override
  void onSignOut() {
    _dbs.clear();
  }

  @override
  Iterator<Connector> get iterator => _dbs.keys.iterator;

  static DatabaseInspector of(BuildContext context) {
    return Provider.of<DatabaseInspector>(context, listen: false);
  }

  static DatabaseInspector watch(BuildContext context) {
    return Provider.of<DatabaseInspector>(context, listen: true);
  }

  DbStructure? operator [](Connector connector) {
    return _dbs[connector];
  }

  Future<void> init() async {
    try {
      isInitialized = false;
      final connectors = await _connectorService.listConnectors();

      for (final connector in connectors ?? <Connector>[]) {
        _dbs[connector] = connector.structure;
      }

      _selectedConnector = _dbs.keys.firstOrNull;
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    } finally {
      isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> add(Connector connector) async {
    _dbs[connector] = null;
    notifyListeners();
    final saved = await _connectorService.createConnector(connector);
    _dbs
      ..remove(connector)
      ..putIfAbsent(saved, () => null);
    notifyListeners();
  }

  Future<void> edit(Connector connector) async {
    _dbs[connector] = null;
    notifyListeners();

    final saved = switch (connector.id) {
      String() => await _connectorService.updateConnector(connector),
      _ => await _connectorService.createConnector(connector),
    };
    _dbs
      ..remove(connector)
      ..putIfAbsent(saved, () => null);
    notifyListeners();
  }

  Future<void> delete(Connector connector) async {
    _dbs.remove(connector);
    notifyListeners();
    if (connector.id case String id) {
      await _connectorService.deleteConnector(id);
    }
  }

  Future<void> inspect(Connector connector) async {
    if (connector.id case String id) {
      final structure = await _queryService.inspect(id);
      _dbs[connector] = structure;
      notifyListeners();
    }
  }
}
