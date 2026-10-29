# Infrastructure as Code — Terraform and Ansible

Reality is whatever the code says it is; when they differ, the code is fixed or the resource is
imported, never the console. Every name and number below is invented.

## Terraform

### Remote state with locking

```hcl
terraform {
  required_version = "~> 1.10.0"
  backend "s3" {
    bucket         = "example-tfstate-prod"
    key            = "ledger/platform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "example-tfstate-lock"          # the lock; two applies cannot overlap
    encrypt        = true
  }
}
```

GitLab's and Terraform Cloud's HTTP backends lock as well. State holds every secret the providers
ever returned: encrypted at rest, access logged, never in git, never in an artifact with a long
retention. `terraform state pull` is a privileged operation.

### Provider and module pinning

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.80.0" }   # patch-level float only
  }
}
module "ledger_db" {
  source  = "git::https://git.example.test/platform/tf-modules.git//rds-postgres?ref=v2.3.1"
  # or registry: source = "example/rds-postgres/aws", version = "2.3.1"
}
```

Commit `.terraform.lock.hcl`; it pins the provider checksums per platform. Upgrading a provider is
its own merge request with its own plan.

### Modules

Small, composable, one concern each (`vpc`, `rds-postgres`, `eks-nodegroup`): inputs validated,
outputs explicit, no provider blocks inside (the root passes them in). A module that takes 60
variables is three modules. Root modules (the thing you `apply`) per system and environment.

### Variable validation

```hcl
variable "environment" {
  type = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}
variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
  validation {
    condition     = can(regex("^db\\.", var.db_instance_class))
    error_message = "db_instance_class must be an RDS instance class."
  }
}
```

`sensitive = true` on secret inputs and outputs keeps them out of the plan text (not out of state).

### Plan as a CI artifact, reviewed before apply

```yaml
# GitLab
plan:
  stage: plan
  rules: [{ if: $CI_PIPELINE_SOURCE == "merge_request_event" }]
  script:
    - terraform init -input=false
    - terraform fmt -check -recursive && terraform validate
    - terraform plan -input=false -lock-timeout=5m -out=tf.plan
    - terraform show -no-color tf.plan > plan.txt     # the reviewer reads this in the MR
  artifacts: { paths: [tf.plan, plan.txt], expire_in: 1 day }
apply:
  stage: apply
  rules: [{ if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH, when: manual }]
  needs: [plan]
  environment: { name: production }
  script: [terraform apply -input=false tf.plan]     # applies exactly what was reviewed
```

GitHub: same two jobs, `plan` on `pull_request` posting `plan.txt` as a PR comment, `apply` on
`push` to `main` gated by the `production` environment's required reviewers. `-auto-approve` is
acceptable only when the argument is a saved plan file from a reviewed run. A plan older than the
state it was made against fails on apply; that is correct behaviour, re-plan.

### `moved` blocks for refactors

```hcl
moved {
  from = aws_db_instance.ledger
  to   = module.ledger_db.aws_db_instance.this
}
```

Renaming or moving a resource into a module without `moved` plans a destroy and a create; with
it, the plan shows zero changes. `removed {}` (1.7+) forgets a resource without destroying it.
`terraform state mv` by hand is the last resort and must be followed by a plan that shows nothing.

### Drift detection

A scheduled pipeline (nightly) runs `terraform plan -detailed-exitcode`; exit 2 means drift and
opens an issue or alerts. Drift is fixed by applying the code or by changing the code to match a
deliberate manual change, then applying; the console edit is never the end state. `terraform import`
(or an `import {}` block) adopts resources created outside Terraform.

### Workspaces vs directories per environment

Directories (`envs/staging/`, `envs/production/`, each a root module with its own backend key and
tfvars) over workspaces: separate state, separate credentials, separate pipelines, a reviewer sees
which environment a diff touches. Workspaces share a backend and a configuration and differ only by
`terraform.workspace`; fine for short-lived preview environments, risky for staging vs production.

### Static checks in CI

`terraform fmt -check`, `terraform validate`, `tflint`, and one of `tfsec`/`trivy config`/`checkov`
on every MR; failures block. `infracost` on the plan when cost matters.

## Ansible

### Idempotent modules over `shell`

```yaml
# GOOD: declares the state; re-run is a no-op
- name: nginx present
  ansible.builtin.apt: { name: nginx=1.26.*, state: present }
- name: ledger config
  ansible.builtin.template: { src: ledger.env.j2, dest: /etc/ledger/env, mode: "0640", owner: ledger }
  notify: restart ledger

# BAD: changed every run, no diff, no check mode
- ansible.builtin.shell: curl -sL https://example.test/install.sh | sh
```

When `command:`/`shell:` is unavoidable: `creates:`/`removes:` or `changed_when:` so the task
reports truthfully, and `failed_when:` instead of relying on exit code semantics the tool lacks.

### Check mode in CI

```yaml
ansible-check:
  rules: [{ if: $CI_PIPELINE_SOURCE == "merge_request_event" }]
  script:
    - ansible-lint
    - ansible-playbook -i inventories/staging site.yml --syntax-check
    - ansible-playbook -i inventories/staging site.yml --check --diff
```

`--check --diff` prints what would change; a task that cannot run in check mode gets
`check_mode: false` only when it is read-only. Apply from the pipeline on merge, by environment,
with the same gating as Terraform.

### Vault for secrets

`ansible-vault encrypt_string --vault-id prod@prompt 's3cr…' --name db_password` into
`group_vars/production/vault.yml`; the plain `vars.yml` references `{{ vault_db_password }}`.
Vault password from the CI secret store via `--vault-password-file` pointing at a file written in
the job, or `ANSIBLE_VAULT_PASSWORD_FILE`. `no_log: true` on any task that handles the value.

### Inventories per environment

```
inventories/
  staging/     hosts.yml  group_vars/all.yml  group_vars/web.yml
  production/  hosts.yml  group_vars/all.yml  group_vars/web.yml  group_vars/all/vault.yml
```

Dynamic inventory plugins (`amazon.aws.aws_ec2`, `kubernetes.core`) over hand-maintained host
lists when the hosts come from a cloud. Never one inventory with `prod` and `staging` groups side
by side: a missing `--limit` applies to both.

### Handlers

```yaml
handlers:
  - name: restart ledger
    ansible.builtin.systemd: { name: ledger, state: restarted, daemon_reload: true }
```

Notified by the tasks that change config, run once at the end of the play even when five tasks
notify them. `meta: flush_handlers` when the restart must happen mid-play.

### ansible-lint

Runs on every MR with the project's `.ansible-lint` (profile `production` when the playbooks are
mature); fully-qualified collection names, `name:` on every task, no `ignore_errors: true` without
a comment. Collections pinned in `requirements.yml` and installed with `ansible-galaxy collection install -r`.

## Anti-patterns

- State in git, in a shared drive, or local on someone's laptop.
- `terraform apply` from a workstation with personal credentials; `-auto-approve` on a fresh plan.
- `version = ">= 5.0"` on a provider: a major-version upgrade arrives on an unrelated change.
- One root module for every environment switched by a variable.
- Resource renamed without `moved`: the plan destroys the production database.
- `shell: curl | sh` tasks; `ignore_errors: true` to make a run green.
- Vault password committed next to the vault file.
- Secrets in `-var` on the command line or in `plan.txt` artifacts without `sensitive = true`.
