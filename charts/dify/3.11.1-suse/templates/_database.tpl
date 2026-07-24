{{/*
  Database helpers

  - dify.defaultDbName           : per-credential default DB name
  - dify.dbName                  : actual DB name (override or default)
  - dify.dbCredentialUser        : per-credential user (or empty for fallback)
  - dify.dbCredentialPassword    : per-credential password (or empty for fallback)
  - dify.dbInstance              : connection metadata (engine/host/port/...) as JSON
  - dify.datasource              : full datasource as JSON (driver, db_type, host, ...)
  - dify.{dify,enterprise,pluginDaemon,audit}Datasource : convenience wrappers
*/}}

{{/* get default database name for credential key
Returns the default database name based on credential key.
*/}}
{{- define "dify.defaultDbName" -}}
{{- $credentialKey := .credentialKey -}}
{{- $defaultDbNames := dict 
    "dify" "dify" 
    "enterprise" "enterprise" 
    "plugin_daemon" "dify_plugin_daemon" 
    "audit" "audit" 
-}}
{{- index $defaultDbNames $credentialKey -}}
{{- end }}

{{/* get database name for credential key
Returns the database name based on externalDatabase or default.
*/}}
{{- define "dify.dbName" -}}
{{- $credentialKey := .credentialKey -}}
{{- $defaultDbName := include "dify.defaultDbName" (dict "credentialKey" $credentialKey) -}}
{{- if .Values.externalDatabase.enabled -}}
  {{- $dbName := index .Values.externalDatabase.databases $credentialKey -}}
  {{- $dbName | default $defaultDbName -}}
{{- else -}}
  {{- $defaultDbName -}}
{{- end -}}
{{- end }}

{{/* get per-database credential user for a given credential key.
Returns the user from externalDatabase.databaseCredentials[credentialKey] if set,
otherwise returns empty string (application layer falls back to global DB_USER).
*/}}
{{- define "dify.dbCredentialUser" -}}
{{- $credentialKey := .credentialKey -}}
{{- if and .Values.externalDatabase.enabled .Values.externalDatabase.databaseCredentials -}}
  {{- $creds := index .Values.externalDatabase.databaseCredentials $credentialKey -}}
  {{- if $creds -}}
    {{- $creds.user | default "" -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/* get per-database credential password for a given credential key.
Returns the password from externalDatabase.databaseCredentials[credentialKey] if set,
otherwise returns empty string (application layer falls back to global DB_PASS).
*/}}
{{- define "dify.dbCredentialPassword" -}}
{{- $credentialKey := .credentialKey -}}
{{- if and .Values.externalDatabase.enabled .Values.externalDatabase.databaseCredentials -}}
  {{- $creds := index .Values.externalDatabase.databaseCredentials $credentialKey -}}
  {{- if $creds -}}
    {{- $creds.password | default "" -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/* get db instance configuration
Returns a JSON object with db instance connection details:
{
  "engine": "postgres|mysql|tidb",
  "host": "...",
  "port": "5432",
  "user": "...",
  "password": "...",
  "timezone": "UTC",
  "pg_ssl_mode": "...",
  "pg_uri_scheme": "...",
  "pg_extras": "...",
  "mysql_params": "...",
  "mysql_tls": "false"
}
*/}}
{{- define "dify.dbInstance" -}}
{{- $dbInstance := dict -}}
{{- $engine := "postgres" -}}
{{- if .Values.externalDatabase.enabled -}}
  {{- $engine = (.Values.externalDatabase.engine | default "postgres") -}}
  {{- $_ := set $dbInstance "engine" $engine -}}
  {{- $_ := set $dbInstance "host" (.Values.externalDatabase.host | default "localhost") -}}
  {{- $defaultPort := 5432 -}}
  {{- if eq $engine "mysql" -}}
    {{- $defaultPort = 3306 -}}
  {{- else if eq $engine "tidb" -}}
    {{- $defaultPort = 4000 -}}
  {{- end -}}
  {{- $_ := set $dbInstance "port" (printf "%v" (.Values.externalDatabase.port | default $defaultPort)) -}}
  {{- $_ := set $dbInstance "user" (.Values.externalDatabase.user | default "postgres") -}}
  {{- $_ := set $dbInstance "password" (.Values.externalDatabase.password | default "") -}}
  {{- $_ := set $dbInstance "timezone" (.Values.externalDatabase.timezone | default "UTC") -}}
  {{- $_ := set $dbInstance "pg_ssl_mode" (.Values.externalDatabase.dialectOptions.postgres.sslMode | default "require") -}}
  {{- $_ := set $dbInstance "pg_uri_scheme" (.Values.externalDatabase.dialectOptions.postgres.uriScheme | default "postgresql") -}}
  {{- $_ := set $dbInstance "pg_extras" (.Values.externalDatabase.dialectOptions.postgres.extras | default "") -}}
  {{- $_ := set $dbInstance "mysql_params" (.Values.externalDatabase.dialectOptions.mysql.params | default "charset=utf8mb4&parseTime=true&loc=UTC") -}}
  {{- $_ := set $dbInstance "mysql_tls" (.Values.externalDatabase.dialectOptions.mysql.tls | default false) -}}
{{- else if .Values.postgresql.enabled -}}
  {{- $username := "" -}}
  {{- $password := "" -}}
  {{- with .Values.postgresql.global.postgresql.auth -}}
    {{- if empty .username -}}
      {{- $username = "postgres" -}}
      {{- $password = .postgresPassword -}}
    {{- else -}}
      {{- $username = .username -}}
      {{- $password = .password -}}
    {{- end -}}
  {{- end -}}
  {{- $host := "" -}}
  {{- if eq .Values.postgresql.architecture "replication" -}}
    {{- $host = printf "%s-postgresql-primary" .Release.Name -}}
  {{- else -}}
    {{- $host = printf "%s-postgresql" .Release.Name -}}
  {{- end -}}
  {{- $_ := set $dbInstance "engine" "postgres" -}}
  {{- $_ := set $dbInstance "host" $host -}}
  {{- $_ := set $dbInstance "port" "5432" -}}
  {{- $_ := set $dbInstance "user" $username -}}
  {{- $_ := set $dbInstance "password" $password -}}
  {{- $_ := set $dbInstance "timezone" "UTC" -}}
  {{- $_ := set $dbInstance "pg_ssl_mode" "disable" -}}
  {{- $_ := set $dbInstance "pg_uri_scheme" "postgresql" -}}
  {{- $_ := set $dbInstance "pg_extras" "" -}}
  {{- $_ := set $dbInstance "mysql_params" "" -}}
  {{- $_ := set $dbInstance "mysql_tls" false -}}
{{- end -}}
{{- $dbInstance | toJson -}}
{{- end }}

{{/* get datasource from external database (PostgreSQL/MySQL/TiDB) or internal postgresql
Returns a JSON object with database connection details:
{
  "db_type": "postgresql|mysql",
  "db_default": "postgres|mysql",
  "driver": "postgres|mysql",
  "user": "...",
  "password": "...",
  "host": "...",
  "port": "5432",
  "ssl_mode": "...",
  "uri_scheme": "postgresql",
  "db_extras": "...",
  "db_charset": "...",
  "db_name": "..."
}

Usage: 
  As JSON: include "dify.datasource" .
  As YAML: include "dify.datasource" . | fromJson | toYaml
  With credential key: include "dify.datasource" (dict "Values" .Values "credentialKey" "enterprise")

Note: db_name is now included in the returned JSON object with default values based on credential key.
Note: db_type is the application-level database type (postgresql/mysql), used by Dify api/worker/plugin-daemon.
Note: db_default is the default database for initial connection (postgres for PostgreSQL, mysql for MySQL/TiDB).
*/}}
{{- define "dify.datasource" -}}
{{- $credentialKey := .credentialKey -}}
{{- $datasource := dict -}}
{{- $_ := set $datasource "driver" "postgres" -}}
{{- $_ := set $datasource "db_type" "postgresql" -}}
{{- $_ := set $datasource "db_default" "postgres" -}}
{{- if .Values.externalDatabase.enabled -}}
  {{- $engine := .Values.externalDatabase.engine | default "postgres" -}}
  {{- $driver := "postgres" -}}
  {{- $dbType := "postgresql" -}}
  {{- $dbDefault := "postgres" -}}
  {{- if or (eq $engine "mysql") (eq $engine "tidb") -}}
    {{- $driver = "mysql" -}}
    {{- $dbType = "mysql" -}}
    {{- $dbDefault = "mysql" -}}
  {{- end -}}
  {{- $_ := set $datasource "driver" $driver -}}
  {{- $_ := set $datasource "db_type" $dbType -}}
  {{- $_ := set $datasource "db_default" $dbDefault -}}
  {{- $_ := set $datasource "host" (.Values.externalDatabase.host | default "localhost") -}}
  {{- $defaultPort := 5432 -}}
  {{- if eq $engine "mysql" -}}
    {{- $defaultPort = 3306 -}}
  {{- else if eq $engine "tidb" -}}
    {{- $defaultPort = 4000 -}}
  {{- end -}}
  {{- $_ := set $datasource "port" (printf "%v" (.Values.externalDatabase.port | default $defaultPort)) -}}
  {{- $_ := set $datasource "user" (.Values.externalDatabase.user | default "postgres") -}}
  {{- $_ := set $datasource "password" (.Values.externalDatabase.password | default "") -}}
  {{- if or (eq $engine "mysql") (eq $engine "tidb") -}}
    {{- if .Values.externalDatabase.dialectOptions.mysql.tls -}}
      {{- $_ := set $datasource "ssl_mode" "require" -}}
    {{- else -}}
      {{- $_ := set $datasource "ssl_mode" "disable" -}}
    {{- end -}}
  {{- else -}}
    {{- $_ := set $datasource "ssl_mode" (.Values.externalDatabase.dialectOptions.postgres.sslMode | default "require") -}}
  {{- end -}}
  {{- if or (eq $engine "mysql") (eq $engine "tidb") -}}
    {{- $_ := set $datasource "uri_scheme" "mysql+pymysql" -}}
    {{- $_ := set $datasource "db_extras" "" -}}
  {{- else -}}
    {{- $_ := set $datasource "uri_scheme" (.Values.externalDatabase.dialectOptions.postgres.uriScheme | default "postgresql") -}}
    {{- $_ := set $datasource "db_extras" (.Values.externalDatabase.dialectOptions.postgres.extras | default "") -}}
  {{- end -}}
  {{- $_ := set $datasource "db_charset" "" -}}
  {{- $defaultDbName := include "dify.defaultDbName" (dict "credentialKey" $credentialKey) -}}
  {{- $dbName := index .Values.externalDatabase.databases $credentialKey -}}
  {{- $_ := set $datasource "db_name" ($dbName | default $defaultDbName) -}}
{{- else if .Values.postgresql.enabled -}}
  {{- $username := "" -}}
  {{- $password := "" -}}
  {{- with .Values.postgresql.global.postgresql.auth -}}
    {{- if empty .username -}}
      {{- $username = "postgres" -}}
      {{- $password = .postgresPassword -}}
    {{- else -}}
      {{- $username = .username -}}
      {{- $password = .password -}}
    {{- end -}}
  {{- end -}}
  {{- $host := "" -}}
  {{- if eq .Values.postgresql.architecture "replication" -}}
    {{- $host = printf "%s-postgresql-primary" .Release.Name -}}
  {{- else -}}
    {{- $host = printf "%s-postgresql" .Release.Name -}}
  {{- end -}}
  {{- $_ := set $datasource "db_type" "postgresql" -}}
  {{- $_ := set $datasource "db_default" "postgres" -}}
  {{- $_ := set $datasource "user" $username -}}
  {{- $_ := set $datasource "password" $password -}}
  {{- $_ := set $datasource "host" $host -}}
  {{- $_ := set $datasource "port" "5432" -}}
  {{- $_ := set $datasource "ssl_mode" "disable" -}}
  {{- $_ := set $datasource "uri_scheme" "postgresql" -}}
  {{- $_ := set $datasource "db_extras" "" -}}
  {{- $_ := set $datasource "db_charset" "" -}}
  {{- $defaultDbName := include "dify.defaultDbName" (dict "credentialKey" $credentialKey) -}}
  {{- $_ := set $datasource "db_name" $defaultDbName -}}
{{- end -}}
{{- $datasource | toJson -}}
{{- end }}


{{/* Shortcuts for getting datasources - no need to specify credentialKey */}}
{{- define "dify.difyDatasource" -}}
{{- include "dify.datasource" (dict "Values" .Values "Release" .Release "credentialKey" "dify") -}}
{{- end }}

{{- define "dify.enterpriseDatasource" -}}
{{- include "dify.datasource" (dict "Values" .Values "Release" .Release "credentialKey" "enterprise") -}}
{{- end }}

{{- define "dify.pluginDaemonDatasource" -}}
{{- include "dify.datasource" (dict "Values" .Values "Release" .Release "credentialKey" "plugin_daemon") -}}
{{- end }}

{{- define "dify.auditDatasource" -}}
{{- include "dify.datasource" (dict "Values" .Values "Release" .Release "credentialKey" "audit") -}}
{{- end }}
