# Standalone MySQL Helm Chart

This chart is a self-contained Helm chart that uses Helm's native Go template functions. It has no dependency on Bitnami's `common` chart and does not import templates from another chart.

The default image is the Docker Official Image `docker.io/library/mysql:8.4.13`. The chart renders a Secret, TLS Secret, ConfigMap, Services, and one MySQL StatefulSet. Persistent storage uses the StatefulSet `volumeClaimTemplates` field.

## Install

```bash
helm install mysql ./charts/mysql --namespace default --create-namespace
```

Set a storage class and credentials through a values file or `--set` flags.

```bash
helm install mysql ./charts/mysql \
  --namespace default \
  --set primary.persistence.storageClass=middleware-nfs \
  --set auth.username=app \
  --set auth.database=appdb
```

The chart generates passwords when `auth.rootPassword` and `auth.password` are empty. Use `auth.existingSecret` when an existing Secret has the keys configured by `auth.existingSecretKeys`.

## TLS

TLS is enabled by default. Helm generates a CA and a certificate whose SANs include the client Service DNS names. Set `tls.requireSecureTransport=true` to reject plaintext TCP connections. A client that validates the generated certificate can use the Service DNS name and `tls.caFilename` from Secret `{{ include "mysql.tlsSecretName" . }}`.

Use `tls.existingSecret` to provide `tls.crt`, `tls.key`, and `ca.crt` or change the key names with the `tls.*Filename` values.

## Initialization scripts

Place `.sql`, `.sql.gz`, or executable `.sh` content in `initdbScripts`. The scripts are mounted at `/docker-entrypoint-initdb.d` and run by the Docker Official MySQL entrypoint only when the data directory is initialized.

## Template validation

```bash
helm lint --strict ./charts/mysql
helm template mysql ./charts/mysql --namespace default --debug
```
