{{/*
Expand the name of the chart.
*/}}
{{- define "dify.name" -}}
{{- default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dify.fullname" -}}
{{- $name := default .Chart.Name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dify.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dify.labels" -}}
helm.sh/chart: {{ include "dify.chart" . }}
{{ include "dify.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* labels defined by user*/}}
{{- define "dify.ud.labels" -}}
{{- if .Values.labels }}
{{- toYaml .Values.labels }}
{{- end -}}
{{- end -}}

{{/* annotations defined by user*/}}
{{- define "dify.ud.annotations" -}}
{{- if .Values.annotations }}
{{- toYaml .Values.annotations }}
{{- end -}}
{{- end -}}

{{/* Extra labels on all workload pod templates (see global.podLabels). Not added to selectors. */}}
{{- define "dify.podExtraLabels" -}}
{{- if .Values.global.podLabels }}
{{- toYaml .Values.global.podLabels }}
{{- end }}
{{- end }}

{{/*
Image pull secrets shared by Dify workloads.
The Rancher UI exposes a single existing Secret while imagePullSecrets keeps
the upstream list-based interface available to Helm users.
*/}}
{{- define "dify.hasImagePullSecrets" -}}
{{- if or .Values.rancherUI.imagePullSecretName .Values.imagePullSecrets -}}true{{- end -}}
{{- end }}

{{- define "dify.imagePullSecrets" -}}
{{- if .Values.rancherUI.imagePullSecretName }}
- name: {{ .Values.rancherUI.imagePullSecretName | quote }}
{{- end }}
{{- with .Values.imagePullSecrets }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dify.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dify.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "dify.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "dify.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Namespace for plugin runtime resources */}}
{{- define "dify.pluginRuntimeNamespace" -}}
{{- default "default" (default .Release.Namespace .Values.plugin_connector.pluginNamespace) -}}
{{- end -}}

{{/* Namespace for plugin control-plane resources */}}
{{- define "dify.pluginControlPlaneNamespace" -}}
{{- default "default" .Release.Namespace -}}
{{- end -}}

{{/* MinIO host for plugin components */}}
{{- define "dify.pluginControlPlaneMinioHost" -}}
{{- printf "%s-minio.%s" (include "dify.fullname" .) (include "dify.pluginControlPlaneNamespace" .) -}}
{{- end -}}

{{/* Service account for plugin connector */}}
{{- define "dify.pluginConnectorServiceAccountName" -}}
{{- printf "%s-plugin-connector-sa" (include "dify.fullname" .) -}}
{{- end -}}

{{/* Service account for plugin manager */}}
{{- define "dify.pluginManagerServiceAccountName" -}}
{{- printf "%s-plugin-manager-sa" (include "dify.fullname" .) -}}
{{- end -}}

{{/* Service account for plugin controller */}}
{{- define "dify.pluginControllerServiceAccountName" -}}
{{- printf "%s-plugin-controller-sa" (include "dify.fullname" .) -}}
{{- end -}}

{{/*
Check if any additionalWorker is enabled
*/}}
{{- define "dify.hasEnabledAdditionalWorkers" -}}
{{- range .Values.additionalWorkers -}}
  {{- if .enabled -}}true{{- end -}}
{{- end -}}
{{- end }}

{{/*
Build external URL with optional port
Usage: {{ include "dify.externalUrl" (dict "domain" .Values.global.consoleApiDomain "useTLS" .Values.global.useTLS "port" .Values.global.externalPort) }}
*/}}
{{- define "dify.externalUrl" -}}
{{- $domain := .domain -}}
{{- $useTLS := .useTLS -}}
{{- $port := .port | default 80 -}}
{{- if $useTLS -}}https://{{- else -}}http://{{- end -}}{{ $domain }}{{- if and $port (ne (int $port) 80) (ne (int $port) 443) -}}:{{ $port }}{{- end -}}
{{- end -}}

{{/*
Build external WebSocket URL with optional port (ws/wss mirror of dify.externalUrl)
Usage: {{ include "dify.externalWsUrl" (dict "domain" .Values.global.consoleApiDomain "useTLS" .Values.global.useTLS "port" .Values.global.externalPort) }}
*/}}
{{- define "dify.externalWsUrl" -}}
{{- $domain := .domain -}}
{{- $useTLS := .useTLS -}}
{{- $port := .port | default 80 -}}
{{- if $useTLS -}}wss://{{- else -}}ws://{{- end -}}{{ $domain }}{{- if and $port (ne (int $port) 80) (ne (int $port) 443) -}}:{{ $port }}{{- end -}}
{{- end -}}

{{/*
OTEL configuration for ConfigMaps
Returns OTEL environment variables when both global.otel.enabled and enterpriseCollector.enabled are true
*/}}
{{- define "dify.otel.config" -}}
{{- if and .Values.global.otel.enabled .Values.enterpriseCollector.enabled }}
ENABLE_OTEL: "true"
OTLP_TRACE_ENDPOINT: "http://{{ template "dify.fullname" . }}-enterprise-collector-svc:4317"
OTLP_METRIC_ENDPOINT: "http://{{ template "dify.fullname" . }}-enterprise-collector-svc:4317"
OTLP_BASE_ENDPOINT: "http://{{ template "dify.fullname" . }}-enterprise-collector-svc:4317"
OTEL_EXPORTER_OTLP_PROTOCOL: "grpc"
OTEL_EXPORTER_TYPE: "otlp"
OTEL_SAMPLING_RATE: {{ .Values.global.otel.samplingRate | default "" | quote }}
OTEL_BATCH_EXPORT_SCHEDULE_DELAY: {{ .Values.global.otel.batchExportScheduleDelay | default "" | quote }}
OTEL_MAX_QUEUE_SIZE: {{ .Values.global.otel.maxQueueSize | default "" | quote }}
OTEL_MAX_EXPORT_BATCH_SIZE: {{ .Values.global.otel.maxExportBatchSize | default "" | quote }}
OTEL_METRIC_EXPORT_INTERVAL: {{ .Values.global.otel.metricExportInterval | default "" | quote }}
OTEL_BATCH_EXPORT_TIMEOUT: {{ .Values.global.otel.batchExportTimeout | default "" | quote }}
OTEL_METRIC_EXPORT_TIMEOUT: {{ .Values.global.otel.metricExportTimeout | default "" | quote }}
{{- end }}
{{- end }}

{{/*
OTEL API key for Secrets
Returns OTLP_API_KEY when both global.otel.enabled and enterpriseCollector.enabled are true
*/}}
{{- define "dify.otel.secret" -}}
{{- if and .Values.global.otel.enabled .Values.enterpriseCollector.enabled }}
OTLP_API_KEY: {{ .Values.global.innerApiKey | b64enc | quote }}
{{- end }}
{{- end }}

{{- define "dify.customCA.enabled" -}}
{{- if and .Values.global.customCA.enabled .Values.global.customCA.existingSecret }}true{{- end }}
{{- end }}

{{- define "dify.customCA.configName" -}}
{{- printf "%s-shared-custom-ca-config" (include "dify.fullname" .) -}}
{{- end }}

{{- define "dify.customCA.volume" -}}
- name: custom-ca-secret
  secret:
    secretName: {{ .Values.global.customCA.existingSecret | quote }}
    items:
      - key: {{ .Values.global.customCA.key | quote }}
        path: {{ .Values.global.customCA.key | quote }}
- name: custom-ca-combined
  emptyDir: {}
{{- end }}

{{- define "dify.customCA.volumeMount" -}}
- name: custom-ca-combined
  mountPath: {{ .Values.global.customCA.mountPath | quote }}
  readOnly: true
{{- end }}

{{- define "dify.customCA.initContainer" -}}
- name: init-custom-ca
  image: {{ .Values.global.customCA.initImage | default "alpine:3.20" }}
  imagePullPolicy: IfNotPresent
  command:
    - sh
    - -c
    - |
      if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        cp /etc/ssl/certs/ca-certificates.crt /custom-ca-combined/ca-bundle.crt
      elif [ -f /etc/ssl/cert.pem ]; then
        cp /etc/ssl/cert.pem /custom-ca-combined/ca-bundle.crt
      else
        echo "No system CA bundle found, creating empty bundle"
        touch /custom-ca-combined/ca-bundle.crt
      fi
      echo >> /custom-ca-combined/ca-bundle.crt
      cat /custom-ca-secret/{{ .Values.global.customCA.key }} >> /custom-ca-combined/ca-bundle.crt
  volumeMounts:
    - name: custom-ca-secret
      mountPath: /custom-ca-secret
      readOnly: true
    - name: custom-ca-combined
      mountPath: /custom-ca-combined
{{- end }}
