# Kubernetes and Helm Patterns

Manifests are code: reviewed in a merge request, applied by the pipeline (or by Argo CD / Flux
from git), never from a laptop. Service `ledger-api` and every number below are invented.

## Workload Basics — Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger-api
  namespace: ledger
  labels: &labels
    app.kubernetes.io/name: ledger-api
    app.kubernetes.io/part-of: ledger
    app.kubernetes.io/version: "2.14.0"
spec:
  replicas: 3
  revisionHistoryLimit: 5
  selector:
    matchLabels: { app.kubernetes.io/name: ledger-api }
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }   # never below desired count
  template:
    metadata:
      labels: *labels
    spec:
      serviceAccountName: ledger-api
      automountServiceAccountToken: false                  # the app does not call the k8s API
      terminationGracePeriodSeconds: 30                    # ≥ the app's real drain time
      securityContext: { runAsNonRoot: true, runAsUser: 1001, fsGroup: 1001, seccompProfile: { type: RuntimeDefault } }
      containers:
        - name: api
          image: registry.example.test/ledger/api@sha256:0000000000000000000000000000000000000000000000000000000000000000
          ports: [{ name: http, containerPort: 8000 }]
          resources:
            requests: { cpu: 200m, memory: 256Mi }           # what the scheduler reserves
            limits: { memory: 512Mi }                        # memory limit always; CPU limit only when throttling is wanted
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: [ALL] }
          startupProbe:
            httpGet: { path: /health, port: http }
            periodSeconds: 5
            failureThreshold: 30                             # 150 s to boot, then the others take over
          livenessProbe:
            httpGet: { path: /health, port: http }
            periodSeconds: 30
            failureThreshold: 3                              # hung for 90 s → restart
          readinessProbe:
            httpGet: { path: /ready, port: http }
            periodSeconds: 10
            failureThreshold: 2                              # out of the Service after 20 s
          envFrom: [{ configMapRef: { name: ledger-api } }]
          env:
            - name: DB_PASSWORD
              valueFrom: { secretKeyRef: { name: ledger-api-db, key: password } }
          volumeMounts: [{ name: tmp, mountPath: /tmp }]
      volumes: [{ name: tmp, emptyDir: {} }]
```

### Requests and limits

Requests are what the scheduler reserves and what HPA divides by; limits are where the kernel
kills (memory) or throttles (CPU). Memory limit always; set it equal to the request for workers
whose footprint is known. CPU limit optional: throttling a latency-sensitive API at the limit hurts
more than letting it burst. Limits without requests silently set requests = limits and over-reserve.

### Probes — three questions, three answers

| Probe | Question | On failure | Checks |
|---|---|---|---|
| `startupProbe` | has it finished booting? | keeps waiting up to `failureThreshold × period`, then restarts | process answers |
| `livenessProbe` | is the process hung? | restart the container | process answers; **never** a dependency |
| `readinessProbe` | can it take traffic right now? | remove from Service endpoints, no restart | dependencies it needs per request |

A liveness probe that checks the database restarts every replica when the database blips, turning
a degradation into an outage. A readiness probe that only checks the process sends traffic to a
pod that cannot serve it. `initialDelaySeconds: 60` on liveness is a guess; a startup probe is the
measurement.

## PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: ledger-api, namespace: ledger }
spec:
  minAvailable: 2                                   # or maxUnavailable: 1; never minAvailable: 0
  selector: { matchLabels: { app.kubernetes.io/name: ledger-api } }
```

Required for anything with more than one replica: it is what makes a node drain wait instead of
taking the service down. `minAvailable` equal to `replicas` blocks every drain forever.

## HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: ledger-api, namespace: ledger }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: ledger-api }
  minReplicas: 3
  maxReplicas: 12
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 70 } }
  behavior:
    scaleDown: { stabilizationWindowSeconds: 300 }     # no flapping
```

HPA needs `requests` on every container (utilisation = usage / request). Scale on a metric that
tracks load for this service: CPU for CPU-bound APIs, queue depth (via an external metric) for
workers; memory almost never, it does not come back down. Do not set `replicas:` in the
Deployment once HPA owns it; the next apply fights the autoscaler.

## ConfigMap vs Secret, and External Secrets

ConfigMap for non-sensitive values (`LOG_LEVEL`, feature toggles, an `app.yaml`); Secret for
credentials. A Secret in git is base64, not encryption. Production secrets come from the store
through an operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: { name: ledger-api-db, namespace: ledger }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: vault-ledger, kind: ClusterSecretStore }
  target: { name: ledger-api-db }
  data:
    - secretKey: password
      remoteRef: { key: ledger/prod/db, property: password }
```

Alternatives when ESO is not there: Secrets Store CSI driver (mounted as files), sealed-secrets
(encrypted in git, decrypted by the controller), SOPS with the cluster's KMS key. Rotating a value
means a pod restart unless the app re-reads the mounted file; plan for that.

## Rolling Update Parameters

`maxSurge: 1, maxUnavailable: 0` is the safe default: one extra pod, never below capacity, slower.
`maxUnavailable: 25%` (the default) is fine for stateless services with headroom. Pair with
`minReadySeconds: 10` so a pod that passes readiness and crashes 3 s later does not count as
rolled out, and `progressDeadlineSeconds: 600` so a stuck rollout fails instead of hanging.
`kubectl rollout undo deployment/ledger-api` returns to the previous ReplicaSet; with Helm,
`helm rollback ledger-api <revision>`.

## Migrations — Init Containers, Jobs and the «one runner» rule

A migration runs **once per release**, not once per replica. Three replicas starting with
`migrate && serve` in the entrypoint race the same DDL; the two losers crash-loop or, worse, the
tool is not transactional and half-applies. Patterns:

```yaml
# Job, applied before the Deployment (or as a Helm pre-upgrade hook)
apiVersion: batch/v1
kind: Job
metadata:
  name: ledger-api-migrate-2-14-0                   # unique per release: Jobs are immutable
  namespace: ledger
spec:
  backoffLimit: 2
  completions: 1
  parallelism: 1
  ttlSecondsAfterFinished: 86400
  template:
    spec:
      restartPolicy: Never                            # never Always in a Job
      serviceAccountName: ledger-api
      containers:
        - name: migrate
          image: registry.example.test/ledger/api@sha256:0000000000000000000000000000000000000000000000000000000000000000
          command: ["python", "manage.py", "migrate", "--no-input"]
          envFrom: [{ secretRef: { name: ledger-api-db } }]
          resources: { requests: { cpu: 100m, memory: 256Mi }, limits: { memory: 512Mi } }
```

Helm: `annotations: {"helm.sh/hook": pre-upgrade,pre-install, "helm.sh/hook-weight": "0",
"helm.sh/hook-delete-policy": before-hook-creation}`; `--wait` makes the upgrade fail when the
hook fails, so bad schema never meets new code. An init container is acceptable only when the
migration tool takes a lock and the second runner exits cleanly as a no-op; even then a Job is
clearer. The ordering across releases (expand → deploy → contract) is in `deploy.md`; the SQL is
in `sql-patterns/references/migrations.md`.

## NetworkPolicy Basics

Default deny per namespace, then allow what is needed:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: ledger }
spec: { podSelector: {}, policyTypes: [Ingress, Egress] }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: ledger-api, namespace: ledger }
spec:
  podSelector: { matchLabels: { app.kubernetes.io/name: ledger-api } }
  policyTypes: [Ingress, Egress]
  ingress:
    - from: [{ namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: ingress } } }]
      ports: [{ port: 8000 }]
  egress:
    - to: [{ podSelector: { matchLabels: { app.kubernetes.io/name: postgres } } }]
      ports: [{ port: 5432 }]
    - to: [{ namespaceSelector: {}, podSelector: { matchLabels: { k8s-app: kube-dns } } }]
      ports: [{ port: 53, protocol: UDP }]       # DNS is the one everyone forgets
```

Needs a CNI that enforces policies (Calico, Cilium); on a CNI that does not, the manifest applies
and does nothing. Test with a `kubectl run --rm -it probe --image=busybox@sha256:… -- wget -T2 …`.

## RBAC Least Privilege

Most apps do not call the API: dedicated ServiceAccount, `automountServiceAccountToken: false`,
no Role. When one does (a controller, a config watcher):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: ledger-config-reader, namespace: ledger }
rules:
  - apiGroups: [""]
    resources: [configmaps]
    resourceNames: [ledger-api]                      # one object, not the namespace
    verbs: [get, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: ledger-config-reader, namespace: ledger }
subjects: [{ kind: ServiceAccount, name: ledger-api, namespace: ledger }]
roleRef: { kind: Role, name: ledger-config-reader, apiGroup: rbac.authorization.k8s.io }
```

`Role` over `ClusterRole`, `resourceNames` where possible, never `cluster-admin` for a workload.
The CI deployer's ServiceAccount gets a Role scoped to its namespace with the verbs `helm upgrade`
needs, not `cluster-admin` either.

## Naming and Labels

The `app.kubernetes.io/{name,instance,version,component,part-of,managed-by}` set on every object;
selectors use `name` + `instance` only (version changes every release and selectors are
immutable). Object names: `<app>[-<component>]`, lower-case, dashes, under 63 characters including
anything Helm prefixes. One namespace per system per environment (`ledger`, `ledger-staging`),
not one per microservice.

## Helm

### Chart layout

```
charts/ledger-api/
  Chart.yaml            # name, version (chart), appVersion (image)
  values.yaml           # every key documented, safe defaults, no environment-specific values
  values.schema.json    # optional; rejects unknown or mistyped keys at install time
  templates/
    _helpers.tpl        # names and labels, nothing else
    deployment.yaml  service.yaml  hpa.yaml  pdb.yaml  configmap.yaml
    migrate-job.yaml   # pre-upgrade hook
    networkpolicy.yaml serviceaccount.yaml
    NOTES.txt
  ci/                   # values files the pipeline lints with
```

Per-environment values live outside the chart with the deploy config:
`deploy/values/staging.yaml`, `deploy/values/production.yaml`; `helm upgrade -f values.yaml -f deploy/values/production.yaml`.
Secrets never in a values file; the chart references the Secret the operator creates.

### In CI

```sh
helm lint charts/ledger-api -f deploy/values/production.yaml
helm template ledger-api charts/ledger-api -f deploy/values/production.yaml \
  | kubeconform -strict -kubernetes-version 1.31.0 -ignore-missing-schemas
helm upgrade --install ledger-api charts/ledger-api \
  --namespace ledger --create-namespace \
  -f deploy/values/production.yaml \
  --set image.digest="$(cat image.digest)" \
  --atomic --wait --timeout 10m                     # failure → automatic rollback to the previous release
```

`--atomic` turns a failed rollout into a rollback instead of a half-upgraded release;
`helm diff upgrade` (plugin) on the MR shows what will change, like a Terraform plan.

### Chart versioning

`version` in `Chart.yaml` is the chart's SemVer, bumped when a template or default changes;
`appVersion` is the image tag it defaults to. Pin `dependencies:` by exact version and commit
`Chart.lock`. Publish to an OCI registry (`helm push … oci://registry.example.test/charts`) and
consume by version, never from a path on someone's machine.

### What not to template

- Anything that a values key could express: `{{ if .Values.featureX }}` is fine, 40 lines of
  Go template logic reimplementing an `if/else` tree is a sign the values are wrong.
- Secret values; Secret *names* are fine.
- Cluster-level objects (CRDs, ClusterRoles, namespaces, storage classes) inside an app chart; they
  belong to a platform chart with their own lifecycle.
- The image digest as a template default; it arrives from the pipeline with `--set`.

### kustomize

When the project uses kustomize instead: `base/` with the plain manifests, `overlays/<env>/` with
`patches:` and `images:` (digest set with `kustomize edit set image`); `kustomize build overlays/production | kubeconform`
in CI. Do not mix the two for one app; pick what the project already has.

## Anti-patterns

- `image: ledger-api:latest` with `imagePullPolicy: Always`: a different binary on every restart.
- No `resources`: a leaking pod evicts its neighbours; HPA cannot compute anything.
- Liveness probe hitting the database; readiness probe only hitting the process.
- `migrate` in the container entrypoint on a Deployment with `replicas > 1`.
- A plain Secret with base64 values committed to the repo.
- `cluster-admin` bound to an application or the CI deployer.
- PDB with `minAvailable: 0`, or equal to `replicas`.
- `kubectl apply -f` from a workstation to production; `helm upgrade` without `--atomic` and `--wait`.
- Environment-specific values hard-coded in `values.yaml` of the chart.
