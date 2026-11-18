# Helm Charts

`charts/` contains standalone charts maintained in this repository. The MySQL chart under `charts/mysql/` is an independent Helm chart that uses Helm's native Go template language and Kubernetes manifests.

It does not depend on Bitnami's `common` chart. The source-form Bitnami charts remain under `../bitnami/` for reference and are not loaded by the standalone MySQL chart.

## MySQL

The chart defaults to the Docker Official MySQL image `docker.io/library/mysql:8.4.13`, a StatefulSet with a persistent volume claim, generated TLS certificates, and enforced TLS transport.

```bash
helm lint --strict ./charts/mysql
helm template mysql ./charts/mysql --namespace default
helm install mysql ./charts/mysql --namespace default
```
