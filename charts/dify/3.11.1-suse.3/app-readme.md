# Dify Enterprise with SUSE Rancher Prime

面向 SUSE Rancher Apps 的 Dify 企业版安装包。此版本在上游 `3.11.1` Chart 基础上增加了 Rancher 图形化配置表单、安装前参数校验、自动创建后端 PVC、TLS Secret 与镜像拉取 Secret 选择，以及中文参数说明。

默认配置采用已验证的单副本部署拓扑：

- Traefik Ingress 与 `*.dify.test` 预设域名
- 内置 PostgreSQL、Redis 和 Qdrant
- `local-path` StorageClass
- Dify Enterprise、Audit、RBAC、Collector、Plugin 与 Sandbox 组件

此 Update 3 适合在已经存在 `dify` Release 的同一 K3s 集群中安装第二套测试环境：默认复用现有 Plugin CRD，不重新接管集群级 CRD，并自动根据 Helm Release 名称配置 Web 服务端访问 API 的内部地址。网络、存储、镜像及单副本参数均已预填。

安全密钥默认采用安装时生成模式：每个 Helm Release 会创建并持久复用独立的 Dify、Enterprise、PostgreSQL、Redis 和 Qdrant 凭据。公共 Chart 中没有固定共享密码。需要接入外部密钥管理流程时，可关闭“自动生成安全密钥”，再在表单中手工填写。

安装前请准备：

1. Dify Enterprise 许可及企业镜像访问权限。
2. 目标命名空间中的镜像拉取 Secret（企业镜像为私有镜像时）。
3. 可用的 StorageClass，或已有后端 PVC。
4. 控制台、应用、API、文件、企业管理和 Trigger 域名的 DNS/hosts 解析。
5. 保持“自动生成安全密钥”开启，或关闭后准备自己的独立随机密钥。

> 默认内置数据库适用于验证、演示和小规模环境。生产环境建议使用外部高可用 PostgreSQL/Redis、可靠的对象存储或 RWX 存储，并根据并发量配置资源请求、限制和副本数。
