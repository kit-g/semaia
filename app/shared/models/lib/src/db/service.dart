import 'package:semaia_models/src/db/connector.dart';

abstract interface class ConnectorService {
  Future<Iterable<Connector>?> listConnectors();

  Future<Connector> getConnector(String id);

  Future<Connector> createConnector(Connector connector);

  Future<Connector> updateConnector(Connector connector);

  Future<void> deleteConnector(String id);
}
