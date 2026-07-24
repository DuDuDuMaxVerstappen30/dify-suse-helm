# Dify Enterprise with SUSE Rancher Prime

Chart 版本：`3.11.1-suse.3`  
Dify Enterprise 应用版本：`3.11.1`

本 Chart 保留上游 Dify Enterprise 3.11.1 的模板和依赖，并增加 Rancher `questions.yaml` 图形化表单。导入 Rancher 后，用户可以通过分组页面配置关键参数，无需直接编辑完整的 `values.yaml`。

## 默认部署拓扑

默认值基于已验证的 Rancher/K3s 部署配置：

| 类型 | 默认选择 |
| --- | --- |
| Ingress | Traefik，HTTP，`*.dify.test` 预设域名 |
| 数据库 | 内置 PostgreSQL，单实例 |
| 缓存与队列 | 内置 Redis |
| 向量数据库 | 内置 Qdrant，1 个副本 |
| 文件存储 | 自动创建 `ReadWriteOnce` PVC，StorageClass 为 `local-path` |
| Dify 组件 | API、Web、Worker、Gateway、Enterprise、Audit、RBAC、Collector、Plugin、Sandbox |
| 遥测 | Dify Enterprise OTEL 开启，采样率 0.2 |

这些默认值适合功能验证和小规模环境。生产部署应根据可用性、数据规模和并发量调整。

## Rancher UI 配置分组

| 分组 | 用途 |
| --- | --- |
| 基础配置 | 许可模式、镜像拉取 Secret、数据库迁移、Marketplace |
| 网络与域名 | IngressClass、Traefik EntryPoint、TLS Secret、各服务域名和 CORS |
| 安全密钥 | 默认自动生成并复用 Dify、Enterprise、数据库、Redis 和 Qdrant 所需的独立随机密钥；也可切换为手工填写 |
| 数据库 | 内置 PostgreSQL 或外部 PostgreSQL/MySQL/TiDB |
| Redis | 内置 Redis 或外部 standalone/Sentinel Redis |
| 向量数据库 | 内置 Qdrant或外部 Qdrant、Weaviate、Milvus、pgvector、OpenSearch、Elasticsearch |
| 文件存储 | PVC、S3、Azure Blob、阿里云 OSS、GCS、腾讯云 COS、华为云 OBS、火山引擎 TOS |
| 组件规模 | 核心组件副本数和进程并发数 |
| 容器镜像 | Dify Enterprise 各组件的镜像仓库和 Tag |
| 功能与可观测性 | OTEL、多人协作、Unstructured、OpenAPI、Prometheus |
| 邮件 | SMTP 或 Resend |

未放入表单的高级配置仍可在 Rancher 的 **Edit YAML** 页面修改，包括资源 requests/limits、affinity、tolerations、nodeSelector、自定义 Ingress annotations、额外 Worker 队列和完整的外部向量数据库参数。

## 安装前准备

### 1. 安全密钥

默认保持 **自动生成安全密钥 / Auto-generate Secrets** 开启即可。首次安装时，Chart 会为当前 Helm Release 生成独立随机值，写入 Release 专属的 Kubernetes Secrets；升级时通过 `lookup` 复用原值，不会因普通升级自动轮换。

Chart 不包含任何发布在公共仓库中的固定密码。安装成功后请备份以下 Secrets，并限制读取权限：

```bash
kubectl -n <namespace> get secret \
  <release>-dify-runtime-credentials \
  <release>-dify-postgresql-credentials \
  <release>-dify-redis-credentials \
  <release>-dify-qdrant-credentials
```

如需使用组织已有的密钥管理流程，可在 Rancher 中关闭自动生成，然后分别填写下列值：

```bash
openssl rand -base64 42   # global.appSecretKey
openssl rand -base64 42   # global.innerApiKey
openssl rand -base64 42   # enterprise.appSecretKey
openssl rand -base64 24   # enterprise.adminAPIsSecretKeySalt
openssl rand -base64 32   # enterprise.passwordEncryptionKey
```

内置 PostgreSQL、Redis 和 Qdrant 也必须填写独立强密码/API Key。敏感值会写入 Helm release 和 Kubernetes Secret；请限制相关 RBAC 权限，并使用集群的 Secret 加密能力。已有数据后不要随意更换 `enterprise.passwordEncryptionKey` 或应用加密密钥。

### 2. 准备镜像拉取 Secret

如果 Dify Enterprise 镜像需要认证，请先在安装目标命名空间创建 `docker-registry` Secret，然后在 Rancher 表单的“镜像拉取 Secret”下拉框中选择它。

### 3. 准备域名

默认示例域名如下：

| 功能 | 默认域名 |
| --- | --- |
| Console Web/API | `console.dify.test` |
| WebApp Web/API | `app.dify.test` |
| Service API | `api.dify.test` |
| 文件上传与预览 | `upload.dify.test` |
| Enterprise 管理 | `enterprise.dify.test` |
| Trigger | `trigger.dify.test` |

请将所有域名解析到 Ingress Controller 的入口地址。若使用 HTTPS，请开启 `global.useTLS`，选择 TLS Secret，并将 Traefik EntryPoint 设置为 `websecure`。

### 4. 选择存储

当 `persistence.type=local` 且未选择已有 PVC 时，本 Chart 会自动创建 `<release>-backend-pvc`。该 PVC 被 API、Worker、Worker Beat 和 Plugin Daemon 等组件共同挂载。

- 单节点验证环境可使用 `ReadWriteOnce` 和 `local-path`。
- 多节点或多副本生产环境建议使用支持 `ReadWriteMany` 的存储。
- 也可以改用 S3 或兼容对象存储，避免多个 Pod 共享文件卷。

PostgreSQL、Redis 和 Qdrant 各自使用独立 PVC，并可在表单中选择 StorageClass 与容量。

## 数据服务模式

Chart 会在渲染阶段校验以下互斥关系：

- `postgresql.enabled` 与 `externalDatabase.enabled` 必须且只能开启一个。
- `redis.enabled` 与 `externalRedis.enabled` 必须且只能开启一个。
- 内置 Qdrant/Weaviate 与 `vectorDB.useExternal` 不能同时启用。

配置错误会在安装前直接返回清晰错误，避免产生部分运行的 Dify 环境。

## 生产环境建议

- 使用高可用外部数据库和 Redis Sentinel/托管 Redis。
- 使用对象存储或可靠的 RWX 存储承载 Dify 文件。
- 为 API、Worker、Enterprise、Gateway、Plugin 与 Sandbox 配置 requests/limits。
- 根据并发量调整 API、Worker、Sandbox 副本及进程数；不要只增加进程而忽略数据库连接池。
- 使用 HTTPS、可信 CA、强随机密钥和最小权限的镜像拉取 Secret。
- 对 PostgreSQL、Redis、Qdrant 和文件存储建立备份、恢复与容量监控。
- 生产变更前先在同版本测试环境运行 `helm template` 和升级演练。

## Helm CLI 示例

Rancher UI 是推荐入口。使用 Helm CLI 时，先准备自己的 values 文件：

```bash
helm upgrade --install dify-test ./dify-3.11.1-suse.3.tgz \
  --namespace dify-test \
  --create-namespace \
  -f values-production.yaml
```

默认自动生成密钥，因此全新安装无需在 values 文件中写入八个敏感字段。关闭自动生成后，Chart 的必填校验同样适用于 Helm CLI。

## 来源与支持边界

应用与原始 Chart 来源：

- <https://github.com/langgenius/dify>
- <https://github.com/langgenius/dify-helm>

`3.11.1-suse.3` 表示针对 SUSE Rancher UI 和同集群第二套 Dify 安装的适配版本，不改变 Dify Enterprise 应用版本。此版本会根据 Helm Release 名称自动生成 Web 服务端访问 API 的 `SERVER_CONSOLE_API_URL`，并默认生成、保存和复用 Release 专属安全凭据，无需把固定密钥发布到公共仓库。Dify Enterprise 许可、镜像和应用支持仍应遵循 Dify 的授权与支持条款。
