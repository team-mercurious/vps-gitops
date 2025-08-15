# Kubernetes Cluster - Configuration K3s

## Configuration du cluster

### Informations générales
- **Distribution**: K3s v1.28.5+k3s1
- **Type**: Single-node control-plane/master
- **Runtime**: containerd 1.7.11-k3s2
- **Node**: vps-6227e9e1
- **Status**: Ready (depuis 37h)

### Composants système

#### Control Plane
```yaml
apiVersion: v1
kind: Node
metadata:
  name: vps-6227e9e1
spec:
  roles:
    - control-plane
    - master
status:
  conditions:
    - type: Ready
      status: "True"
  nodeInfo:
    osImage: "Ubuntu 24.10"
    kernelVersion: "6.11.0-19-generic"
    containerRuntimeVersion: "containerd://1.7.11-k3s2"
```

#### Services système K3s
- **API Server**: Port 6443 (accessible localement et externement)
- **kubelet**: Port 10250
- **kube-proxy**: Géré par K3s
- **etcd**: Intégré dans K3s (single-node)

### Namespaces et applications

#### Namespace: kube-system
**Composants essentiels:**
- `local-path-provisioner`: Gestion du stockage local
- `coredns`: Résolution DNS interne
- `traefik`: Ingress controller et load balancer
- `metrics-server`: Métriques de ressources
- `helm-install-*`: Jobs d'installation Helm

**Ports exposés:**
- Traefik: 80, 443 (HTTP/HTTPS)
- Kubernetes API: 6443

#### Namespace: flux-system
**Contrôleurs GitOps:**
- `source-controller`: Gestion des sources Git/Helm
- `kustomize-controller`: Applications Kustomize
- `helm-controller`: Charts Helm
- `image-reflector-controller`: Détection d'images
- `image-automation-controller`: Mise à jour automatique
- `notification-controller`: Notifications et webhooks

**Configuration source:**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  url: https://github.com/[votre-repo]/k3s-gitops
  ref:
    branch: main
  interval: 1m
  secretRef:
    name: flux-system
```

#### Namespace: cert-manager
**Composants:**
- `cert-manager`: Gestionnaire de certificats principal
- `cert-manager-webhook`: Validation des CRDs
- `cert-manager-cainjector`: Injection CA

**Issuers configurés:**
- Let's Encrypt Production
- Let's Encrypt Staging

#### Namespace: monitoring
**Stack observabilité:**
- `prometheus`: Collecte de métriques (stack kube-prometheus)
- `grafana`: Visualisation et dashboards
- `alertmanager`: Gestion des alertes
- `loki`: Agrégation de logs
- `promtail`: Agent de collecte de logs (DaemonSet)
- `node-exporter`: Métriques système (DaemonSet)
- `kube-state-metrics`: Métriques Kubernetes

#### Namespace: kafka
**Messaging platform:**
- `strimzi-cluster-operator`: Opérateur Kafka
- `mercurious-cluster-zookeeper-0`: Coordination Zookeeper
- `mercurious-cluster-kafka-0`: Broker Kafka
- `mercurious-cluster-entity-operator`: Gestion des topics/users
- `kafka-client`: Client de test (Job completed)
- `kafka-admin`: Administration (Job completed)

#### Namespace: default
**Applications métier:**
- `api-gateway`: Point d'entrée API
- `api-generation`: Service de génération
- `api-enrichment`: Service d'enrichissement

### Configuration réseau

#### Traefik (Ingress Controller)
**Services exposés:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: kube-system
spec:
  type: LoadBalancer
  ports:
    - name: web
      port: 80
      targetPort: 8000
    - name: websecure
      port: 443
      targetPort: 8443
```

**Ports internes:**
- Dashboard: 8080 (local seulement)
- Métriques: 8082
- Health checks: 8000/8443

#### DNS interne (CoreDNS)
- Service DNS: 10.43.0.10:53
- Résolution `.local` et `.cluster.local`
- Forward vers systemd-resolved

### Storage

#### Local Path Provisioner
**StorageClass par défaut:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

**Path de stockage:** `/opt/local-path-provisioner`

### Auto-scaling

#### HPA configuré pour:
- `api-gateway`: min 1, max 10 replicas
- `api-generation`: min 1, max 10 replicas  
- `api-enrichment`: min 1, max 10 replicas

**Métriques utilisées:**
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)

### Sécurité

#### RBAC
- Service accounts dédiés par namespace
- Flux avec privilèges admin (cluster-admin)
- Applications avec permissions minimales

#### Network Policies
- Isolation par défaut entre namespaces
- Communication autorisée vers kafka
- Accès monitoring depuis tous les namespaces

#### Pod Security Standards
- Profil "restricted" par défaut
- Exceptions pour flux-system et kube-system
- Scan de vulnérabilités activé

### Monitoring cluster

#### Métriques disponibles
- **Node metrics**: CPU, memory, disk, network
- **Pod metrics**: Resource usage, restarts, status
- **Cluster metrics**: API server, etcd, scheduler
- **Application metrics**: Custom metrics exposées

#### Dashboards Grafana
- Kubernetes Cluster Overview
- Node Exporter Dashboard  
- Pod Resource Usage
- Kafka Cluster Metrics

### Opérations courantes

#### Vérification santé cluster
```bash
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A
```

#### Logs troubleshooting
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
kubectl logs -n flux-system -l app=source-controller
journalctl -u k3s
```

#### Maintenance
```bash
# Restart K3s
sudo systemctl restart k3s

# Cordon/Uncordon node
kubectl cordon vps-6227e9e1
kubectl uncordon vps-6227e9e1

# Force pod restart
kubectl rollout restart deployment/api-gateway
```