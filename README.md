# IDP Lab — Ansible

This repository contains the Ansible automation to bootstrap the foundation of the **IDP Lab** workshop on OpenShift.

The `idp_lab_from0` role installs two components in order:

1. **OpenShift GitOps** (Argo CD) — installs the operator, grants cluster-admin to the GitOps service account, and tunes the `openshift-gitops` ArgoCD instance resources and RBAC.
2. **GitLab** — creates an Argo CD `Application` that deploys GitLab via the Helm chart, waits for it to be ready, then seeds users, groups, repositories, and OAuth applications.

All subsequent platform components (Vault, Pipelines, Keycloak, RHDH, etc.) are expected to be deployed as Argo CD `Application` resources that point at the Helm chart repository, which GitOps will reconcile automatically.

## Prerequisites

- An OpenShift 4.14+ cluster
- `oc` CLI logged in as a `cluster-admin` user
- Ansible 2.14+ with the `kubernetes.core` collection installed:

```bash
ansible-galaxy collection install kubernetes.core
```

- A valid `KUBECONFIG` pointing at your cluster (or `~/.kube/config`)

## Repository layout

```
ansible/
├── playbooks/
│   └── idp_lab_from0.yml          # Entry-point playbook
└── roles/
    ├── install_operator/           # Generic OLM operator installer (dependency)
    └── idp_lab_from0/
        ├── defaults/main.yml       # All tuneable variables
        ├── files/
        │   └── openshift_gitops_clusterrolebinding.yaml
        ├── tasks/
        │   ├── main.yml            # pre → workload → post
        │   ├── pre_workload.yml    # Discover cluster domain, generate common_password
        │   ├── workload.yml        # Calls openshift_gitops + gitlab
        │   ├── post_workload.yml
        │   ├── openshift_gitops.yml
        │   ├── gitlab.yml
        │   └── create_oauth_app.yml
        └── templates/
            ├── openshift-gitops/openshift-gitops.yaml.j2
            └── gitlab/gitlab-application.yml.j2
```

## Quick start

### 1. Run with all defaults

The playbook targets `localhost` and communicates with the cluster through the `kubernetes.core` modules (no SSH required):

```bash
ansible-playbook playbooks/idp_lab_from0.yml
```

This will:
- Detect the cluster ingress domain automatically
- Generate a random `common_password` (stored in `/tmp/passwordfile`)
- Install the OpenShift GitOps operator and tune the ArgoCD instance
- Deploy GitLab via Argo CD with three default lab users (`user1`, `user2`, `user3`)
- Create a GitLab OAuth application for Dev Spaces

### 2. Override variables with `-e`

```bash
ansible-playbook playbooks/idp_lab_from0.yml \
  -e common_password=MyLabPass42 \
  -e idp_lab_from0_gitlab_user1=alice \
  -e idp_lab_from0_gitlab_user2=bob \
  -e idp_lab_from0_gitlab_user3=charlie
```

### 3. Override variables with a vars file

Create a file, e.g. `vars/my-cluster.yml`:

```yaml
# vars/my-cluster.yml
common_password: MyLabPass42

idp_lab_from0_gitlab_user1: alice
idp_lab_from0_gitlab_user2: bob
idp_lab_from0_gitlab_user3: charlie

# Point GitLab at a different Helm branch
idp_lab_from0_gitlab_gitops_repo_tag: my-branch

# Tune ArgoCD controller if cluster is small
idp_lab_from0_openshift_gitops_controller_requests_cpu: 250m
idp_lab_from0_openshift_gitops_controller_requests_memory: 512Mi
```

Then run:

```bash
ansible-playbook playbooks/idp_lab_from0.yml -e @vars/my-cluster.yml
```

### 4. Run only specific components with tags

Each task block has a tag so you can re-run individual components without repeating the full play:

```bash
# Only (re-)install OpenShift GitOps
ansible-playbook playbooks/idp_lab_from0.yml --tags install_gitops

# Only (re-)deploy GitLab
ansible-playbook playbooks/idp_lab_from0.yml --tags install_gitlab

# Only (re-)deploy Vault
ansible-playbook playbooks/idp_lab_from0.yml --tags install_vault
```

## Key variables

### Common

| Variable | Default | Description |
|---|---|---|
| `common_password` | _auto-generated_ | Shared password for all lab users and services. Generated once into `/tmp/passwordfile`. Override to set a fixed value. |
| `silent` | `false` | Set to `true` to suppress informational debug output. |

### OpenShift GitOps

| Variable | Default | Description |
|---|---|---|
| `idp_lab_from0_openshift_gitops_operator_channel` | `latest` | OLM subscription channel. |
| `idp_lab_from0_openshift_gitops_operator_catalog` | `redhat-operators` | CatalogSource to install from. |
| `idp_lab_from0_openshift_gitops_setup_cluster_admin` | `true` | Grant `cluster-admin` to the ArgoCD application controller SA. |
| `idp_lab_from0_openshift_gitops_update_resources` | `true` | Patch the `openshift-gitops` ArgoCD CR with tuned resource requests/limits. |
| `idp_lab_from0_openshift_gitops_controller_remove_memory_limits` | `false` | Remove memory limits from the ArgoCD application controller (useful on small clusters). |
| `idp_lab_from0_rhdh_gitops_namespace` | `rhdh-gitops` | Namespace added to `ARGOCD_CLUSTER_CONFIG_NAMESPACES` so a future dedicated ArgoCD instance can manage cluster-scoped resources. |
| `idp_lab_from0_openshift_gitops_rbac_policy` | see defaults | ArgoCD RBAC policy applied to the `openshift-gitops` instance. |

### GitLab

| Variable | Default | Description |
|---|---|---|
| `idp_lab_from0_gitlab_namespace` | `gitlab` | Namespace where GitLab is deployed. |
| `idp_lab_from0_gitlab_gitops_repo` | `https://github.com/rh-opencodequest-origins/helm.git` | Helm chart repository URL. |
| `idp_lab_from0_gitlab_gitops_repo_tag` | `opencodequest` | Git branch/tag of the Helm chart repository. |
| `idp_lab_from0_gitlab_gitops_repo_path` | `gitlab` | Path inside the Helm repository for the GitLab chart. |
| `idp_lab_from0_gitlab_config_root_password` | `{{ common_password }}` | GitLab root user password. |
| `idp_lab_from0_gitlab_users_password` | `{{ common_password }}` | Password set for all seeded lab users. |
| `idp_lab_from0_gitlab_user1` | `user1` | First lab user created in GitLab. |
| `idp_lab_from0_gitlab_user2` | `user2` | Second lab user created in GitLab. |
| `idp_lab_from0_gitlab_user3` | `user3` | Third lab user created in GitLab. |
| `idp_lab_from0_gitlab_oauth_apps` | Dev Spaces entry | List of GitLab OAuth applications to create. Each entry needs `name`, `redirect_uri`, and `scopes`. |

### Vault

| Variable | Default | Description |
|---|---|---|
| `idp_lab_from0_vault_application_name` | `vault` | Name of the Argo CD `Application` resource. |
| `idp_lab_from0_vault_application_namespace` | `openshift-gitops` | Namespace where the Argo CD Application is created. |
| `idp_lab_from0_vault_namespace` | `vault` | Target namespace for the Vault deployment. |
| `idp_lab_from0_vault_gitops_repo` | `https://github.com/rh-opencodequest-origins/helm.git` | Helm chart repository URL. |
| `idp_lab_from0_vault_gitops_repo_tag` | `opencodequest` | Git branch/tag of the Helm chart repository. |
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

Once the playbook completes, open the ArgoCD UI and wait for the `gitlab` application to reach **Healthy** status. GitLab is accessible at:

```
https://gitlab-gitlab.<cluster-ingress-domain>
```

Log in as `root` with `common_password`.

The next step is to deploy the remaining IDP components (Vault, Pipelines, External Secrets, Keycloak, Dev Spaces, RHDH) as Argo CD `Application` resources — either manually or by extending `workload.yml` with additional task files following the same pattern.
