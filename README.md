# Dify Enterprise with SUSE Rancher Prime

This public repository publishes Rancher-enhanced Dify Enterprise 3.11.1 Helm
charts. The current recommended version is **`3.11.1-suse.3`**.

## Add the catalog to Rancher Prime

In the target cluster, open:

`Apps` → `Repositories` → `Create`

Select **Git Repository** (not Helm Repository) and use:

- Name: `dify-ee-suse-rancher`
- Git Repo URL: `https://github.com/DuDuDuMaxVerstappen30/dify-suse-helm.git`
- Branch: `main`
- Authentication: `None`

This repository intentionally has no root `index.yaml`. Rancher must scan the
Git chart directories so it can load `app-readme.md`, `questions.yaml`, and
`values.yaml` together.

After the repository is **Active**, click **Refresh**, open `Apps` → `Charts`,
and choose **Dify Enterprise with SUSE Rancher Prime** version
`3.11.1-suse.3`.

## Current catalog layout

```text
charts/
└── dify/
    ├── 3.11.1-suse.2/
    └── 3.11.1-suse.3/
        ├── Chart.yaml
        ├── app-readme.md
        ├── questions.yaml
        ├── values.yaml
        ├── charts/
        └── templates/
```

The packaged chart can also be downloaded directly:

- [`dify-3.11.1-suse.3.tgz`](./dify-3.11.1-suse.3.tgz)

## Update 3 highlights

- 199 Rancher form fields grouped into 11 bilingual configuration sections.
- Defaults prepared for a second `dify-test` installation using
  `*.dify.test`, Traefik, `local-path`, PostgreSQL, Redis, and Qdrant.
- Plugin CRD installation disabled by default so an existing `dify` release
  can remain the CRD owner.
- `SERVER_CONSOLE_API_URL` automatically follows the Helm release name.
- Application, Enterprise, PostgreSQL, Redis, and Qdrant credentials are
  generated independently on the first install and reused on upgrades.
- Operators can disable automatic credential generation and enter their own
  values in the Rancher form.

## Security

The public chart contains no fixed shared passwords. With automatic credential
generation enabled, credentials are stored in release-specific Kubernetes
Secrets. Back them up, restrict Secret read access, and do not rotate
encryption keys during an upgrade.

Dify Enterprise licensing and private image-registry access are still required
where applicable.
