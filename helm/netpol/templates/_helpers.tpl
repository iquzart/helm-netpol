{{/*
=============================================================================
_helpers.tpl — Shared template helpers for netpol chart
=============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "netpol.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all NetworkPolicy resources.
*/}}
{{- define "netpol.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "netpol.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Render a list of ports for a NetworkPolicy rule.
Usage: {{ include "netpol.ports" .ports }}
*/}}
{{- define "netpol.ports" -}}
{{- range . }}
- port: {{ .port }}
  protocol: {{ .protocol | default "TCP" }}
{{- end }}
{{- end }}

{{/*
Render a list of ipBlock entries from a cidrs list.
Usage: {{ include "netpol.ipBlocks" .cidrs }}
*/}}
{{- define "netpol.ipBlocks" -}}
{{- range . }}
- ipBlock:
    cidr: {{ .cidr }}
    {{- if .except }}
    except:
      {{- range .except }}
      - {{ . }}
      {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Render a namespaceSelector + optional podSelector entry.
Accepts a single `from` or `to` entry dict.
*/}}
{{- define "netpol.selectorEntry" -}}
- namespaceSelector:
    matchLabels:
      {{- range $k, $v := .namespaceSelector.matchLabels }}
      {{ $k }}: {{ $v }}
      {{- end }}
  {{- if .podSelector }}
  podSelector:
    {{- if .podSelector.matchLabels }}
    matchLabels:
      {{- range $k, $v := .podSelector.matchLabels }}
      {{ $k }}: {{ $v }}
      {{- end }}
    {{- else }}
    {}
    {{- end }}
  {{- end }}
{{- end }}
