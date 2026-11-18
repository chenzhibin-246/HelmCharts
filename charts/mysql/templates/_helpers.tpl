{{/* Return the chart name, allowing a caller to override it. */}}
{{- define "mysql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Return the fully qualified release name, allowing a caller to override it. */}}
{{- define "mysql.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "mysql.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mysql.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
app.kubernetes.io/name: {{ include "mysql.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "mysql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mysql.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end }}

{{- define "mysql.image" -}}
{{- $registry := trimSuffix "/" .Values.image.registry -}}
{{- if $registry -}}{{ printf "%s/%s:%s" $registry .Values.image.repository .Values.image.tag }}{{- else -}}{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}{{- end -}}
{{- end -}}

{{- define "mysql.secretName" -}}
{{- default (include "mysql.fullname" .) .Values.auth.existingSecret -}}
{{- end -}}

{{- define "mysql.tlsSecretName" -}}
{{- default (printf "%s-tls" (include "mysql.fullname" .)) .Values.tls.secretName -}}
{{- end -}}

{{- define "mysql.serviceName" -}}
{{- include "mysql.fullname" . -}}
{{- end -}}

{{- define "mysql.headlessServiceName" -}}
{{- printf "%s-headless" (include "mysql.fullname" .) -}}
{{- end -}}

{{- define "mysql.tlsDnsNames" -}}
{{- $service := include "mysql.serviceName" . -}}
{{- $headless := include "mysql.headlessServiceName" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $domain := "cluster.local" -}}
{{- list $service (printf "%s.%s" $service $namespace) (printf "%s.%s.svc" $service $namespace) (printf "%s.%s.svc.%s" $service $namespace $domain) $headless (printf "%s.%s" $headless $namespace) (printf "%s.%s.svc" $headless $namespace) (printf "%s.%s.svc.%s" $headless $namespace $domain) | toYaml -}}
{{- end -}}

{{- define "mysql.containerSecurityContext" -}}
{{- if .Values.primary.containerSecurityContext.enabled }}
allowPrivilegeEscalation: {{ .Values.primary.containerSecurityContext.allowPrivilegeEscalation }}
readOnlyRootFilesystem: {{ .Values.primary.containerSecurityContext.readOnlyRootFilesystem }}
runAsNonRoot: {{ .Values.primary.containerSecurityContext.runAsNonRoot }}
runAsUser: {{ .Values.primary.containerSecurityContext.runAsUser }}
runAsGroup: {{ .Values.primary.containerSecurityContext.runAsGroup }}
capabilities:
  drop:
    - ALL
seccompProfile:
  type: RuntimeDefault
{{- end }}
{{- end }}
