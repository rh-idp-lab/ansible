# IDP Lab — Ansible

This repository contains the Ansible automation to bootstrap the foundation of the **IDP Lab** workshop on OpenShift.

The `idp_lab_from0` role installs the following components in order:

1. **OpenShift GitOps** (Argo CD) — installs the operator, grants cluster-admin to the GitOps service account, and tunes the `openshift-gitops` ArgoCD instance resources and RBAC.
2. **GitLab** — creates an Argo CD `Application` that deploys GitLab via the Helm chart, waits for it to be ready, then seeds users, groups, repositories, and OAuth applications.
3. **NooBaa** — creates an Argo CD `Application` that deploys NooBaa (object storage) via the Helm chart.
4. **Vault** — creates an Argo CD `Application` that deploys HashiCorp Vault via the Helm chart and configures Vault auth for the cluster.

All subsequent platform components (Pipelines, Keycloak, RHDH, etc.) are expected to be deployed as Argo CD `Application` resources that point at the Helm chart repository.

## Prerequisites

- An OpenShift 4.14+ cluster
- `oc` CLI logged in as a `cluster-admin` user
- `make` installed
- Ansible 2.14+ with the `kubernetes.core` collection:

```bash
ansible-galaxy collection install kubernetes.core
```

- A valid `KUBECONFIG` pointing at your cluster (or `~/.kube/config`)

## Repository layout

```
ansible/
├── Makefile                            # All deploy and clean targets
├── clean.sh                            # Teardown script (called by make clean)
├── ansible.cfg                         # Roles path configuration
├── playbooks/
│   └── idp_lab_from0.yml               # Entry-point playbook
└── roles/
    ├── install_operator/               # Generic OLM operator installer (dependency)
    └── idp_lab_from0/
        ├── defaults/main.yml           # All tuneable variables
        ├── files/
        │   └── openshift_gitops_clusterrolebinding.yaml
        ├── tasks/
        │   ├── main.yml                # pre → workload → post
        │   ├── pre_workload.yml        # Discover cluster domain, generate common_password
        │   ├── workload.yml            # Calls gitops, gitlab, noobaa, vault
        │   ├── post_workload.yml
        │   ├── openshift_gitops.yml
        │   ├── gitlab.yml
        │   ├── noobaa.yml
        │   ├── vault.yml
        │   └── create_oauth_app.yml
        └── templates/
            ├── openshift-gitops/openshift-gitops.yaml.j2
            ├── gitlab/gitlab-application.yml.j2
            └── vault/vault-application.yml.j2
```

## Quick start

Run all commands from the **repo root** (`ansible/`) so that `ansible.cfg` is picked up automatically.

### Deploy everything

```bash
make deploy
```

This runs the full role in order: GitOps → GitLab → NooBaa → Vault.

### Deploy with a fixed password

Create a `.env` file (never committed) to pin the shared password:

```bash
# .env
COMMON_PASSWORD=MyLabPass42
```

Then:

```bash
make deploy
```

The Makefile automatically loads `.env` and passes `COMMON_PASSWORD` to the playbook.

### Deploy individual components

```bash
make gitops    # Install OpenShift GitOps operator only
make gitlab    # Deploy GitLab only
make noobaa    # Deploy NooBaa only
make vault     # Deploy Vault only
```

### Pass extra variables on the fly

Use `EXTRA_VARS` to override any role variable without editing files:

```bash
make deploy EXTRA_VARS="-e idp_lab_from0_gitlab_user1=alice -e idp_lab_from0_gitlab_user2=bob"
```

### Clean up

Removes all deployed resources (ArgoCD applications, namespaces, OAuth secrets, Dev Spaces workspaces):

```bash
make clean
```

`make clean` calls `clean.sh` which deletes:
- All ArgoCD Applications in `rhdh-gitops` and `openshift-gitops` (gitlab, noobaa, vault, rhdh-gitops)
- Namespaces: `gitlab`, `openshift-storage`, `vault`, `rhdh-gitops`
- Dev Spaces user workspaces
- The GitLab OAuth secret in `openshift-devspaces`

### See all available targets

```bash
make help
```

## Key variables

### Common

| Variable | Default | Description |
|---|---|---|
| `common_password` | _auto-generated_ | Shared password for all lab users and services. Generated once into `/tmp/passwordfile`. Override via `.env` or `EXTRA_VARS`. |
| `silent` | `false` | Set to `true` to suppress informational debug output. |

### OpenShift GitOps

| Variable | Default | Description |
|---|---|---|
| `idp_lab_from0_openshift_gitops_operator_channel` | `latest` | OLM subscription channel. |
| `idp_lab_from0_openshift_gitops_operator_catalog` | `redhat-operators` | CatalogSource to install from. |
| `idp_lab_from0_openshift_gitops_setup_cluster_admin` | `true` | Grant `cluster-admin` to the ArgoCD application controller SA. |
| `idp_lab_from0_openshift_gitops_update_resources` | `true` | Patch the `openshift-gitops` ArgoCD CR with tuned resource requests/limits. |
| `idp_lab_from0_openshift_gitops_controller_remove_memory_limits` | `false` | Remove memory limits from the ArgoCD application controller (useful on small clusters). |
| `idp_lab_from0_rhdh_gitops_namespace` | `rhdh-gitops` | Namespace added to `ARGOCD_CLUSTER_CONFIG_NAMESPACES` for the dedicated RHDH ArgoCD instance. |

### GitLab

| Variable | Default | Description |
|---|---|---|
| `idp_lab_from0_gitlab_namespace` | `gitlab` | Namespace where GitLab is deployed. |
| `idp_lab_from0_gitlab_gitops_repo` | `https://github.com/rh-idp-lab/helm.git` | Helm chart repository URL. |
| `idp_lab_from0_gitlab_gitops_repo_tag` | `main` | Git branch/tag of the Helm chart repository. |
| `idp_lab_from0_gitlab_gitops_repo_path` | `gitlab` | Path inside the Helm repository for the GitLab chart. |
| `idp_lab_from0_gitlab_config_root_password` | `{{ common_password }}` | GitLab root user password. |
| `idp_lab_from0_gitlab_users_password` | `{{ common_password }}` | Password set for all seeded lab users. |
| `idp_lab_from0_gitlab_user1` | `user1` | First lab user created in GitLab. |
| `idp_lab_from0_gitlab_user2` | `user2` | Second lab user created in GitLab. |
| `idp_lab_from0_gitlab_user3` | `user3` | Third lab user created in GitLab. |
| `idp_lab_from0_gitlab_oauth_apps` | Dev Spaces entry | List of GitLab OAuth applications to create. |

### NooBaa

| Variable | Default | Description |
|---|---|---|
| `idp_lab_from0_noobaa_namespace` | `openshift-storage` | Target namespace for the NooBaa deployment. |
| `idp_lab_from0_noobaa_gitops_repo` | `https://github.com/rh-idp-lab/helm.git` | Helm chart repository URL. |
| `idp_lab_from0_noobaa_gitops_repo_tag` | `main` | Git branch/tag of the Helm chart repository. |
| `idp_lab_from0_noobaa_gitops_repo_path` | `noobaa` | Path inside the Helm repository for the NooBaa chart. |

### Vault

| Variable | Default | Description |
|---|---|---|
| `idp_lab_from0_vault_application_name` | `vault` | Name of the Argo CD `Application` resource. |
| `idp_lab_from0_vault_application_namespace` | `openshift-gitops` | Namespace where the Argo CD Application is created. |
| `idp_lab_from0_vault_namespace` | `vault` | Target namespace for the Vault deployment. |
| `idp_lab_from0_vault_gitops_repo` | `https://github.com/rh-idp-lab/helm.git` | Helm chart repository URL. |
| `idp_lab_from0_vault_gitops_repo_tag` | `main` | Git branch/tag of the Helm chart repository. |
| `idp_lab_from0_vault_gitops_repo_path` | `hashicorp-vault` | Path inside the Helm repository for the Vault chart. |
| `idp_lab_from0_vault_name` | `vault` | Value passed as `nameOverride` to the Helm chart. |
| `idp_lab_from0_vault_auth_namespace` | `default` | Kubernetes namespace Vault uses for its auth backend. |

## What is deployed in GitLab

The Helm chart seeds GitLab with the following static groups and repositories:

| Group | Repositories mirrored from GitHub |
|---|---|
| `global` | `global-techdocs` |
| `rhdh` | `developer-hub-config`, `import-existing-app-template`, `import-existing-api-template`, `rhdh-entities`, `template-developer-self-service` |
| `devteam` | _(no repos, users only)_ |

Users `user1`, `user2`, `user3` (configurable) are added to all groups.

## After deployment

Once `make deploy` completes, open the ArgoCD UI and wait for all applications to reach **Healthy** status. GitLab is accessible at:

```
https://gitlab-gitlab.<cluster-ingress-domain>
```

Log in as `root` with `common_password`.

The next step is to deploy the remaining IDP components (Pipelines, External Secrets, Keycloak, Dev Spaces, RHDH) as Argo CD `Application` resources — either manually via the ArgoCD UI or by extending `workload.yml` with additional task files following the same pattern.
