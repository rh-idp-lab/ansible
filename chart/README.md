# IDP Lab — Ansible Deployment

Deploy the Red Hat Internal Developer Platform lab using Ansible playbooks executed via a Kubernetes Job. Ansible handles tasks beyond Helm templating: waiting for operators, configuring Keycloak, seeding GitLab repositories, and calling external APIs.

## Quick Start

1. Copy this folder to your own repository
2. Edit `values.yaml` — update the repository URL and playbook settings
3. Edit `playbooks/idp_lab_from0.yml` — customize the deployment tasks
4. Push to your Git repository
5. Order the **Field Content CI** from RHDP with your repository URL

## Architecture

```
ansible/
├── chart/
│   ├── Chart.yaml
│   ├── values.yaml           # Job configuration, collections, extraVars
│   ├── README.md
│   └── templates/            # Job, RBAC, ConfigMap, Namespace templates
└── playbooks/
    ├── idp_lab_from0.yml     # Main playbook
    └── roles/
        └── idp_lab_from0/    # Main role with all deployment logic
            ├── tasks/        # Modular task files per component
            └── defaults/     # Default variable values
```

ArgoCD deploys this as a Helm chart. The chart creates a Kubernetes Job that clones the playbooks and runs Ansible.

## What Gets Deployed

| Component | Description |
|-----------|-------------|
| OpenShift GitOps | Cluster-level ArgoCD instance |
| GitLab | Source control and CI/CD platform |
| NooBaa | S3-compatible object storage |
| HashiCorp Vault | Secrets management |
| Red Hat Developer Hub | Internal developer portal (Backstage) |
| Keycloak (SSO) | Identity provider, users and groups |
| Showroom | Lab guide with terminal |

## Configuration

All settings are in `values.yaml`. Key sections:

```yaml
ansible:
  repository:
    url: "https://github.com/rh-idp-lab/ansible"
    branch: "main"
  playbook: "idp_lab_from0.yml"
  extraVars:
    gitlab_enabled: true
    noobaa_enabled: true
    vault_enabled: true
    rhdh_enabled: true
```

See comments in [values.yaml](values.yaml) for detailed documentation of all available variables.

## Testing Locally

```bash
cd playbooks
ansible-galaxy collection install -r requirements.yml
ansible-playbook idp_lab_from0.yml \
  -e "cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')"
```

## Troubleshooting

```bash
# Check job status
oc get jobs -n idp-lab-deployer

# Stream job logs
oc logs -n idp-lab-deployer job/idp-lab -f

# View events
oc get events -n idp-lab-deployer --sort-by='.lastTimestamp'
```

To re-run the deployment:

```bash
oc delete job -n idp-lab-deployer idp-lab
argocd app sync idp-lab
```

## Support

- GitHub Issues: https://github.com/rh-idp-lab/ansible/issues
- Based on: https://github.com/rhpds/field-sourced-content-template
