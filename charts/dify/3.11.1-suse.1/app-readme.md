# Dify Enterprise 3.11.1

面向 SUSE Rancher Apps 的 Dify 企业版安装包。此版本在上游 `3.11.1` Chart 基础上增加了 Rancher 图形化配置表单、安装前参数校验、自动创建后端 PVC、TLS Secret 与镜像拉取 Secret 选择，以及中文参数说明。

默认配置采用已验证的单副本部署拓扑：

- Traefik Ingress 与 `*.dify.local` 示例域名
- 内置 PostgreSQL、Redis 和 Qdrant
- `local-path` StorageClass
- Dify Enterprise、Audit、RBAC、Collector、Plugin 与 Sandbox 组件

安装前请准备：

1. Dify Enterprise 许可及企业镜像访问权限。
2. 目标命名空间中的镜像拉取 Secret（企业镜像为私有镜像时）。
3. 可用的 StorageClass，或已有后端 PVC。
4. 控制台、应用、API、文件、企业管理和 Trigger 域名的 DNS/hosts 解析。
5. 五个独立随机密钥；表单中提供了生成命令。

> 默认内置数据库适用于验证、演示和小规模环境。生产环境建议使用外部高可用 PostgreSQL/Redis、可靠的对象存储或 RWX 存储，并根据并发量配置资源请求、限制和副本数。

