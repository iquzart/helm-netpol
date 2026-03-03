# helm-netpol

Helm chart for managing Kubernetes NetworkPolicies in a namespace. Provides a global deny-all baseline with auto-injected critical rules, pre-built common allow patterns, and fully customizable user-defined policies.

## Repository Structure

```
.
└── helm
    └── netpol
        ├── Chart.yaml                    # Chart metadata and version
        ├── README.md                     # Chart-level documentation
        ├── values.yaml                   # Default values
        ├── values-ci.yaml                # CI/CD override values
        └── templates/
            ├── _helpers.tpl              # Shared template helpers
            ├── netpol-global-deny.yaml   # Default-deny policies
            ├── netpol-must-have.yaml     # Auto-injected critical rules
            ├── netpol-common.yaml        # Pre-built allow patterns
            └── netpol-custom.yaml        # User-defined policies
```

## How It Works

Policies are rendered in four layers:

```
globalDeny      deny-all ingress / egress (baseline)
    └── mustHave    auto-injected when globalDeny is active
common          explicit opt-in allow patterns
custom          fully user-defined NetworkPolicy specs
```

**`globalDeny`** creates a default-deny `NetworkPolicy` for ingress, egress, or both. When active, it automatically injects the `mustHave` rules so the cluster continues to function correctly — no manual wiring required.

**`mustHave`** covers the rules every namespace needs: DNS resolution, the metrics-server (required for HPA and `kubectl top`), kubelet probes (required for liveness/readiness checks), and the Kubernetes API server. Each can be individually disabled.

**`common`** provides pre-built patterns for the most frequent use cases — allowing traffic from specific namespaces, ingress controllers, CIDRs, or ports. All fields support multi-value lists.

**`custom`** accepts raw Kubernetes `NetworkPolicy` specs for anything not covered by the above.

## Usage

```bash
# Install into a namespace
helm install netpol ./helm/netpol -n <namespace>

# Dry-run to preview rendered policies
helm template netpol ./helm/netpol -n <namespace>

# Install with CI values
helm install netpol ./helm/netpol -n <namespace> -f ./helm/netpol/values-ci.yaml

# Upgrade
helm upgrade netpol ./helm/netpol -n <namespace> -f ./helm/netpol/values.yaml
```

## Default Behaviour

Out of the box with no overrides, the chart deploys:

| Policy | Direction | Source |
|--------|-----------|--------|
| Deny all traffic | Ingress + Egress | `globalDeny` |
| Allow DNS (UDP+TCP 53) | Egress | `mustHave` |
| Allow metrics-server (TCP 4443) | Egress | `mustHave` |
| Allow kubelet probes (TCP 10250) | Egress | `mustHave` |
| Allow Kubernetes API (TCP 443) | Egress | `mustHave` |

Everything else is opt-in.

## Configuration

### Enable a common policy

```yaml
netpol:
  common:
    allowIngressFromNamespace:
      enabled: true
      from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
          podSelector:
            matchLabels:
              app: prometheus
```

### Add a custom policy

```yaml
netpol:
  custom:
    - name: allow-frontend-to-backend
      enabled: true
      podSelector:
        matchLabels:
          app: frontend
      policyTypes:
        - Egress
      egress:
        - to:
            - podSelector:
                matchLabels:
                  app: backend
          ports:
            - port: 3000
              protocol: TCP
```

### Disable a must-have rule

```yaml
netpol:
  mustHave:
    metricsServer:
      enabled: false
```

## Requirements

- Kubernetes 1.21+
- Helm 3.0+
- A CNI plugin that enforces NetworkPolicies (Calico, Cilium, Weave, etc.)

## License

MIT
