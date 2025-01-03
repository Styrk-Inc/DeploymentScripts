{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "aitrism-chart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{/*{{- define "chart.fullname" -}}*/}}
{{/*{{- if .Values.fullnameOverride }}*/}}
{{/*{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}*/}}
{{/*{{- else }}*/}}
{{/*{{- $name := default .Chart.Name .Values.nameOverride }}*/}}
{{/*{{- if contains $name .Release.Name }}*/}}
{{/*{{- .Release.Name | trunc 63 | trimSuffix "-" }}*/}}
{{/*{{- else }}*/}}
{{/*{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}*/}}
{{/*{{- end }}*/}}
{{/*{{- end }}*/}}
{{/*{{- end }}*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "kafka-consumer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Define the name of the Kafka consumer */}}
{{- define "kafka-consumer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

# Define default labels
{{- define "kafka-consumer.labels" -}}
helm.sh/chart: {{ include "kafka-consumer.chart" . }}
app.kubernetes.io/name: {{ include "kafka-consumer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

# Define selector labels
{{- define "kafka-consumer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kafka-consumer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "kafka-consumer.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Create a default service account name.
*/}}
{{- define "kafka-consumer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "kafka-consumer.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end }}
