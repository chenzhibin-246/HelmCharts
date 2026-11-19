# Standalone PostgreSQL Helm Chart

This is a self-contained Helm chart using Helm's native Go template language. It has no Bitnami `common` dependency.

The default image is `docker.io/library/postgres:16.16`. The chart creates a password Secret, PostgreSQL ConfigMap, client and headless Services, a single-replica StatefulSet, and a persistent volume claim.

```bash
helm lint --strict ./charts/postgresql
helm template postgresql ./charts/postgresql --namespace default
helm install postgresql ./charts/postgresql --namespace default --set primary.persistence.storageClass=middleware-nfs
```

Set `auth.username`, `auth.password`, and `auth.database` for an application role and database. Set `auth.existingSecret` to use an existing Secret. Initialization scripts are mounted at `/docker-entrypoint-initdb.d` and run only during first initialization.
