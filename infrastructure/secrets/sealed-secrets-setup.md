# Sealed Secrets Setup for OLYMPUS

Sealed Secrets encrypts Kubernetes Secrets so they can be safely committed to Git.
The controller in-cluster holds the private key; only it can decrypt.

## 1. Install Sealed Secrets Controller

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace infrastructure \
  --set fullnameOverride=sealed-secrets-controller
```

Verify the controller is running:

```bash
kubectl get pods -n infrastructure -l app.kubernetes.io/name=sealed-secrets
```

## 2. Install kubeseal CLI (macOS)

```bash
brew install kubeseal
```

Verify:

```bash
kubeseal --version
```

## 3. Workflow: Plain Secret → Sealed Secret → Git

### Step 1 — Create a plain Secret (never commit this)

```bash
kubectl create secret generic vikunja-agent-secrets \
  --namespace apps \
  --from-literal=VIKUNJA_API_URL=https://tasks.ramoneees.com/api/v1 \
  --from-literal=VIKUNJA_HERMES_TOKEN=actual-token-here \
  --dry-run=client -o yaml > vikunja-agent-secrets.yaml
```

### Step 2 — Seal it with kubeseal

```bash
kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=infrastructure \
  --format yaml \
  < vikunja-agent-secrets.yaml \
  > vikunja-agent-secrets-sealed.yaml
```

### Step 3 — Delete the plain secret, commit the sealed version

```bash
rm vikunja-agent-secrets.yaml  # NEVER commit this
git add vikunja-agent-secrets-sealed.yaml
git commit -m "Add sealed vikunja agent secrets"
git push
```

ArgoCD syncs the SealedSecret → the controller decrypts it → a regular Secret appears in the cluster.

## 4. Example SealedSecret Manifest

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: vikunja-agent-secrets
  namespace: apps
  labels:
    app.kubernetes.io/part-of: olympus
    app.kubernetes.io/component: agent-secrets
spec:
  encryptedData:
    VIKUNJA_API_URL: AgBy8s...  # kubeseal-encrypted value
    VIKUNJA_HERMES_TOKEN: AgCx7...
    VIKUNJA_HEPHAESTUS_TOKEN: AgDz9...
    VIKUNJA_PROMETHEUS_TOKEN: AgEw2...
    VIKUNJA_ATHENA_TOKEN: AgFv4...
    VIKUNJA_PLUTUS_TOKEN: AgGu6...
    VIKUNJA_THEMIS_TOKEN: AgHt8...
    VIKUNJA_MNEMOSYNE_TOKEN: AgIs1...
  template:
    metadata:
      name: vikunja-agent-secrets
      namespace: apps
      labels:
        app.kubernetes.io/part-of: olympus
        app.kubernetes.io/component: agent-secrets
    type: Opaque
```

## 5. Important Notes

- **Namespace-scoped by default**: Sealed Secrets are bound to a specific namespace. A sealed secret for `apps` cannot be applied to `olympus`. You must seal separately for each target namespace.
- **Key rotation**: The controller rotates its key every 30 days by default. Old sealed secrets remain valid — they are re-encrypted on update.
- **Backup the master key**: Export with `kubectl get secret -n infrastructure -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > master-key-backup.yaml` and store offline.
- **Re-sealing**: If you need to update a token value, create a new plain secret with the updated value, re-seal, and commit.
- **Plutus secrets**: Even when sealed, ensure the agent deployment using these secrets is pinned to the olympus node via `nodeSelector`.
