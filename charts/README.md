# MySQL Helm Chart

`charts/mysql/` 基于 `bitnami/mysql/` 中的 Bitnami MySQL Chart 14.0.5。仓库内的 Chart 版本为 `14.0.5+helm4.1`，MySQL 应用版本为 `9.4.0`。参数说明见 [Bitnami MySQL 文档](mysql/README.md#parameters)。

`common` 依赖固定为 `2.31.4`，源码随 MySQL Chart 一同存放在 `mysql/charts/common/`。Helm 可直接从该目录加载依赖，以下预检可在离线环境执行。

## 使用 Helm 4.0 预检

在仓库根目录执行：

```sh
helm dependency build --skip-refresh ./charts/mysql
helm lint --strict ./charts/mysql
helm install mysql ./charts/mysql --namespace database --dry-run=client --hide-secret
```

使用主从模式时，加上 `--set architecture=replication` 验证相应配置。

## 安装或升级

```sh
helm upgrade --install mysql ./charts/mysql --namespace database --create-namespace
```

升级已有 Release 时，使用原 Release 名称、命名空间和环境配置文件，保留现有凭据和持久卷配置。通过 `-f` 传入环境配置文件。部署时，集群节点需要能拉取该环境配置中指定的容器镜像。
