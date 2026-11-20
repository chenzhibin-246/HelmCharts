{{/*
Expand the name of the chart.
*/}}
{{- define "scopedb.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "scopedb.fullname" -}}
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
Create ScopeQL name as <scopedb.fullname>-scopeql or just scopeql if scopedb.fullname is scopedb
*/}}
{{- define "scopeql.fullname" -}}
{{- if eq (include "scopedb.fullname" .) "scopedb" }}
{{- printf "scopeql" }}
{{- else }}
{{- printf "%s-scopeql" (include "scopedb.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "scopedb.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "scopedb.labels" -}}
helm.sh/chart: {{ include "scopedb.chart" . }}
{{ include "scopedb.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ $.Values.image.tag | default .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "scopeql.labels" -}}
helm.sh/chart: {{ include "scopedb.chart" . }}
{{ include "scopeql.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.scopeql.image.tag }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "scopedb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "scopedb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "scopeql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "scopeql.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ include "scopeql.fullname" $ }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "scopedb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "scopedb.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Validate CPU:Memory ratio is 1:2
Only handles CPU format like "16" and memory format like "32Gi", fails for other formats or missing limits
*/}}
{{- define "scopedb.validateCpuMemoryRatio" -}}
{{- $resources := .resources -}}
{{- if not $resources.limits -}}
  {{- fail "scopedb.nodegroups.[].resources.limits is required" -}}
{{- end -}}
{{- if not $resources.limits.cpu -}}
  {{- fail "scopedb.nodegroups.[].resources.limits.cpu is required" -}}
{{- end -}}
{{- if not $resources.limits.memory -}}
  {{- fail "scopedb.nodegroups.[].resources.limits.memory is required" -}}
{{- end -}}
{{- $cpuStr := $resources.limits.cpu | toString -}}
{{- $memStr := $resources.limits.memory | toString -}}
{{- if not (regexMatch "^[0-9]+$" $cpuStr) -}}
  {{- fail (printf "invalid scopedb.nodegroups.[].resources.limits.cpu format, expected format like '16', got '%s'" $cpuStr) -}}
{{- end -}}
{{- if not (regexMatch "^[0-9]+Gi$" $memStr) -}}
  {{- fail (printf "invalid scopedb.nodegroups.[].resources.limits.memory format, expected format like '32Gi', got '%s'" $memStr) -}}
{{- end -}}
{{- $cpu := $cpuStr | int -}}
{{- $memory := $memStr | trimSuffix "Gi" | int -}}
{{- $name := .name | toString -}}
{{- if eq "ingest" $name }}
  {{- if ne $cpu $memory -}}
    {{- fail (printf "invalid CPU:memory ratio for %s, expected 1:1, got %d:%d" .name $cpu $memory) -}}
  {{- end -}}
{{- else if hasSuffix "meta" $name }}
  {{- if ne (mul $cpu 2) $memory -}}
    {{- fail (printf "invalid CPU:memory ratio for %s, expected 1:2, got %d:%d" .name $cpu $memory) -}}
  {{- end -}}
{{- else }}
  {{- if gt (mul $cpu 4) $memory -}}
    {{- fail (printf "invalid CPU:memory ratio for %s, expected <= 1:4, got %d:%d" .name $cpu $memory) -}}
  {{- end -}}
{{- end }}
{{- end }}

{{/*
Returns "true" when any nodegroup sets dedicatedService. Needed for
nodegroups whose pods must not be selected by the main (NodePort) Service, e.g. VCI pods,
which the VCI admission webhook forbids behind a NodePort Service.
*/}}
{{- define "scopedb.hasServiceExclusion" -}}
{{- range .Values.nodegroups }}{{- if .dedicatedService }}true{{- end }}{{- end }}
{{- end }}
