# Standalone Redis Helm Chart

This is a self-contained Helm chart using Helm's native Go template language. It has no Bitnami `common` dependency.

The default image is `docker.io/library/redis:7.2.17`. The chart creates a password Secret, Redis ConfigMap, client and headless Services, a single-replica StatefulSet, and a persistent volume claim.

```bash
helm lint --strict ./charts/redis
helm template redis ./charts/redis --namespace default
helm install redis ./charts/redis --namespace default --set primary.persistence.storageClass=middleware-nfs
```

Authentication is enabled by default. Set `auth.password` or use `auth.existingSecret`. Redis data is stored under `/data` with AOF enabled.
