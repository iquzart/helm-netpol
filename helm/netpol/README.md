# netpol — Kubernetes NetworkPolicy Helm Chart

A Helm chart for managing Kubernetes NetworkPolicies in a namespace.  
Supports global deny-all with auto-injected must-have rules, pre-built common patterns, and fully customizable policies.

---

## Architecture

```
globalDeny        →  Default-deny ingress/egress (baseline security)
    └── mustHave  →  Auto-injected when globalDeny is active (DNS, metrics, probes, API)
common            →  Pre-built opt-in allow patterns
custom            →  Fully user-defined NetworkPolicy specs
```

---

## Quick Start

```bash
helm install my-netpol ./netpol -n my-namespace
```

Default behaviour (out of the box):

- Deny all ingress
- Deny all egress
- Allow DNS (auto-injected)
- Allow Metrics Server (auto-injected)
- Allow Kubelet Probes (auto-injected)
- Allow Kubernetes API Server (auto-injected)

---

## Policy Rendering Flow

```
globalDeny.egress.enabled = true
    │
    ├─► NetworkPolicy: deny-all-egress
    │
    └─► Auto-inject mustHave:
            ├─► mustHave.dns            → allow-egress-dns
            ├─► mustHave.metricsServer  → allow-egress-metrics-server
            ├─► mustHave.kubeletProbes  → allow-egress-kubelet-probes
            └─► mustHave.kubeApiServer  → allow-egress-kube-apiserver

globalDeny.ingress.enabled = true
    │
    ├─► NetworkPolicy: deny-all-ingress
    │
    └─► Auto-inject mustHave (if enabled):
            └─► mustHave.coreDNSIngress → allow-ingress-coredns-healthcheck

common.<policy>.enabled = true
    └─► NetworkPolicy: allow-<policy-name>

custom[].enabled = true
    └─► NetworkPolicy: <custom.name>
```

---

## File Structure

```
netpol/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl            # shared label/selector/port helpers
    ├── netpol-global-deny.yaml # default-deny policies
    ├── netpol-must-have.yaml   # auto-injected critical rules
    ├── netpol-common.yaml      # pre-built allow patterns
    └── netpol-custom.yaml      # user-defined policies
```

---

## Values Reference

### `globalDeny`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `globalDeny.ingress.enabled` | bool | `true` | Deny all ingress traffic |
| `globalDeny.egress.enabled` | bool | `true` | Deny all egress traffic |

### `mustHave`

Auto-injected when the corresponding `globalDeny` direction is enabled.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `mustHave.dns.enabled` | bool | `true` | Allow DNS (UDP+TCP 53) |
| `mustHave.dns.nodeLocalDNS.enabled` | bool | `false` | Also allow NodeLocal DNSCache IP |
| `mustHave.metricsServer.enabled` | bool | `false` | Allow egress to metrics-server (TCP 4443) |
| `mustHave.kubeletProbes.enabled` | bool | `false` | Allow egress for kubelet probes (TCP 10250) |
| `mustHave.kubeApiServer.enabled` | bool | `false` | Allow egress to API server (TCP 443) |
| `mustHave.coreDNSIngress.enabled` | bool | `false` | Allow ingress from CoreDNS in kube-system |

### `common`

| Key | Description |
|-----|-------------|
| `allowIngressFromSameNamespace` | Pods in same namespace can reach each other |
| `allowIngressFromNamespace` | Allow from specific namespaces/pods (list) |
| `allowIngressFromIngress` | Allow from ingress controllers (list) |
| `allowIngressOnPorts` | Allow on specific ports from any source (list) |
| `allowIngressFromCIDR` | Allow from specific CIDRs with optional except (list) |
| `allowEgressToSameNamespace` | Pods in same namespace can reach each other |
| `allowEgressToNamespace` | Allow to specific namespaces/pods (list) |
| `allowEgressOnPorts` | Allow on specific ports to any destination (list) |
| `allowEgressToCIDR` | Allow to specific CIDRs with optional except (list) |
| `allowEgressToInternet` | Allow all outbound internet access |

### `custom[]`

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique name → becomes the NetworkPolicy resource name |
| `enabled` | Yes | Set `false` to skip rendering |
| `podSelector` | Yes | Target pods. Use `{}` for all pods in namespace |
| `policyTypes` | Yes | `[Ingress]`, `[Egress]`, or `[Ingress, Egress]` |
| `ingress` | conditional | Required if `Ingress` in policyTypes |
| `egress` | conditional | Required if `Egress` in policyTypes |

---

## AND vs OR Logic for Selectors

In `allowIngressFromNamespace`, `allowIngressFromIngress`, `allowEgressToNamespace`:

```yaml
# OR logic — two separate entries, either matches
from:
  - namespaceSelector:
      matchLabels:
        name: ns-a        # ← matches ns-a (any pod)
  - namespaceSelector:
      matchLabels:
        name: ns-b        # ← OR matches ns-b (any pod)

# AND logic — combined in one entry, both must match
from:
  - namespaceSelector:
      matchLabels:
        name: monitoring  # ← must be from 'monitoring' namespace
    podSelector:
      matchLabels:
        app: prometheus   # AND must be the prometheus pod
```

---

## CIDR Except

```yaml
allowIngressFromCIDR:
  enabled: true
  cidrs:
    - cidr: "10.0.0.0/8"       # allow entire range
    - cidr: "203.0.113.0/24"   # allow this range...
      except:
        - "203.0.113.5/32"     # ...except this specific IP
```

---

## Overriding Per-Release

```bash
# Disable metrics server must-have (if you use a custom setup)
helm install my-netpol ./netpol -n my-namespace \
  --set netpol.mustHave.metricsServer.enabled=false

# Enable ingress from monitoring namespace
helm install my-netpol ./netpol -n my-namespace \
  --set netpol.common.allowIngressFromNamespace.enabled=true
```
