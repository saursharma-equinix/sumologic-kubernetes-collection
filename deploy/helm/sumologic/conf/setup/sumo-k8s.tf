variable "cluster_name" {
  type  = string
  default = "{{ template "sumologic.clusterNameReplaceSpaceWithDash" . }}"
}

{{- if .Values.sumologic.collectorName }}
variable "collector_name" {
  type  = string
  default = "{{ .Values.sumologic.collectorName }}"
}
{{- else }}
variable "collector_name" {
  type  = string
  default = "{{ template "sumologic.clusterNameReplaceSpaceWithDash" . }}"
}
{{- end }}

variable "namespace_name" {
  type  = string
  default = "{{ .Release.Namespace }}"
}

locals {
  {{- range $source := .Values.sumologic.sources }}
  {{ template "sources.terraform_local" $source }}
  {{- end }}
}

provider "sumologic" {}

resource "sumologic_collector" "collector" {
    name  = var.collector_name
    fields  = {
      cluster = var.cluster_name
    }
}

{{- $ctx := .Values }}
{{ range $source := .Values.sumologic.sources }}
resource "sumologic_http_source" "{{ template "sources.terraform_name" $source }}" {
    name         = local.{{ template "sources.terraform_source_name" $source }}
    collector_id = "${sumologic_collector.collector.id}"
    {{- if $source.category }}
    category     = {{ if $ctx.fluentd.events.sourceCategory }}{{ $ctx.fluentd.events.sourceCategory | quote }}{{- else}}{{ "\"${var.cluster_name}/${local.events-source-name}\"" }}{{- end}}
    {{- end }}
}
{{ end }}

provider "kubernetes" {
{{- $ctx := .Values -}}
{{ $printf_str := "%-25s" }}
{{ range $key, $value := .Values.sumologic.cluster }}
  {{ if eq $key "exec" }}
  exec {
    command = "{{ $ctx.sumologic.cluster.exec.command }}"
    {{ if hasKey $ctx.sumologic.cluster.exec "api_version" }}{{ printf $printf_str "api_version" }} = "{{ $ctx.sumologic.cluster.exec.api_version }}"{{ end }}
    {{ if hasKey $ctx.sumologic.cluster.exec "args" }}
    {{ printf $printf_str "args" }} = {{ toJson $ctx.sumologic.cluster.exec.args }}
    {{- end -}}
    {{ if hasKey $ctx.sumologic.cluster.exec "env" }}
    {{ printf $printf_str "env" }} = {
      {{ range $key_env, $value_env := $ctx.sumologic.cluster.exec.env }}
        {{ printf $printf_str $key_env }} = "{{ $value_env }}"
      {{- end -}}
    }
    {{ end }}
  }
  {{- else -}}
  {{ printf "  %-25s" $key }} = "{{ $value }}"
  {{- end -}}
{{- end }}
}

resource "kubernetes_namespace" "sumologic_collection_namespace" {
  metadata {
    name = var.namespace_name
  }
}

resource "kubernetes_secret" "sumologic_collection_secret" {
  metadata {
    name = "sumologic"
    namespace = var.namespace_name
  }

  data = {
    endpoint-events                           = "${sumologic_http_source.events_source.url}"
    endpoint-logs                             = "${sumologic_http_source.logs_source.url}"
    endpoint-metrics                          = "${sumologic_http_source.default_metrics_source.url}"
    endpoint-metrics-apiserver                = "${sumologic_http_source.apiserver_metrics_source.url}"
    endpoint-metrics-kube-controller-manager  = "${sumologic_http_source.kube_controller_manager_metrics_source.url}"
    endpoint-metrics-kube-scheduler           = "${sumologic_http_source.kube_scheduler_metrics_source.url}"
    endpoint-metrics-kube-state               = "${sumologic_http_source.kube_state_metrics_source.url}"
    endpoint-metrics-kubelet                  = "${sumologic_http_source.kubelet_metrics_source.url}"
    endpoint-metrics-node-exporter            = "${sumologic_http_source.node_exporter_metrics_source.url}"
  }

  type = "Opaque"
}