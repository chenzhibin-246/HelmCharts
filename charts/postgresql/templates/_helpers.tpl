{{- define "postgresql.name" -}}{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "postgresql.fullname" -}}{{ if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}{{ else }}{{ printf "%s-%s" .Release.Name (include "postgresql.name" .) | trunc 63 | trimSuffix "-" }}{{ end }}{{- end -}}
{{- define "postgresql.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
app.kubernetes.io/name: {{ include "postgresql.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{ with .Values.commonLabels }}{{ toYaml . }}{{ end }}
{{- end -}}
{{- define "postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postgresql.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}
{{- define "postgresql.image" -}}{{ $registry := trimSuffix "/" .Values.image.registry }}{{ if $registry }}{{ printf "%s/%s:%s" $registry .Values.image.repository .Values.image.tag }}{{ else }}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{ end }}{{- end -}}
{{- define "postgresql.secretName" -}}{{ default (include "postgresql.fullname" .) .Values.auth.existingSecret }}{{- end -}}
{{- define "postgresql.serviceName" -}}{{ include "postgresql.fullname" . }}{{- end -}}
{{- define "postgresql.headlessServiceName" -}}{{ printf "%s-headless" (include "postgresql.fullname" .) }}{{- end -}}
{{- define "postgresql.containerSecurityContext" -}}
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
