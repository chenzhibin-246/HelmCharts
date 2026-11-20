# GuanceDB Helm Chart

This maintained copy is based on OCI chart `guancedb` version `1.2.1` and keeps the original `pubrepo.guance.com` image repositories. It updates deprecated Kubernetes API versions for Helm 4 and current Kubernetes releases. The original OCI download remains under `guancedb-oci-download/guancedb/guancedb`.

The `scopedb` chart is vendored under `charts/scopedb` and is loaded as a local subchart. It is intentionally kept in the chart tree so `helm lint`, `helm template`, and `helm package` work without a registry dependency.

## 常用配置

### guance-insert 启动参数

- scopeDB.enableActiveTable：默认 true，是否使用 view 和 session 新模式（guance-select 需要同步设置）
- streamaggr.onlySystemQueries：是否禁用非必需流式聚合（流式聚合出问题时使用）
- fileQueue.workers：guance-insert 到日志存储（ScopeDB、Doris）的写入并发，通常不需要设置

### guance-select 启动参数

指标：
- search.maxShowUniqueTimeseries：默认 1000 万，指标 show 函数查询的时序数限制，指标管理等页面会用到
大查询：
- search.minRowsForLargeQuery：默认 5000 万，用来根据原始行数判断是否为大查询
- search.minTimeRangeForLargeQuery：默认 24h，用来根据时间范围判断是否为大查询
采样：
- search.rowsToSampleForExplorer：查看器查询的采样行数，默认 2 亿，此参数优先级高于请求中的 rows_to_sample 参数
- search.rowsToSampleForFacet：facet 查询的采样行数，默认 5000 万
- search.rowsToSampleForDashboard：仪表板查询的采样行数，默认 2 亿
- search.rowsToSample：其它查询的采样行数，默认 1 亿
- search.rowsToSampleForArchive：归档报告查询的采样行数，默认 5 亿
分段查询：
- search.scopeDB.disableCursorWithStreamAggr：默认 true，是否禁用基于流式聚合行数预估的分段
- search.scopeDB.disableCursorWithSystemTable：默认 true，是否禁用基于 system.partitions 表的行数预估的分段
- search.scopeDB.aggregateCursorRows：分段聚合查询的扫描行数，默认为 5 千万，数据量大且计算资源充裕时可以调大，比如新加坡 SaaS 为 1 亿
其它：
- scopeDB.enableActiveTable：默认 true，是否使用 view 和 session 新模式
- search.maxConcurrentRequestsPerTenant：默认为 5，如果 guance-select 有 3 个实例，则可以简单理解为每个空间最多有 15
  个同时运行的查询，实际还会按 Referer 和 URL path 的组合进行限制
- storageNode：需连接现有 guance-storage 时设置（比如 `172.16.7.158:8401,172.16.8.235:8401,172.16.19.134:8401`）
- scopeDB.disableArchiveQuery：是否禁用归档报告查询
- scopeDB.nodegroup.archiveQuery：默认 large-query，指定归档报告使用的 nodegroup

### 查询排队（queryQueue）

已被 ScopeDB 自身的排队和单语句资源限制取代，保持 `guance_select.queryQueue.enabled=false`，同时开启会排队两次。
确需开启时还要设置 `guance_select.queryQueue.acknowledgeSupersededByScopeDBQueue=true`。

排队数据的过期由 guance-select 内的 janitor 负责，Redis key 上没有 TTL，所以关闭排队后这些 key 不会自己消失。
只要 `guance_select.queryQueue.redisAddr` 仍然保留，chart 会在 install/upgrade 后运行一个清理 Job，删除
`{guancedb}:*` 和 `{guancedb:nodegroup}:*`（前缀取自 `guance_select.extraArgs` 的
`search.queryQueue.redisPrefix`，默认 `guancedb`）。该 Job 可重复执行，Redis 已下线时会跳过而不会让 helm 失败。
不需要时设置 `guance_select.queryQueue.cleanup.enabled=false`。

Redis 使用 TLS 时（`guance_select.extraArgs` 中的 `search.queryQueue.redisTLSInsecure: true`），Job 会自动带上
`redis-cli --tls --insecure`；如果禁用排队时一并删掉了该参数，可用 `guance_select.queryQueue.cleanup.tls=true` 单独指定。
此时清理镜像需要是带 TLS、连接超时和可调 SCAN 批次支持的 redis-cli（默认使用 8.6）。Job 跳过时会打印 Redis 的返回内容，
`kubectl logs` 可以区分「Redis 已下线」和「redis-cli 不支持 --tls」。

## 部署

### 1. 启用 Datakit 的 OTLP、Zipkin V2 采集器

### 2. 准备 Helm values 文件

```yaml
guance_select:
  # 海外集群需要指定时区，格式如：
  timezone: Asia/Shanghai
  # 使用 ScopeDB 时必填，「shared」用于多租户共享集群，「dedicated」用于少量租户专用集群
  tenancy: shared

guance_insert:
  persistentVolume:
    # 流式聚合需要低延迟磁盘，吞吐要求不高
    storageClass: ''
    fileQueue:
      # 默认模版名称为 guance-insert-file-queue；更换新盘时可通过修改 name 挂载新 PVC
      name: ''
      enabled: true
      # file queue 对延迟和吞吐的要求都比较高
      storageClass: ''
```

#### guance-insert 存储配置与预建卷绑定

`guance-insert` 为多副本架构（默认 3 副本，且不建议单副本运行），主数据卷（`/data`）与 `fileQueue` 卷（`/file-queue`）均通过 `volumeClaimTemplates` 由 Kubernetes 为每个副本分配专属的独立 PVC，严禁多副本挂载同一张静态卷（会导致块存储 Multi-Attach 失败卡死，或并发写队列造成数据损坏）。

若集群**不支持动态 StorageClass（无法动态创建卷）**，请按以下方式配置静态绑定：
1. 在 values 中将对应存储的 `storageClass` 显式设为 `"-"`（输出为空字符串 `storageClassName: ""`）；
2. 提前在命名空间下手动创建好各副本对应的 PVC，命名格式遵循 Kubernetes StatefulSet 严格规范：`<PVC模板名称>-<StatefulSet名称>-<序号>`。
   例如 release name 为 `guancedb` 时，StatefulSet 名称为 `guance-insert`：
   - 主卷：`guance-insert-volume-guance-insert-<ordinal>`（如 `guance-insert-volume-guance-insert-0`）
   - file queue 卷：`<fileQueue.name>-guance-insert-<ordinal>`（默认未改名时为 `guance-insert-file-queue-guance-insert-0`；若设置 `fileQueue.name: guance-insert-file-queue-v2`，则为 `guance-insert-file-queue-v2-guance-insert-0`）
StatefulSet 控制器在拉起 Pod 时会自动绑定同名已有 PVC，不会尝试动态创建。

若存量测试环境曾配置过单 PVC 且写入过待发送队列，切换为 `volumeClaimTemplates` 后旧卷数据不会自动继承。请在升级下线旧卷前，使用离线出清工具 `app/scripts/drain-filequeue` 挂载旧卷将其中的历史在途文件排空推至 ScopeDB，或通过临时 Pod 迁移至新 PVC 后再启动消费。

若升级时提示 `updates to statefulset spec for fields other than ... are forbidden`（StatefulSet 原生禁止就地增删 `volumeClaimTemplates`），执行孤儿删除后重新升级即可：
```shell
kubectl -n guancedb delete sts <release-name>-guance-insert --cascade=orphan
helm -n guancedb upgrade ...
```

`scopedb.nodegroups` 需要包含 `large-query` 或通过在 `guance_select.extraArgs` 添加
`scopeDB.disableArchiveQuery: true` 禁用归档报告查询

#### （不推荐）如果需要 guance-insert 使用内存做数据攒批

使用这种方式每次 guance-insert 重启都可能丢数据。

```yaml
guance_insert:
  extraVolumes:
    - name: cache-volume
      emptyDir:
        medium: Memory
        sizeLimit: 4Gi
  extraVolumeMounts:
    - name: cache-volume
      mountPath: /cache
  extraArgs:
    doris.cacheDataPath: /cache
```

### 3. 创建 Secret：

`guance_meta` 的 Secret 不会由 Helm chart 创建。启用 `guance_meta.enabled=true` 前，需要先在集群中创建对应 Secret。

```yaml
apiVersion: v1
kind: Secret
metadata:
  # guance_meta.enabled=true 时需要；如果未设置 guance_meta.secret.name，则使用 guance-meta 的 fullname
  name: guance-meta
stringData:
  metadataMySQLUsername: ""
  metadataMySQLPassword: ""
---
apiVersion: v1
kind: Secret
metadata:
  name: scopedb
stringData:
  # 密码需要 percent-encoding：https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING-URIS
  SERVER_META_SERVICE_URL: "postgres://scopedb:[password]@[host]:[port]/scopedb_meta"
  SERVER_DEFAULT_STORAGE_ACCESS_KEY_ID: ""
  SERVER_DEFAULT_STORAGE_SECRET_ACCESS_KEY: ""
```

### 4. 安装

```shell
helm -n guancedb install guancedb oci://pubrepo.jiagouyun.com/guancedb/guancedb --dependency-update -f values.yaml
```

仓库内提供两份可独立传给 Helm 的业务 values 文件。

- 日志业务使用 [`values-logs.yaml`](values-logs.yaml)。该 profile 部署 `guance-meta`、GuanceDB Insert、GuanceDB Select 和 ScopeDB。它关闭本地 `guance-storage`，并保留 ScopeDB 的节点组、S3 和时间索引配置。
- 指标业务使用 [`values-metrics.yaml`](values-metrics.yaml)。该 profile 关闭 ScopeDB，部署独立的 `guance-storage`，并通过 `guance_meta.externalURL` 连接日志业务的 `guance-meta`。日志业务建议使用 release 名 `guancedb`，这样指标 profile 中的默认元数据地址可以直接解析。

先部署日志业务，再部署指标业务。

```shell
helm upgrade --install guancedb ./charts/guancedb \
  --namespace guancedb --create-namespace \
  -f ./charts/guancedb/values-logs.yaml

helm upgrade --install guancedb-metrics ./charts/guancedb \
  --namespace guancedb --create-namespace \
  -f ./charts/guancedb/values-metrics.yaml
```

两份 profile 都保留了原始镜像仓库配置。部署前需要把占位的 MySQL、Kodo、OTLP、ScopeDB S3 和 StorageClass 参数替换成目标环境的实际值。

### 配置项速查

| 配置项 | 作用 | 常见修改场景 |
| --- | --- | --- |
| `global.storageClass` | 为没有单独指定 StorageClass 的 PVC 提供默认值 | 切换云盘、NFS 或本地盘 |
| `nodeSelector`、`tolerations` | 控制 Insert、Select、Storage 的默认调度位置 | 绑定专用节点池或容忍节点污点 |
| `image.tag` 和组件 `image.tag` | 选择 GuanceDB 镜像版本 | 使用镜像仓库、灰度版本或离线镜像 |
| `guance_meta.enabled` | 是否在当前 release 创建 guance-meta | 主业务 cluster 开启，从业务 cluster 关闭 |
| `guance_meta.cluster` | 隔离元数据参数、租户配置和流式聚合注册 | 同一个 guance-meta 服务多个业务 cluster |
| `guance_meta.externalURL` | 指向已经存在的 guance-meta Service | 从业务 cluster 复用主业务 meta |
| `streamAggr.enabled` | 开启 Insert 的自研流式聚合 | 日志聚合、指标注册和多 cluster 注册 |
| `timeIndex.enabled`、`timeIndex.path` | 控制时间索引是否写入 Insert 数据盘 | 兼容较旧 ScopeDB 查询或需要时间索引时 |
| `guance_insert.persistentVolume` | 配置 Insert 主数据盘和 fileQueue 盘 | 调整写入容量、吞吐和 PVC 绑定 |
| `guance_select.extraArgs.storageNode` | 指向现有 Storage 的 select 端口 | 关闭本 Chart Storage 或连接外部 Storage |
| `guance_storage.enabled` | 是否部署指标 Storage StatefulSet | 指标业务自建 Storage 时开启 |
| `scopedb.enabled` | 是否部署 ScopeDB 子 Chart | 日志业务使用 ScopeDB 时开启 |
| `scopedb.nodegroups` | 定义 ScopeDB 的查询、写入和后台作业节点 | 按节点池、资源和磁盘类型拆分负载 |
| `scopedb.s3` | 配置 ScopeDB 对象存储 | 使用 RustFS、S3、OSS 或其他 S3 兼容服务 |
| `imagePullSecrets` | 配置私有镜像仓库认证 | 中国区镜像仓库、离线仓库或私有 Registry |

### 模板阅读顺序

建议先阅读 `values-logs.yaml` 或 `values-metrics.yaml`，再按以下顺序查看模板。

1. `guance-meta-deployment.yaml` 说明元数据入口和 Secret 引用。
2. `guance-insert-statefulset.yaml` 说明写入参数、数据盘、流式聚合和 fileQueue。
3. `guance-select-deployment.yaml` 说明查询路由、Storage FQDN、ScopeDB 和 queryQueue。
4. `guance-storage-statefulset.yaml` 说明指标数据持久化和 Storage 节点发现。
5. `charts/scopedb/templates/workload.yaml` 说明每个 ScopeDB nodegroup 如何生成 workload。

模板文件顶部和关键条件分支已经增加说明性 Helm 注释。渲染结果不会包含这些注释。

### 5. 多集群共享 guance-meta

同一个 guance-meta 可以服务多个 GuanceDB 集群。主集群按上文启用 `guance_meta.enabled=true`；第二个及后续集群设置
`guance_meta.enabled=false`，并将 `guance_meta.externalURL` 指向主集群的 guance-meta Service URL，同时为每个集群显式设置不同的
`guance_meta.cluster`。同一个 cluster 的 guance-insert、guance-select 和 guance-storage 必须由同一个 `metaClientURL` 注入
`--meta.addr`；不要在同一 cluster 内混用不同的 meta 地址。

#### 示例：guancedb（日志）+ middleware（指标）分离部署

主集群 values（`-n guancedb`）：

```yaml
guance_meta:
  enabled: true
  cluster: guancedb
  mysql:
    addr: "mysql.example.com:3306"
    database: guance_meta
  kodo:
    endpoint: "http://kodo.example.com:9527"
  secret:
    name: guance-meta-secret

streamAggr:
  enabled: true          # 主集群 insert 是流式聚合执行者
```

从集群 values（`-n middleware`）：

```yaml
guance_meta:
  enabled: false
  externalURL: "http://guance-meta.guancedb.svc.cluster.local:8483"
  cluster: middleware    # 必须与主集群不同；只区分部署，不区分指标/日志
```

从集群三个组件都会被注入 `--meta.addr=<externalURL>` 与 `--meta.cluster=middleware`。语义：

- 注册入口唯一（主集群 meta）；注册目录全局一份，广播到所有启用了自研流式聚合（`--streamAggr.dataPath`）的 insert 执行。
- **从集群 insert 必须接入 meta**：即使不执行（VM 原生 streamaggr），也要通过 `externalURL` 上报，使该 cluster 为显式
  incapable 并被排除——否则落 unknown，其节点被保守纳入，注册永久 `preparing`。
- 从集群要执行用户注册（如指标流式聚合）：其 insert 需启用自研流式聚合（`streamAggr.enabled: true` + 持久化卷），
  成为 capable 执行者；未启用前注册到该数据集的查询不会被任何节点执行。
- 三套参数（启动快照/动态参数/租户配置）按 cluster 完全隔离。

详细语义见 `docs/Deployment StreamAggr Pinned Registration.md` 的「多集群共享部署」章节。

#### cluster 维度升级顺序（硬约束）

- **meta 先行**：先升级/部署带 cluster 维度的 guance-meta（三表迁移 + API 兼容回退），再滚动升级组件，最后升级 UI。
- **禁止组件先行**：带 `--meta.cluster` 的新组件连旧 meta 会把数据写入 `default` 集群，且 insert/storage 的启动参数快照与
  runtime 声明不会自动重写——升级 meta 后也不会自动归位。唯一受支持的跨版本组合是「旧组件 → 新 meta」。
- **单集群存量部署**：chart 默认 `guance_meta.cluster` 为空（生效值 `default`），与存量数据归属一致，升级零切换；
  不要在生产拆分为多集群前把 cluster 改成 namespace。
- **存量 default → 新 cluster 拆分**：多集群是新部署场景；若要把既有单集群拆开，需先显式迁移 `default` 集群下的参数数据到
  目标 cluster（当前不提供自动化），迁移完成前不要滚动组件。

## 升级

```shell
helm -n guancedb upgrade guancedb oci://pubrepo.jiagouyun.com/guancedb/guancedb \
  --dependency-update -f values.yaml \
  --set scopedb.deployedVersion=$(kubectl -n guancedb get svc/scopedb -o jsonpath="{.metadata.labels.app\.kubernetes\.io/version}")
```

如果报错「ScopeDB ^0.1.xxx requires offline meta upgrade」，执行
```shell
kubectl -n guancedb scale --replicas=0 deploy,sts -l app.kubernetes.io/name=scopedb
helm -n guancedb upgrade guancedb oci://pubrepo.jiagouyun.com/guancedb/guancedb \
  --dependency-update -f values.yaml \
  --set scopedb.metaUpgrade.offline=true
```
