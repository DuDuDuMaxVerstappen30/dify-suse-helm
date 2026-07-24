{{/*
  Redis helpers

  - dify.redis.svc                : in-cluster Bitnami service name
  - dify.redis.assertNoCluster   : fail-fast on cluster.enabled=true
                                    (main Redis does not support Cluster)
  - dify.redis.mode              : "standalone" | "sentinel" (inferred from sentinel.enabled)
  - dify.redis.envBlock          : emit REDIS_* env keys (dual-emits community legacy keys)
  - dify.redis.envBlockInternal  : standalone block for the in-cluster Bitnami subchart
  - dify.redis.dsn               : single redis:// URL for collector + Caddy
  - dify.eventBus.envBlock       : EVENT_BUS_REDIS_* env keys (community-only;
                                    independent Redis, optionally a Redis Cluster)
*/}}

{{- define "dify.redis.svc" -}}
{{- printf "%s-redis-master" .Release.Name }}
{{- end }}

{{/* dify.redis.assertNoCluster — fail `helm template` if the deprecated
externalRedis.cluster.enabled flag is set. The main Redis (cache,
Celery broker, EE Go services) does not support Redis Cluster end-to-end:
  - Celery cannot speak Redis Cluster (broker URL has no cluster scheme)
  - dify-enterprise Go factory rejects mode=cluster at startup
  - enterprise queues use cross-key operations that hit CROSSSLOT on cluster
The supported path for cluster-scale workloads is to leave the main
Redis on standalone/sentinel and deploy a separate Redis Cluster
behind the Event Bus via externalRedis.eventBus.url. */}}
{{- define "dify.redis.assertNoCluster" -}}
{{- if and .Values.externalRedis.enabled (dig "cluster" "enabled" false .Values.externalRedis) -}}
{{- fail "externalRedis.cluster.enabled is not supported on the main Redis. The main Redis backs the cache, the Celery broker, and the dify-enterprise Go services — none of these speak Redis Cluster. Keep externalRedis on standalone/sentinel; if you need cluster-scale fan-out for the community Event Bus, deploy a separate Redis Cluster and set externalRedis.eventBus.url + externalRedis.eventBus.useClusters=true." -}}
{{- end -}}
{{- end }}

{{/* dify.redis.mode — "standalone" | "sentinel". Inferred from the
existing externalRedis.sentinel.enabled boolean; cluster is rejected
upstream by dify.redis.assertNoCluster. */}}
{{- define "dify.redis.mode" -}}
{{- include "dify.redis.assertNoCluster" . -}}
{{- if and .Values.externalRedis.enabled .Values.externalRedis.sentinel.enabled -}}
sentinel
{{- else -}}
standalone
{{- end -}}
{{- end }}

{{/* dify.redis.envBlock — emit the REDIS_* env block into the shared
ConfigMap. Always emits REDIS_MODE / _USERNAME / _DB / _USE_SSL plus
mode-specific keys (HOST/PORT for standalone, SENTINEL_* for sentinel).
In sentinel mode, also dual-emits the community legacy keys
(REDIS_USE_SENTINEL / REDIS_SENTINELS) that the Python services read.
Passwords are emitted by redis-secret.yaml.

Timeout / retry knobs (REDIS_READ_TIMEOUT / WRITE_TIMEOUT /
DIAL_TIMEOUT / MAX_RETRIES) have sensible 1s/1s/10s/3 defaults in
the EE service config and are not plumbed through values.yaml —
operators needing non-defaults can override via extraEnv. */}}
{{- define "dify.redis.envBlock" -}}
{{- $mode := include "dify.redis.mode" . -}}
{{- $r := .Values.externalRedis -}}
REDIS_MODE: {{ $mode | quote }}
REDIS_USERNAME: {{ $r.username | default "" | quote }}
REDIS_DB: {{ $r.db | default 0 | toString | quote }}
REDIS_USE_SSL: {{ $r.useSSL | default false | toString | quote }}
{{- if eq $mode "standalone" }}
REDIS_HOST: {{ $r.host | quote }}
REDIS_PORT: {{ $r.port | toString | quote }}
{{- else if eq $mode "sentinel" }}
REDIS_SENTINEL_ADDRS: {{ $r.sentinel.nodes | default "" | quote }}
REDIS_SENTINEL_SERVICE_NAME: {{ $r.sentinel.serviceName | default "" | quote }}
REDIS_SENTINEL_USERNAME: {{ $r.sentinel.username | default "" | quote }}
{{- /* community legacy keys — dify (Python) reads these */}}
REDIS_USE_SENTINEL: "true"
REDIS_SENTINELS: {{ $r.sentinel.nodes | default "" | quote }}
  {{- if hasKey $r.sentinel "socketTimeout" }}
REDIS_SENTINEL_SOCKET_TIMEOUT: {{ $r.sentinel.socketTimeout | toString | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{/* dify.redis.envBlockInternal — same shape as envBlock but for the
in-cluster Bitnami subchart (when redis.enabled). Always standalone. */}}
{{- define "dify.redis.envBlockInternal" -}}
{{- $svc := printf "%s-redis-master" .Release.Name -}}
{{- $port := .Values.redis.master.service.ports.redis -}}
REDIS_MODE: "standalone"
REDIS_USERNAME: ""
REDIS_DB: "0"
REDIS_USE_SSL: {{ .Values.redis.tls.enabled | toString | quote }}
REDIS_HOST: {{ $svc | quote }}
REDIS_PORT: {{ $port | toString | quote }}
{{- end }}

{{/* dify.eventBus.envBlock — community-only EVENT_BUS_REDIS_* envs.
Emitted only when externalRedis.eventBus.url is non-empty (i.e. the
operator has explicitly pointed the Event Bus at a separate Redis).
dify-enterprise Go services do not consume these; the keys live in
the same shared ConfigMap as the main REDIS_* envs because per-Pod
each consumer ignores envs it doesn't bind.

When url is empty this define renders nothing, and the community
Python services derive PUBSUB_REDIS_URL automatically from
REDIS_HOST / REDIS_PORT (the Event Bus follows the main Redis).

EVENT_BUS_REDIS_CHANNEL_TYPE (pubsub | sharded | streams) is not
plumbed here — Python defaults to pubsub on its own. Operators
wanting sharded/streams can set it via api / worker / worker-beat /
additional-worker / plugin-daemon extraEnv. Same for the streams-
only EVENT_BUS_STREAMS_RETENTION_SECONDS. */}}
{{- define "dify.eventBus.envBlock" -}}
{{- $eb := .Values.externalRedis.eventBus | default dict -}}
{{- if $eb.url -}}
EVENT_BUS_REDIS_URL: {{ $eb.url | quote }}
EVENT_BUS_REDIS_USE_CLUSTERS: {{ $eb.useClusters | default false | toString | quote }}
{{- end }}
{{- end }}

{{/* dify.redis.dsn — single redis:// URL for the main Redis. Used by
the enterprise collector and the gateway Caddy module; both consume
REDIS_DSN rather than the discrete envs. Sentinel mode emits the
redis+sentinel:// scheme. Cluster is unreachable here (asserted out). */}}
{{- define "dify.redis.dsn" -}}
{{- if .Values.externalRedis.enabled -}}
  {{- include "dify.redis.assertNoCluster" . -}}
  {{- $user := .Values.externalRedis.username | urlquery | replace "+" "%20" -}}
  {{- $pass := .Values.externalRedis.password | urlquery | replace "+" "%20" -}}
  {{- $db := .Values.externalRedis.db | default 0 -}}
  {{- $useSSL := .Values.externalRedis.useSSL | default false -}}
  {{- $auth := "" -}}
  {{- if $user -}}
    {{- $auth = printf "%s:%s@" $user $pass -}}
  {{- else if $pass -}}
    {{- $auth = printf ":%s@" $pass -}}
  {{- end -}}
  {{- if .Values.externalRedis.sentinel.enabled -}}
    {{- $proto := ternary "rediss+sentinel" "redis+sentinel" $useSSL -}}
    {{ $proto }}://{{ $auth }}{{ .Values.externalRedis.sentinel.nodes | default "" }}/{{ $db }}?sentinelService={{ .Values.externalRedis.sentinel.serviceName }}
  {{- else -}}
    {{- $proto := ternary "rediss" "redis" $useSSL -}}
    {{- $host := .Values.externalRedis.host | default "localhost" -}}
    {{- $port := .Values.externalRedis.port | default 6379 -}}
    {{ $proto }}://{{ $auth }}{{ $host }}:{{ $port }}/{{ $db }}
  {{- end -}}
{{- else if .Values.redis.enabled -}}
  {{- $pass := .Values.redis.global.redis.password | urlquery | replace "+" "%20" -}}
  {{- $svc := include "dify.redis.svc" . -}}
  redis://:{{ $pass }}@{{ $svc }}:6379/0
{{- else -}}
  ""
{{- end -}}
{{- end }}
