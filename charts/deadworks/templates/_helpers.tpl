{{/*
Expand the name of the chart.
*/}}
{{- define "deadworks.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "deadworks.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart name and version as used by the chart label.
*/}}
{{- define "deadworks.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "deadworks.labels" -}}
helm.sh/chart: {{ include "deadworks.chart" . }}
{{ include "deadworks.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "deadworks.selectorLabels" -}}
app.kubernetes.io/name: {{ include "deadworks.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the env ConfigMap.
*/}}
{{- define "deadworks.envConfigMapName" -}}
{{- printf "%s-env" (include "deadworks.fullname" .) }}
{{- end }}

{{/*
Name of the env Secret (chart-managed, or existing when existingEnvSecret is set).
*/}}
{{- define "deadworks.envSecretName" -}}
{{- default (printf "%s-env-secret" (include "deadworks.fullname" .)) .Values.existingEnvSecret }}
{{- end }}

{{/*
Game port: service.port override, else server.port, else 27015.
*/}}
{{- define "deadworks.gamePort" -}}
{{- .Values.service.port | default .Values.server.port | default 27015 | toString }}
{{- end }}
