{{- define "redis.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "redis.fullname" -}}{{ if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}{{ else }}{{ printf "%s-%s" .Release.Name (include "redis.name" .) | trunc 63 | trimSuffix "-" }}{{ end }}{{- end -}}
{{- define "redis.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
app.kubernetes.io/name: {{ include "redis.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{ with .Values.commonLabels }}{{ toYaml . }}{{ end }}
{{- end -}}
{{- define "redis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "redis.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}
{{- define "redis.image" -}}{{ $registry := trimSuffix "/" .Values.image.registry }}{{ if $registry }}{{ printf "%s/%s:%s" $registry .Values.image.repository .Values.image.tag }}{{ else }}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{ end }}{{- end -}}
{{- define "redis.secretName" -}}{{ default (include "redis.fullname" .) .Values.auth.existingSecret }}{{- end -}}
{{- define "redis.serviceName" -}}{{ include "redis.fullname" . }}{{- end -}}
{{- define "redis.headlessServiceName" -}}{{ printf "%s-headless" (include "redis.fullname" .) }}{{- end -}}
{{- define "redis.containerSecurityContext" -}}
{{- if .Values.primary.containerSecurityContext.enabled }}
allowPrivilegeEscalation: {{ .Values.primary.containerSecurityContext.allowPrivilegeEscalation }}
readOnlyRootFilesystem: {{ .Values.primary.containerSecurityContext.readOnlyRootFilesystem }}
runAsNonRoot: {{ .Values.primary.containerSecurityContext.runAsNonRoot }}
runAsUser: {{ .Values.primary.containerSecurityContext.runAsUser }}
runAsGroup: {{ .Values.primary.containerSecurityContext.runAsGroup }}
capabilities:
  drop: [ALL]
seccompProfile:
  type: RuntimeDefault
{{- end }}
{{- end }}
