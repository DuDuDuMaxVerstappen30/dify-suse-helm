# Dify Enterprise Helm Chart for SUSE Rancher

This public repository publishes a Rancher-enhanced Dify Enterprise 3.11.1 chart.

## Recommended: Rancher Git Repository

In the target cluster, open:

`Apps` → `Repositories` → `Create`

Select **Git Repository** and use:

- Name: `dify-ee-suse`
- Git Repo URL: `https://github.com/DuDuDuMaxVerstappen30/dify-suse-helm.git`
- Branch: `main`
- Authentication: `None`

The Rancher catalog layout is:

```text
charts/
└── dify/
    └── 3.11.1-suse/
        ├── Chart.yaml
        ├── app-readme.md
        ├── questions.yaml
        ├── values.yaml
        ├── charts/
        └── templates/
```

After the repository is Active, open `Apps` → `Charts`, select the
`dify-ee-suse` repository, and install **Dify Enterprise 3.11.1**.

## Rancher UI capabilities

- Guided bilingual installation form
- 197 configuration questions
- Grouped fields for ingress, security, databases, Redis, vector database,
  persistence, sizing, images, optional features, and mail
- Dropdowns, booleans, password fields, storage class selection, conditional
  fields, and validation
- Detailed chart and parameter documentation

## Security

Required credentials are intentionally not included. Provide passwords,
licenses, registry credentials, and production values through Rancher at
installation time. Do not commit secrets to this public repository.

This package is intended for authorized Dify Enterprise deployments. Users
remain responsible for Dify licensing and image-registry access.
