# Monitoring et Observabilité - Stack Prometheus/Grafana/Loki

## Architecture de monitoring

### Vue d'ensemble
```
┌─────────────────────────────────────────────────────────────────┐
│                    Observability Stack                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────┐ │
│  │  Prometheus   │ │    Loki     │ │  Grafana    │ │AlertMgr  │ │
│  │   Metrics     │ │    Logs     │ │Visualization│ │ Alerting │ │
│  │   Storage     │ │   Storage   │ │ Dashboards  │ │ Routing  │ │
│  └───────────────┘ └─────────────┘ └─────────────┘ └──────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                      Collectors                                │
│  ┌───────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │ Node Exporter │ │  Promtail   │ │ Kube State  │             │
│  │System Metrics │ │Log Collector│ │K8s Metrics  │             │
│  │  (DaemonSet)  │ │(DaemonSet)  │ │  Metrics    │             │
│  └───────────────┘ └─────────────┘ └─────────────┘             │
├─────────────────────────────────────────────────────────────────┤
│                    Target Sources                              │
│  ┌───────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │   Kubernetes  │ │Applications │ │   System    │             │
│  │   API/Pods    │ │   Metrics   │ │    Logs     │             │
│  │   Services    │ │    /health  │ │  journald   │             │
│  └───────────────┘ └─────────────┘ └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## Prometheus - Collecte de métriques

### Configuration Prometheus
**Service**: `prometheus-kube-prometheus-stack-prometheus-0`
**Namespace**: monitoring
**Port**: 9090 (interne cluster)

#### Targets configurés
```yaml
# Scrape configs automatiques via ServiceMonitor
- job_name: 'kubernetes-apiservers'
  kubernetes_sd_configs:
  - role: endpoints
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

- job_name: 'kubernetes-nodes'
  kubernetes_sd_configs:
  - role: node
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

- job_name: 'kubernetes-pods'
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    action: keep
    regex: true
```

#### Métriques système (Node Exporter)
**Service**: `kube-prometheus-stack-prometheus-node-exporter`
**Port**: 9100 (exposé publiquement)
**Métriques collectées**:
- CPU usage, load average
- Memory usage, swap
- Disk I/O, filesystem usage
- Network interfaces
- System temperatures, power

#### Métriques Kubernetes (Kube State Metrics)
**Service**: `kube-prometheus-stack-kube-state-metrics`
**Métriques collectées**:
- Pods status, restarts, resource usage
- Deployments replicas, availability
- Services endpoints
- PersistentVolumes status
- Nodes capacity, allocatable

#### Métriques applications
**Pattern**: Applications exposent `/metrics` sur port dédié
```yaml
# Exemple annotation pour scraping automatique
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

### Retention et stockage
- **Retention**: 15 jours (configurable)
- **Storage**: Local PV via local-path-provisioner
- **Compression**: gzip automatique
- **Backup**: Snapshots recommandés

## Grafana - Visualisation

### Configuration Grafana
**Service**: `kube-prometheus-stack-grafana`
**Namespace**: monitoring
**Port**: 3000 (via Ingress)
**Accès**: https://grafana.domain.com (à configurer)

#### Datasources configurées
```yaml
# Prometheus datasource
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  url: http://prometheus-operated:9090
  access: proxy
  isDefault: true
  
- name: Loki
  type: loki
  url: http://loki:3100
  access: proxy
```

#### Dashboards intégrés
**Kubernetes Monitoring**:
- **Kubernetes Cluster Overview**: Vue globale cluster
- **Kubernetes Node Overview**: Métriques par node
- **Kubernetes Pod Overview**: Métriques par pod
- **Kubernetes Deployment**: Status des déploiements

**System Monitoring**:
- **Node Exporter Full**: Métriques système complètes
- **System Overview**: CPU, Memory, Disk, Network
- **Disk Performance**: I/O, latency, throughput

**Application Monitoring**:
- **API Gateway Metrics**: Requêtes, latence, erreurs
- **Kafka Cluster**: Topics, partitions, lag consumer
- **Flux GitOps**: Reconciliation status, drift detection

### Custom Dashboards

#### Kubernetes Applications Dashboard
```json
{
  "dashboard": {
    "title": "Applications Overview",
    "panels": [
      {
        "title": "Pod Status",
        "type": "stat",
        "targets": [
          {
            "expr": "sum by (namespace) (kube_pod_status_phase{phase=\"Running\"})"
          }
        ]
      },
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "sum by (pod) (rate(container_cpu_usage_seconds_total[5m]))"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph", 
        "targets": [
          {
            "expr": "sum by (pod) (container_memory_working_set_bytes)"
          }
        ]
      }
    ]
  }
}
```

## Loki - Agrégation de logs

### Configuration Loki
**Service**: `loki-0`
**Namespace**: monitoring
**Port**: 3100 (interne cluster)
**Storage**: Local filesystem

#### Architecture Loki
```yaml
# Configuration Loki
auth_enabled: false
server:
  http_listen_port: 3100
ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
schema_config:
  configs:
  - from: 2020-10-24
    store: boltdb-shipper
    object_store: filesystem
    schema: v11
    index:
      prefix: index_
      period: 24h
storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks
```

### Promtail - Collecteur de logs
**Service**: `loki-promtail` (DaemonSet)
**Collecte**:
- Logs containers Kubernetes
- Logs système via journald
- Logs applications via stdout/stderr

#### Configuration Promtail
```yaml
# Scrape configs
scrape_configs:
- job_name: kubernetes-pods
  kubernetes_sd_configs:
  - role: pod
  pipeline_stages:
  - cri: {}
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_controller_name]
    regex: ([0-9a-z-.]+?)(-[0-9a-f]{8,10})?
    target_label: __tmp_controller_name
  - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
    target_label: app
  - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_component]
    target_label: component

- job_name: journal
  journal:
    json: false
    max_age: 12h
    path: /var/log/journal
    labels:
      job: systemd-journal
  pipeline_stages:
  - json:
      expressions:
        transport: _TRANSPORT
        unit: _SYSTEMD_UNIT
        priority: PRIORITY
  - labels:
      transport:
      unit:
      priority:
```

### Requêtes LogQL

#### Logs par application
```logql
# Logs API Gateway
{app="api-gateway"} |= "ERROR"

# Logs avec parsing JSON
{app="api-gateway"} | json | level="error"

# Métriques de logs
rate({app="api-gateway"} |= "ERROR" [5m])

# Agrégation par service
sum by (app) (rate({namespace="default"}[5m]))
```

#### Logs système
```logql
# Logs SSH
{unit="ssh.service"}

# Logs Kubernetes
{unit="k3s.service"} |= "ERROR"

# Logs par priorité
{job="systemd-journal"} | json | priority <= "3"
```

## AlertManager - Gestion des alertes

### Configuration AlertManager
**Service**: `alertmanager-kube-prometheus-stack-alertmanager-0`
**Namespace**: monitoring
**Port**: 9093 (interne cluster)

#### Routes d'alertes
```yaml
# Configuration routing
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default'
  routes:
  - match:
      severity: critical
    receiver: 'critical-alerts'
  - match:
      alertname: DeadMansSwitch
    receiver: 'deadmansswitch'

receivers:
- name: 'default'
  slack_configs:
  - api_url: 'SLACK_WEBHOOK_URL'
    channel: '#alerts'
    title: 'Alert: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

- name: 'critical-alerts'
  slack_configs:
  - api_url: 'SLACK_WEBHOOK_URL'
    channel: '#critical'
    title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

### Rules d'alertes

#### Alertes système
```yaml
# rules/system.yaml
groups:
- name: system
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"
      description: "CPU usage is {{ $value }}% on {{ $labels.instance }}"

  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
      description: "Memory usage is {{ $value }}% on {{ $labels.instance }}"

  - alert: DiskSpaceLow
    expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 90
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Low disk space on {{ $labels.instance }}"
      description: "Disk usage is {{ $value }}% on {{ $labels.instance }}"
```

#### Alertes Kubernetes
```yaml
# rules/kubernetes.yaml
groups:
- name: kubernetes
  rules:
  - alert: PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[5m]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ $labels.pod }} is crash looping"
      description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently"

  - alert: DeploymentReplicasMismatch
    expr: kube_deployment_spec_replicas != kube_deployment_status_available_replicas
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Deployment {{ $labels.deployment }} has mismatched replicas"
      description: "Deployment {{ $labels.deployment }} has {{ $value }} available replicas but {{ $labels.spec_replicas }} desired"

  - alert: NodeNotReady
    expr: kube_node_status_condition{condition="Ready",status="true"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Node {{ $labels.node }} is not ready"
      description: "Node {{ $labels.node }} has been not ready for more than 5 minutes"
```

#### Alertes applications
```yaml
# rules/applications.yaml
groups:
- name: applications
  rules:
  - alert: APIHighErrorRate
    expr: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate on API"
      description: "API error rate is {{ $value | humanizePercentage }}"

  - alert: APIHighLatency
    expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 0.5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High latency on API"
      description: "95th percentile latency is {{ $value }}s"
```

## Opérations de monitoring

### Requêtes Prometheus courantes

#### Santé cluster
```promql
# Nodes disponibles
up{job="kubernetes-nodes"}

# Pods en cours d'exécution
sum by (namespace) (kube_pod_status_phase{phase="Running"})

# CPU utilization cluster
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory utilization cluster
(1 - (sum(node_memory_MemAvailable_bytes) / sum(node_memory_MemTotal_bytes))) * 100
```

#### Performance applications
```promql
# Request rate par service
sum by (service) (rate(http_requests_total[5m]))

# Error rate par service
sum by (service) (rate(http_requests_total{status=~"5.."}[5m])) / sum by (service) (rate(http_requests_total[5m]))

# Latence 95e percentile
histogram_quantile(0.95, sum by (service, le) (rate(http_request_duration_seconds_bucket[5m])))
```

### Troubleshooting avec logs

#### Corrélation métriques et logs
```logql
# Erreurs pendant pic de latence
{app="api-gateway"} |= "ERROR" | json | __error__ = ""

# Logs autour d'un timestamp spécifique
{app="api-gateway"} | json | timestamp > "2024-08-15T10:00:00Z" and timestamp < "2024-08-15T10:05:00Z"
```

### Maintenance monitoring

#### Backup métriques
```bash
# Snapshot Prometheus
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Export dashboard Grafana
curl -H "Authorization: Bearer $GRAFANA_TOKEN" \
  http://grafana:3000/api/dashboards/uid/dashboard-uid
```

#### Rotation logs Loki
```bash
# Nettoyage automatique configuré
# Retention: 30 jours par défaut
# Compaction: Automatique

# Vérification espace disque
kubectl exec -n monitoring loki-0 -- df -h /loki
```

### Monitoring de monitoring

#### Self-monitoring
```promql
# Prometheus ingestion rate
rate(prometheus_tsdb_samples_appended_total[5m])

# Prometheus storage size
prometheus_tsdb_size_bytes

# Loki ingestion rate
rate(loki_ingester_samples_received_total[5m])

# Grafana active sessions
grafana_stat_active_sessions
```

## Accès et interfaces

### URLs des services (à configurer avec ingress)
- **Grafana**: https://grafana.domain.com
- **Prometheus**: https://prometheus.domain.com (optionnel)
- **AlertManager**: https://alertmanager.domain.com (optionnel)

### Authentification
- **Grafana**: Admin user (password dans secret)
- **Prometheus**: Accès cluster interne seulement
- **AlertManager**: Accès cluster interne seulement

### APIs disponibles
```bash
# Prometheus API
curl http://prometheus:9090/api/v1/query?query=up

# Loki API
curl http://loki:3100/loki/api/v1/labels

# Grafana API
curl -H "Authorization: Bearer $TOKEN" http://grafana:3000/api/dashboards/home
```