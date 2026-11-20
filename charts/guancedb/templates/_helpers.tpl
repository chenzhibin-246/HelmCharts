{{/* vim: set filetype=mustache: */}}

{{- if and .Values.guance_select.enabled .Values.guance_insert.enabled -}}
{{- $selectArgs := .Values.guance_select.extraArgs | default dict -}}
{{- $insertArgs := .Values.guance_insert.extraArgs | default dict -}}
{{- $flags := list
      "scopeDB.streamFieldsDefault"
      "scopeDB.streamFieldsTenant"
      "scopeDB.clusteredFieldsDefault"
      "scopeDB.clusteredFieldsTenant"
  -}}
{{- range $flag := $flags -}}
  {{- $selectHas := hasKey $selectArgs $flag -}}
  {{- $insertHas := hasKey $insertArgs $flag -}}
  {{- if ne $selectHas $insertHas -}}
    {{- fail (printf "%s must be set in both guance_select.extraArgs and guance_insert.extraArgs, or omitted from both" $flag) -}}
  {{- end -}}
  {{- if and $selectHas $insertHas -}}
    {{- $selectVal := printf "%v" (index $selectArgs $flag) -}}
    {{- $insertVal := printf "%v" (index $insertArgs $flag) -}}
    {{- if ne $selectVal $insertVal -}}
      {{- fail (printf "%s mismatch: guance_select.extraArgs[%s]=%q, guance_insert.extraArgs[%s]=%q" $flag $flag $selectVal $flag $insertVal) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Version compatibility check.
ScopeDB >= v1.4.14 must be paired with GuanceDB >= v1.45.0. Running a new ScopeDB
against an old GuanceDB is unsupported, so fail when the ScopeDB constraint is
satisfied but the GuanceDB constraint is not. (The reverse — a new GuanceDB with
an older ScopeDB — is allowed.)
*/}}
{{- if .Values.scopedb.enabled -}}
{{- $guancedbTag := .Values.image.tag | default "" | toString -}}
{{- $scopedbTag := dig "image" "tag" "" .Values.scopedb | toString -}}
{{- $semverRe := `^v?[0-9]+\.[0-9]+\.[0-9]+` -}}
{{- if and (regexMatch $semverRe $guancedbTag) (regexMatch $semverRe $scopedbTag) -}}
{{- $scopedbNew := semverCompare ">=1.4.14" $scopedbTag -}}
{{- $guancedbNew := semverCompare ">=1.45.0" $guancedbTag -}}
{{- if and $scopedbNew (not $guancedbNew) -}}
{{- fail (printf "Incompatible versions: ScopeDB >= v1.4.14 requires GuanceDB >= v1.45.0 (got ScopeDB scopedb.image.tag=%q, GuanceDB image.tag=%q). Upgrade GuanceDB to >= v1.45.0." $scopedbTag $guancedbTag) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "guancedb.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "guancedb.fullname" -}}
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
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "guancedb.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account
*/}}
{{- define "guancedb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "guancedb.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create unified labels for guancedb components
*/}}
{{- define "guancedb.common.matchLabels" -}}
app.kubernetes.io/name: {{ include "guancedb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "guancedb.common.metaLabels" -}}
helm.sh/chart: {{ include "guancedb.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "guancedb.guance_storage.labels" -}}
{{ include "guancedb.guance_storage.matchLabels" . }}
{{ include "guancedb.common.metaLabels" . }}
{{- end -}}

{{- define "guancedb.guance_storage.matchLabels" -}}
app.kubernetes.io/component: {{ .Values.guance_storage.name }}
{{ include "guancedb.common.matchLabels" . }}
{{- end -}}

{{- define "guancedb.guance_select.labels" -}}
{{ include "guancedb.guance_select.matchLabels" . }}
{{ include "guancedb.common.metaLabels" . }}
{{- end -}}

{{- define "guancedb.guance_select.matchLabels" -}}
app.kubernetes.io/component: {{ .Values.guance_select.name }}
{{ include "guancedb.common.matchLabels" . }}
{{- end -}}

{{- define "guancedb.guance_insert.labels" -}}
{{ include "guancedb.guance_insert.matchLabels" . }}
{{ include "guancedb.common.metaLabels" . }}
{{- end -}}

{{- define "guancedb.guance_insert.matchLabels" -}}
app.kubernetes.io/component: {{ .Values.guance_insert.name }}
{{ include "guancedb.common.matchLabels" . }}
{{- end -}}

{{- define "guancedb.guance_throttler.labels" -}}
{{ include "guancedb.guance_throttler.matchLabels" . }}
{{ include "guancedb.common.metaLabels" . }}
{{- end -}}

{{- define "guancedb.guance_throttler.matchLabels" -}}
app.kubernetes.io/component: {{ .Values.guance_throttler.name }}
{{ include "guancedb.common.matchLabels" . }}
{{- end -}}

{{- define "guancedb.guance_meta.labels" -}}
{{ include "guancedb.guance_meta.matchLabels" . }}
{{ include "guancedb.common.metaLabels" . }}
{{- end -}}

{{- define "guancedb.guance_meta.matchLabels" -}}
app.kubernetes.io/component: {{ .Values.guance_meta.name }}
{{ include "guancedb.common.matchLabels" . }}
{{- end -}}
{{- define "guancedb.datakitAnnotationDeprecated" -}}
datakit/prom.instances: |-
 [[inputs.prom]]
   measurement_name = "guancedb"
   url = "http://$IP:{{ . }}/metrics"
   interval = "10s"
   [inputs.prom.tags]
     k8s_namespace = "$NAMESPACE"
     pod = "$PODNAME"
{{- end -}}

{{- define "guancedb.datakitAnnotation" -}}
datakit/prom.instances: |-
 [[inputs.prom]]
   measurement_name = "guancedb"
   url = "http://$IP:{{ . }}/metrics"
   interval = "10s"
   [inputs.prom.tags]
     k8s_namespace = "$NAMESPACE"
     pod = "$PODNAME"
{{- end -}}

{{- define "guancedb.datakitAnnotations" -}}
prometheus.io/scrape: "true"
prometheus.io/port: "{{ . }}"
prometheus.io/param_measurement: "guancedb"
prometheus.io/param_tags: "k8s_namespace=$NAMESPACE,pod=$PODNAME"
{{- end -}}

{{/*
Create a fully qualified guance_storage name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "guancedb.guance_storage.fullname" -}}
{{- if .Values.guance_storage.fullnameOverride -}}
{{- .Values.guance_storage.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if eq $name .Release.Name -}}
{{ .Values.guance_storage.name }}
{{- else if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.guance_storage.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.guance_storage.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified guance_select name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "guancedb.guance_select.fullname" -}}
{{- if .Values.guance_select.fullnameOverride -}}
{{- .Values.guance_select.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if eq $name .Release.Name -}}
{{ .Values.guance_select.name }}
{{- else if hasPrefix $name .Release.Name }}
{{- printf "%s%s" .Values.guance_select.name (trimPrefix $name .Release.Name) }}
{{- else if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.guance_select.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.guance_select.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified guance_select name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "guancedb.guance_insert.fullname" -}}
{{- if .Values.guance_insert.fullnameOverride -}}
{{- .Values.guance_insert.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if eq $name .Release.Name -}}
{{ .Values.guance_insert.name }}
{{- else if hasPrefix $name .Release.Name }}
{{- printf "%s%s" .Values.guance_insert.name (trimPrefix $name .Release.Name) }}
{{- else if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.guance_insert.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.guance_insert.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified guance_meta name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "guancedb.guance_meta.fullname" -}}
{{- if .Values.guance_meta.fullnameOverride -}}
{{- .Values.guance_meta.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if eq $name .Release.Name -}}
{{ .Values.guance_meta.name }}
{{- else if hasPrefix $name .Release.Name }}
{{- printf "%s%s" .Values.guance_meta.name (trimPrefix $name .Release.Name) }}
{{- else if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.guance_meta.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.guance_meta.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "guancedb.guance_meta.secretName" -}}
{{- if .Values.guance_meta.secret.name -}}
{{- .Values.guance_meta.secret.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "guancedb.guance_meta.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "guancedb.guance_meta.serviceURL" -}}
{{- $service := include "guancedb.guance_meta.fullname" . -}}
{{- printf "http://%s.%s.svc.%s:%v" $service .Release.Namespace .Values.clusterDomainSuffix .Values.guance_meta.service.servicePort -}}
{{- end -}}

{{- define "guancedb.guance_meta.clientURL" -}}
{{- $externalURL := .Values.guance_meta.externalURL | default "" -}}
{{- if and .Values.guance_meta.enabled $externalURL -}}
{{- fail "guance_meta.enabled and guance_meta.externalURL cannot both be set" -}}
{{- else if .Values.guance_meta.enabled -}}
{{- include "guancedb.guance_meta.serviceURL" . -}}
{{- else -}}
{{- $externalURL -}}
{{- end -}}
{{- end -}}

{{/*
Create a fully qualified guance_throttler name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "guancedb.guance_throttler.fullname" -}}
{{- if .Values.guance_throttler.fullnameOverride -}}
{{- .Values.guance_throttler.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if eq $name .Release.Name -}}
{{ .Values.guance_throttler.name }}
{{- else if hasPrefix $name .Release.Name }}
{{- printf "%s%s" .Values.guance_throttler.name (trimPrefix $name .Release.Name) }}
{{- else if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.guance_throttler.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.guance_throttler.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "guancedb.guance_insert.guance_storage-pod-fqdn" -}}
{{- $pod := include "guancedb.guance_storage.fullname" . -}}
{{- $svc := include "guancedb.guance_storage.fullname" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $dnsSuffix := .Values.clusterDomainSuffix -}}
{{- range $i := until (.Values.guance_storage.replicaCount | int) -}}
{{- printf "- --storageNode=%s-%d.%s.%s.svc.%s:8400\n" $pod $i $svc $namespace $dnsSuffix -}}
{{- end -}}
{{- end -}}

{{- define "guancedb.guance_select.guance_storage-pod-fqdn" -}}
{{- $pod := include "guancedb.guance_storage.fullname" . -}}
{{- $svc := include "guancedb.guance_storage.fullname" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $dnsSuffix := .Values.clusterDomainSuffix -}}
{{- range $i := until (.Values.guance_storage.replicaCount | int) -}}
{{- printf "- --storageNode=%s-%d.%s.%s.svc.%s:8401\n" $pod $i $svc $namespace $dnsSuffix -}}
{{- end -}}
{{- end -}}

{{- define "guancedb.guance_select.guance_insert-service-fqdn" -}}
{{- $svc := include "guancedb.guance_insert.fullname" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $dnsSuffix := .Values.clusterDomainSuffix -}}
{{- printf "- --insertNode=%s.%s.svc.%s:%v\n" $svc $namespace $dnsSuffix .Values.guance_insert.service.servicePort -}}
{{- end -}}

{{- define "split-host-port" -}}
{{- $hp := split ":" . -}}
{{- printf "%s" $hp._1 -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for ingress.
*/}}
{{- define "guancedb.ingress.apiVersion" -}}
  {{- if and (.Capabilities.APIVersions.Has "networking.k8s.io/v1") -}}
      {{- print "networking.k8s.io/v1" -}}
  {{- else if .Capabilities.APIVersions.Has "networking.k8s.io/v1beta1" -}}
    {{- print "networking.k8s.io/v1beta1" -}}
  {{- else -}}
    {{- print "extensions/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{/*
Return if ingress is stable.
*/}}
{{- define "guancedb.ingress.isStable" -}}
  {{- eq (include "guancedb.ingress.apiVersion" .) "networking.k8s.io/v1" -}}
{{- end -}}

{{/*
Return if ingress supports ingressClassName.
*/}}
{{- define "guancedb.ingress.supportsIngressClassName" -}}
  {{- or (eq (include "guancedb.ingress.isStable" .) "true") (and (eq (include "guancedb.ingress.apiVersion" .) "networking.k8s.io/v1beta1")) -}}
{{- end -}}

{{/*
Return if ingress supports pathType.
*/}}
{{- define "guancedb.ingress.supportsPathType" -}}
  {{- or (eq (include "guancedb.ingress.isStable" .) "true") (and (eq (include "guancedb.ingress.apiVersion" .) "networking.k8s.io/v1beta1")) -}}
{{- end -}}


{{- define "guancedb.guance_storage.hasInitContainer" -}}
    {{- gt (len .Values.guance_storage.initContainers) 0 -}}
{{- end -}}

{{- define "guancedb.guance_storage.initContiners" -}}
{{- if eq (include "guancedb.guance_storage.hasInitContainer" . ) "true" -}}
{{- with .Values.guance_storage.initContainers -}}
{{ toYaml . }}
{{- end -}}
[]
{{- end -}}
{{- end -}}

{{- define "guancedb.guance_throttler.hasInitContainer" -}}
    {{- gt (len .Values.guance_throttler.initContainers) 0 -}}
{{- end -}}

{{- define "guancedb.guance_throttler.initContiners" -}}
{{- if eq (include "guancedb.guance_throttler.hasInitContainer" . ) "true" -}}
{{- with .Values.guance_throttler.initContainers -}}
{{ toYaml . }}
{{- end -}}
[]
{{- end -}}
{{- end -}}

{{/*
Parse a Kubernetes CPU quantity into cores: "12" -> 12, "0.5" -> 0.5, "500m" -> 0.5.
Sprig's atoi drops the parse error, so a suffixed or fractional quantity reads as 0
cores and anything sized from it renders as 0 — for fileQueue.workers that means the
file queue starts no push goroutines and never drains. Fail on a quantity this cannot
parse, and on a non-positive one, instead of rendering a manifest that looks fine.
Usage: include "guancedb.cpuCores" (dict "value" $q "path" "<values path, for the message>")
*/}}
{{- define "guancedb.cpuCores" -}}
{{- $raw := .value | toString -}}
{{- if not (regexMatch `^[0-9]+(\.[0-9]+)?m?$` $raw) -}}
  {{- fail (printf "invalid %s: expected a CPU quantity like \"12\", \"0.5\" or \"500m\", got %q" .path $raw) -}}
{{- end -}}
{{- $cores := 0.0 -}}
{{- if hasSuffix "m" $raw -}}
  {{- $cores = divf (float64 (trimSuffix "m" $raw)) 1000.0 -}}
{{- else -}}
  {{- $cores = float64 $raw -}}
{{- end -}}
{{- if le $cores 0.0 -}}
  {{- fail (printf "invalid %s: expected a positive CPU quantity, got %q" .path $raw) -}}
{{- end -}}
{{- $cores -}}
{{- end -}}
