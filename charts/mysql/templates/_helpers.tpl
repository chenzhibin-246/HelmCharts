{{/*
Copyright Broadcom, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{- define "mysql.primary.fullname" -}}
{{- if eq .Values.architecture "replication" }}
{{- printf "%s-%s" (include "common.names.fullname" .) .Values.primary.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "common.names.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "mysql.secondary.fullname" -}}
{{- printf "%s-%s" (include "common.names.fullname" .) .Values.secondary.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the proper MySQL image name
*/}}
{{- define "mysql.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{- define "mysql.imageFlavor" -}}
{{- $flavor := default "auto" .Values.image.flavor -}}
{{- if ne $flavor "auto" -}}
    {{- $flavor -}}
{{- else if regexMatch "(^|/)(bitnami|bitnamilegacy|bitnamiprem|bitnamisecure)/mysql$" .Values.image.repository -}}
    bitnami
{{- else -}}
    official
{{- end -}}
{{- end -}}

{{- define "mysql.officialArgs" -}}
{{- $args := list -}}
{{- if and (not .Values.primary.args) (not .Values.primary.command) -}}
    {{- $args = append $args "mysqld" -}}
{{- end -}}
{{- if .Values.primary.args -}}
    {{- $args = concat $args (fromYamlArray (include "common.tplvalues.render" (dict "value" .Values.primary.args "context" $))) -}}
{{- end -}}
{{- if .Values.primary.extraFlags -}}
    {{- $args = concat $args (compact (regexSplit "[[:space:]]+" .Values.primary.extraFlags -1)) -}}
{{- end -}}
{{- if .Values.tls.enabled -}}
    {{- $cert := ternary .Values.tls.certFilename "tls.crt" (not (empty .Values.tls.existingSecret)) -}}
    {{- $key := ternary .Values.tls.certKeyFilename "tls.key" (not (empty .Values.tls.existingSecret)) -}}
    {{- $args = append $args (printf "--ssl-cert=%s/%s" (include "mysql.tls.directory" .) $cert) -}}
    {{- $args = append $args (printf "--ssl-key=%s/%s" (include "mysql.tls.directory" .) $key) -}}
    {{- with (include "mysql.tlsCACert" .) -}}
        {{- $args = append $args (printf "--ssl-ca=%s" .) -}}
    {{- end -}}
{{- end -}}
{{- if .Values.tls.requireSecureTransport -}}
    {{- $args = append $args "--require-secure-transport=ON" -}}
{{- end -}}
{{- if $args -}}
args: {{- $args | toYaml | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "mysql.validateImageFlavor" -}}
{{- if eq (include "mysql.imageFlavor" .) "official" -}}
    {{- if ne .Values.architecture "standalone" -}}
        {{- fail "The Docker Official MySQL image supports architecture=standalone in this chart. For replication, configure a Bitnami MySQL image with image.flavor=bitnami." -}}
    {{- end -}}
    {{- if or .Values.startdbScriptsConfigMap .Values.startdbScripts .Values.passwordUpdateJob.enabled -}}
        {{- fail "startdbScripts and passwordUpdateJob require the Bitnami MySQL entrypoint. For fresh Docker Official MySQL installs, use initdbScripts." -}}
    {{- end -}}
{{- else if .Values.tls.requireSecureTransport -}}
    {{- fail "tls.requireSecureTransport requires the Docker Official MySQL image." -}}
{{- end -}}
{{- if and .Values.tls.requireSecureTransport (not .Values.tls.enabled) -}}
    {{- fail "tls.requireSecureTransport requires tls.enabled=true." -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper metrics image name
*/}}
{{- define "mysql.metrics.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.metrics.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper image name (for the init container volume-permissions image)
*/}}
{{- define "mysql.volumePermissions.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.volumePermissions.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "mysql.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.image .Values.metrics.image .Values.volumePermissions.image) "global" .Values.global) }}
{{- end -}}

{{/*
Get the initialization scripts ConfigMap name.
*/}}
{{- define "mysql.initdbScriptsCM" -}}
{{- if .Values.initdbScriptsConfigMap -}}
    {{- printf "%s" (tpl .Values.initdbScriptsConfigMap $) -}}
{{- else -}}
    {{- printf "%s-init-scripts" (include "mysql.primary.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Get the startdb scripts ConfigMap name.
*/}}
{{- define "mysql.startdbScriptsCM" -}}
{{- if .Values.startdbScriptsConfigMap -}}
    {{- printf "%s" (tpl .Values.startdbScriptsConfigMap $) -}}
{{- else -}}
    {{- printf "%s-start-scripts" (include "mysql.primary.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
 Returns the proper service account name depending if an explicit service account name is set
 in the values file. If the name is not set it will default to either mysql.fullname if serviceAccount.create
 is true or default otherwise.
*/}}
{{- define "mysql.serviceAccountName" -}}
    {{- if .Values.serviceAccount.create -}}
        {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
    {{- else -}}
        {{ default "default" .Values.serviceAccount.name }}
    {{- end -}}
{{- end -}}

{{/*
Return the configmap with the MySQL Primary configuration
*/}}
{{- define "mysql.primary.configmapName" -}}
{{- if .Values.primary.existingConfigmap -}}
    {{- printf "%s" (tpl .Values.primary.existingConfigmap $) -}}
{{- else -}}
    {{- printf "%s" (include "mysql.primary.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a configmap object should be created for MySQL Secondary
*/}}
{{- define "mysql.primary.createConfigmap" -}}
{{- if and .Values.primary.configuration (not .Values.primary.existingConfigmap) }}
    {{- true -}}
{{- else -}}
{{- end -}}
{{- end -}}

{{/*
Return the configmap with the MySQL Primary configuration
*/}}
{{- define "mysql.secondary.configmapName" -}}
{{- if .Values.secondary.existingConfigmap -}}
    {{- printf "%s" (tpl .Values.secondary.existingConfigmap $) -}}
{{- else -}}
    {{- printf "%s" (include "mysql.secondary.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a configmap object should be created for MySQL Secondary
*/}}
{{- define "mysql.secondary.createConfigmap" -}}
{{- if and (eq .Values.architecture "replication") .Values.secondary.configuration (not .Values.secondary.existingConfigmap) }}
    {{- true -}}
{{- else -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret with MySQL credentials
*/}}
{{- define "mysql.secretName" -}}
    {{- if .Values.auth.existingSecret -}}
        {{- printf "%s" (tpl .Values.auth.existingSecret $) -}}
    {{- else -}}
        {{- printf "%s" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for MySQL
*/}}
{{- define "mysql.createSecret" -}}
{{- if and (not .Values.auth.existingSecret) (not .Values.auth.customPasswordFiles) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for MySQL
*/}}
{{- define "mysql.createPreviousSecret" -}}
{{- if and .Values.passwordUpdateJob.previousPasswords.rootPassword (not .Values.passwordUpdateJob.previousPasswords.existingSecret) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret with previous MySQL credentials
*/}}
{{- define "mysql.update-job.previousSecretName" -}}
    {{- if .Values.passwordUpdateJob.previousPasswords.existingSecret -}}
        {{- /* The secret with the new password is managed externally */ -}}
        {{- tpl .Values.passwordUpdateJob.previousPasswords.existingSecret $ -}}
    {{- else if .Values.passwordUpdateJob.previousPasswords.rootPassword -}}
        {{- /* The secret with the new password is managed externally */ -}}
        {{- printf "%s-previous-secret" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- /* The secret with the new password is managed by the helm chart. We use the current secret name as it has the old password */ -}}
        {{- include "common.names.fullname" . -}}
    {{- end -}}
{{- end -}}

{{/*
Return the secret with new MySQL credentials
*/}}
{{- define "mysql.update-job.newSecretName" -}}
    {{- if and (not .Values.passwordUpdateJob.previousPasswords.existingSecret) (not .Values.passwordUpdateJob.previousPasswords.rootPassword) -}}
        {{- /* The secret with the new password is managed by the helm chart. We create a new secret as the current one has the old password */ -}}
        {{- printf "%s-new-secret" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- /* The secret with the new password is managed externally */ -}}
        {{- include "mysql.secretName" . -}}
    {{- end -}}
{{- end -}}

{{/*
Return the MySQL TLS credentials secret
*/}}
{{- define "mysql.tlsSecretName" -}}
{{- if .Values.tls.existingSecret -}}
    {{- print (tpl .Values.tls.existingSecret $) -}}
{{- else -}}
    {{- printf "%s-crt" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mysql.tls.directory" -}}
{{- ternary "/etc/mysql/tls" "/opt/bitnami/mysql/certs" (eq (include "mysql.imageFlavor" .) "official") -}}
{{- end -}}

{{- define "mysql.tlsCACert" -}}
{{- $directory := include "mysql.tls.directory" . -}}
{{- if .Values.tls.existingSecret -}}
    {{- with .Values.tls.certCAFilename -}}
        {{- printf "%s/%s" $directory . -}}
    {{- end -}}
{{- else if or .Values.tls.autoGenerated.enabled .Values.tls.ca -}}
    {{- printf "%s/ca.crt" $directory -}}
{{- end -}}
{{- end -}}

{{- define "mysql.tls.dnsNames" -}}
{{- $namespace := include "common.names.namespace" . -}}
{{- $primary := include "mysql.primary.fullname" . -}}
{{- $services := list $primary -}}
{{- if eq .Values.architecture "replication" -}}
    {{- $services = append $services (include "mysql.secondary.fullname" .) -}}
{{- end -}}
{{- $names := list "localhost" -}}
{{- range $services -}}
    {{- $headless := printf "%s-headless" . | trunc 63 | trimSuffix "-" -}}
    {{- $names = concat $names (list . (printf "%s.%s" . $namespace) (printf "%s.%s.svc" . $namespace) (printf "%s.%s.svc.%s" . $namespace $.Values.clusterDomain) (printf "%s.%s.svc.%s" $headless $namespace $.Values.clusterDomain) (printf "*.%s.%s.svc.%s" $headless $namespace $.Values.clusterDomain)) -}}
{{- end -}}
{{- $names | toYaml -}}
{{- end -}}

{{/* Check if there are rolling tags in the images */}}
{{- define "mysql.checkRollingTags" -}}
{{- include "common.warnings.rollingTag" .Values.image }}
{{- include "common.warnings.rollingTag" .Values.metrics.image }}
{{- include "common.warnings.rollingTag" .Values.volumePermissions.image }}
{{- end -}}

{{/*
Compile all warnings into a single message, and call fail.
*/}}
{{- define "mysql.validateValues" -}}
{{- $messages := list -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{- printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}
