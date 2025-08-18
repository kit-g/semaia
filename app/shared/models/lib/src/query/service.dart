import 'inspect.dart';
import 'query.dart';

abstract interface class QueryService {
  Future<SqlQueryResult> sendQuery(String connectorId, String query);

  Future<DbStructure> inspect(String connectorId);

  Future<DbRoutine> getRoutineDefinition(String connectorId, String schema, String routine);

  Future<DbTrigger> getTriggerDefinition(String connectorId, String schema, String table, String trigger);
}
