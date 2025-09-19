{{/*
Expand the name of the chart.
*/}}
{{- define "openedxinfra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common annotations that match Kustomize commonAnnotations
*/}}
{{- define "openedxinfra.annotations" -}}
app.kubernetes.io/version: {{ .Values.global.openedxVersion | quote }}
{{- with .Values.commonAnnotations }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openedxinfra.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openedxinfra.labels" -}}
helm.sh/chart: {{ include "openedxinfra.chart" . }}
app.kubernetes.io/name: {{ include "openedxinfra.name" . }}
app.kubernetes.io/instance: openedxinfra-{{ .Values.global.instanceId }}
app.kubernetes.io/version: {{ .Values.global.openedxVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: openedxinfra
{{- with .Values.commonLabels }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openedxinfra.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openedxinfra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-specific labels
*/}}
{{- define "openedxinfra.componentLabels" -}}
{{- $component := .component }}
{{- include "openedxinfra.labels" .root | nindent 0 }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Component-specific selector labels
*/}}
{{- define "openedxinfra.componentSelectorLabels" -}}
{{- $component := .component }}
app.kubernetes.io/name: {{ include "openedxinfra.name" .root }}
app.kubernetes.io/instance: openedxinfra-{{ .root.Values.global.instanceId }}
app.kubernetes.io/component: {{ $component }}
{{- end }}
