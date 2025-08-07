inspect = """
WITH 
  _databases AS (
    SELECT datname AS database_name
    FROM pg_database
    WHERE NOT datistemplate
      AND datname != 'rdsadmin' AND datname != 'qa' AND datname != 'pg_catalog'
  ),
  _schemata AS (
    SELECT 
      catalog_name AS database_name,
      schema_name,
      d.description AS schema_comment
    FROM information_schema.schemata
    JOIN pg_namespace n ON n.nspname = schema_name
    LEFT JOIN pg_description d ON d.objoid = n.oid
    WHERE (
        schema_name NOT IN ('pg_catalog', 'information_schema') 
            AND
        (
            %(schemata)s::TEXT[] IS NULL 
                OR 
            array_length(%(schemata)s::TEXT[], 1) = 0 
                OR 
            schema_name = ANY(%(schemata)s::TEXT[])    
        )
    )
)
, _tables AS (
  SELECT    
    table_schema,
    table_catalog AS database_name,
    table_name,
    max(d.description) AS table_comment
  FROM information_schema.tables t
  JOIN pg_class c 
    ON c.relname = table_name 
   AND c.relnamespace = (
    SELECT oid FROM pg_namespace 
    WHERE nspname = table_schema
  )
  LEFT JOIN pg_description d ON d.objoid = c.oid
  WHERE table_schema = ANY(SELECT schema_name FROM _schemata)
    AND table_type = 'BASE TABLE'
  GROUP BY t.table_schema, t.table_catalog, t.table_name
)
, _columns AS (
    SELECT
        columns.table_schema,
        columns.table_name,
        columns.column_name,
        columns.data_type AS column_data_type,
        columns.is_nullable,
        (tc.constraint_type = 'PRIMARY KEY') AS is_primary_key,
        exists(
            SELECT 1 
            FROM information_schema.constraint_column_usage fkc 
            WHERE columns.table_name = fkc.table_name 
            AND columns.column_name = fkc.column_name 
            AND fkc.constraint_name IN (
                SELECT constraint_name 
                FROM information_schema.table_constraints 
                WHERE constraint_type = 'FOREIGN KEY'
            )
        ) AS is_foreign_key
    FROM information_schema.columns columns
    LEFT JOIN information_schema.key_column_usage kcu 
      ON columns.table_schema = kcu.table_schema
     AND columns.table_name = kcu.table_name
     AND columns.column_name = kcu.column_name
    LEFT JOIN information_schema.table_constraints tc 
      ON kcu.constraint_name = tc.constraint_name
     AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
)
, _triggers AS (
    SELECT
        event_object_schema AS schema_name,
        event_object_table AS table_name,
        trigger_name,
        action_timing || ' ' || event_manipulation AS runs_when,
        action_statement AS executes_procedure,
        d.description AS trigger_comment
    FROM information_schema.triggers
    JOIN pg_trigger t ON t.tgname = trigger_name
    LEFT JOIN pg_description d ON d.objoid = t.oid
)
, _routines AS (
    SELECT
        routine_schema,
        routine_name,
        routines.data_type AS routine_return_type,
        string_agg(parameter_mode || ' ' || parameters.data_type, ', ' ORDER BY ordinal_position) AS args,
        d.description AS routine_comment
    FROM information_schema.routines
    LEFT JOIN information_schema.parameters 
      ON routines.specific_name = parameters.specific_name
    LEFT JOIN pg_proc p 
        ON p.proname = routine_name 
       AND p.pronamespace = (
           SELECT oid FROM pg_namespace 
           WHERE nspname = routine_schema
       )
    LEFT JOIN pg_description d ON d.objoid = p.oid
    WHERE routine_schema NOT IN ('information_schema', 'pg_catalog')
    GROUP BY routine_schema, routine_name, routines.data_type, d.description
)
SELECT jsonb_agg(
  jsonb_build_object(
    'databaseName', d.database_name,
    'schemata', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'schemaName', s.schema_name,
          'comment', s.schema_comment,
          'tables', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'tableName', t.table_name,
                'schema', t.table_schema,
                'comment', t.table_comment,
                'columns', (
                  SELECT jsonb_agg(
                    jsonb_build_object(
                      'columnName', c.column_name,
                      'dataType', c.column_data_type,
                      'isPrimaryKey', c.is_primary_key,
                      'isForeignKey', c.is_foreign_key,
                      'isNullable', c.is_nullable = 'YES'
                    )
                  )
                  FROM _columns c
                  WHERE c.table_schema = t.table_schema
                    AND c.table_name = t.table_name
                ),
                'triggers', (
                  SELECT jsonb_agg(
                    jsonb_build_object(
                      'triggerName', tr.trigger_name,
                      'runsWhen', tr.runs_when,
                      'executesProcedure', tr.executes_procedure,
                      'comment', tr.trigger_comment
                    )
                  )
                  FROM _triggers tr
                  WHERE tr.schema_name = t.table_schema
                    AND tr.table_name = t.table_name
                )
              )
            )
            FROM _tables t
            WHERE t.table_schema = s.schema_name
          ),
          'routines', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'routineName', r.routine_name,
                'args', string_to_array(r.args, ', '),
                'returnType', r.routine_return_type,
                'comment', r.routine_comment
              )
            )
            FROM _routines r
            WHERE r.routine_schema = s.schema_name
          )
        )
      )
      FROM _schemata s
      WHERE s.database_name = d.database_name
    )
  )
) AS databases
FROM _databases d
;
"""

trigger = """
SELECT
    trigger_schema,
    trigger_name,
    event_object_schema,
    event_object_table,
    action_timing,
    event_manipulation,
    action_orientation,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = %(trigger)s
  AND event_object_table = %(table)s
  AND event_object_schema = %(schema)s
;
"""

routine = """
SELECT
    p.proname AS "routineName",
    pg_catalog.pg_get_functiondef(p.oid) AS definition,
    string_to_array(pg_catalog.pg_get_function_arguments(p.oid) , ',') AS args,  
    t.typname AS "returnType"  
FROM pg_proc p
INNER JOIN pg_namespace n 
   ON p.pronamespace = n.oid
INNER JOIN pg_type t 
   ON p.prorettype = t.oid
WHERE n.nspname = %(schema)s 
    AND p.proname = %(routine)s
; 
"""
