# Guide de Troubleshooting - Diagnostic et Résolution

## Méthodologie de diagnostic

### Approche structurée
1. **Identifier les symptômes**: Logs, métriques, alertes
2. **Isoler la couche**: Système, Kubernetes, Application
3. **Vérifier les dépendances**: Services, réseau, stockage
4. **Appliquer la solution**: Étapes documentées
5. **Valider la résolution**: Tests et monitoring

### Outils de diagnostic
```bash
# Santé générale système
systemctl status
journalctl --since "1 hour ago" --priority=err
top
df -h
free -h

# Santé Kubernetes
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A

# Santé applications
kubectl logs -l app=api-gateway --tail=100
kubectl describe pod <pod-name>
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Problèmes système

### High CPU Usage

#### Diagnostic
```bash
# Identifier les processus
top -o %CPU
ps aux --sort=-%cpu | head -10

# Vérifier load average
uptime
cat /proc/loadavg

# Métriques Prometheus
# Requête: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

#### Solutions courantes
```bash
# Redémarrer services gourmands
sudo systemctl restart service-name

# Limiter resources Kubernetes
kubectl patch deployment api-gateway -p '{"spec":{"template":{"spec":{"containers":[{"name":"api-gateway","resources":{"limits":{"cpu":"500m"}}}]}}}}'

# Scaling horizontal si HPA configuré
kubectl scale deployment api-gateway --replicas=3
```

### High Memory Usage

#### Diagnostic
```bash
# Mémoire système
free -h
cat /proc/meminfo
ps aux --sort=-%mem | head -10

# Mémoire containers
kubectl top pods --sort-by=memory
kubectl describe node vps-6227e9e1 | grep -A 20 "Allocated resources"
```

#### Solutions
```bash
# Redémarrer pod avec fuite mémoire
kubectl delete pod <pod-name>

# Ajuster limits mémoire
kubectl patch deployment api-gateway -p '{"spec":{"template":{"spec":{"containers":[{"name":"api-gateway","resources":{"limits":{"memory":"512Mi"}}}]}}}}'

# Vider caches système
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
```

### Disk Space Full

#### Diagnostic
```bash
# Espace disque
df -h
du -sh /* | sort -hr | head -10

# Logs volumineux
journalctl --disk-usage
find /var/log -name "*.log" -size +100M

# Images Docker/containerd
crictl images
crictl system df
```

#### Solutions
```bash
# Nettoyer journald
sudo journalctl --vacuum-time=7d
sudo journalctl --vacuum-size=500M

# Nettoyer containers/images
sudo crictl rmi --prune
sudo crictl system prune -a

# Nettoyer logs applicatifs
kubectl logs api-gateway-xxx --previous > /tmp/logs.txt
kubectl logs api-gateway-xxx --tail=0
```

## Problèmes Kubernetes

### Pods Crash/Restart Loop

#### Diagnostic
```bash
# Status pods problématiques
kubectl get pods --field-selector=status.phase!=Running
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# Events récents
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20

# Resource constraints
kubectl top pods
kubectl describe node vps-6227e9e1
```

#### Solutions courantes
```bash
# Pod OOMKilled
kubectl patch deployment api-gateway -p '{"spec":{"template":{"spec":{"containers":[{"name":"api-gateway","resources":{"limits":{"memory":"1Gi"},"requests":{"memory":"512Mi"}}}]}}}}'

# Image pull errors
kubectl describe pod <pod-name> | grep -A 10 "Events"
# Vérifier image policy et registry access

# Readiness/Liveness probe failures
kubectl edit deployment api-gateway
# Ajuster probe timeouts et intervals

# Force restart deployment
kubectl rollout restart deployment api-gateway
```

### Node NotReady

#### Diagnostic
```bash
# Status node détaillé
kubectl describe node vps-6227e9e1
kubectl get node -o yaml vps-6227e9e1

# K3s service
sudo systemctl status k3s
sudo journalctl -u k3s --since "1 hour ago"

# Resources node
kubectl top node vps-6227e9e1
```

#### Solutions
```bash
# Restart K3s
sudo systemctl restart k3s

# Vérifier network connectivity
ping 8.8.8.8
nslookup kubernetes.io

# Disk pressure resolution
# Nettoyer espace disque (voir section précédente)

# Memory pressure resolution
# Arrêter pods non-critiques temporairement
kubectl scale deployment non-critical-app --replicas=0
```

### Service/Ingress Inaccessible

#### Diagnostic
```bash
# Vérifier services et endpoints
kubectl get svc
kubectl get endpoints
kubectl describe svc api-gateway

# Vérifier ingress
kubectl get ingress
kubectl describe ingress api-gateway
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# Test connectivité interne
kubectl run test-pod --image=busybox --rm -it -- sh
# Dans le pod: wget -qO- api-gateway.default.svc.cluster.local
```

#### Solutions
```bash
# Recréer endpoints
kubectl delete endpoints api-gateway
# Service va recréer automatiquement

# Restart ingress controller
kubectl rollout restart deployment -n kube-system traefik

# Vérifier certificats TLS
kubectl describe certificate api-gateway-tls
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager

# Debug DNS interne
kubectl exec -it test-pod -- nslookup api-gateway.default.svc.cluster.local
```

## Problèmes Flux GitOps

### Reconciliation Failed

#### Diagnostic
```bash
# Status Flux components
flux get all
flux get sources git
flux get kustomizations

# Logs controllers
kubectl logs -n flux-system -l app=source-controller --tail=100
kubectl logs -n flux-system -l app=kustomize-controller --tail=100

# Git connectivity
flux get sources git flux-system
```

#### Solutions
```bash
# Force reconciliation
flux reconcile source git flux-system
flux reconcile kustomization apps

# Vérifier credentials Git
kubectl get secret -n flux-system flux-system -o yaml

# Reset stuck kustomization
flux suspend kustomization apps
flux resume kustomization apps

# Check Git repository access
kubectl exec -n flux-system deploy/source-controller -- git ls-remote https://github.com/user/repo.git
```

### Image Automation Issues

#### Diagnostic
```bash
# Status image automation
flux get image repository
flux get image policy
flux get image update

# Logs image controllers
kubectl logs -n flux-system -l app=image-reflector-controller
kubectl logs -n flux-system -l app=image-automation-controller
```

#### Solutions
```bash
# Force image scan
flux reconcile image repository api-gateway

# Vérifier registry credentials
kubectl get secret regcred -o yaml

# Debug image policy
kubectl describe imagepolicy api-gateway-policy

# Manual image update test
flux trace api-gateway --kind=Deployment
```

### SOPS Decryption Failed

#### Diagnostic
```bash
# Vérifier secret SOPS
kubectl get secret -n flux-system sops-age
kubectl describe secret -n flux-system sops-age

# Logs décryptage
kubectl logs -n flux-system -l app=kustomize-controller | grep -i sops

# Test décryptage manuel
sops -d security/secret-kafka.sops.yaml
```

#### Solutions
```bash
# Recréer secret SOPS
kubectl delete secret -n flux-system sops-age
kubectl create secret generic sops-age --from-file=age.key=/home/ubuntu/.sops/age.key -n flux-system

# Vérifier clé Age
file /home/ubuntu/.sops/age.key
cat /home/ubuntu/.sops/age.key | head -1

# Test avec nouvelle clé
age-keygen -o new-age.key
# Puis re-chiffrer secrets avec nouvelle clé
```

## Problèmes applications

### API Gateway 502/503 Errors

#### Diagnostic
```bash
# Logs API Gateway
kubectl logs -l app=api-gateway --tail=100
kubectl describe deployment api-gateway

# Vérifier health checks
kubectl exec deployment/api-gateway -- curl -I localhost:8080/health

# Traefik routing
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik | grep "api-gateway"
```

#### Solutions
```bash
# Restart pods
kubectl rollout restart deployment api-gateway

# Vérifier configuration service
kubectl get svc api-gateway -o yaml
kubectl edit svc api-gateway

# Test direct pod access
kubectl port-forward deployment/api-gateway 8080:8080
curl -I localhost:8080/health

# Check ingress configuration
kubectl edit ingress api-gateway
```

### Kafka Connection Issues

#### Diagnostic
```bash
# Status Kafka cluster
kubectl get kafka -n kafka
kubectl get kafkatopic -n kafka
kubectl logs -n kafka mercurious-cluster-kafka-0

# Test connectivity depuis applications
kubectl exec deployment/api-gateway -- nc -zv mercurious-cluster-kafka-bootstrap.kafka.svc.cluster.local 9092
```

#### Solutions
```bash
# Restart Kafka
kubectl delete pod -n kafka mercurious-cluster-kafka-0

# Vérifier network policies
kubectl get networkpolicy -A
kubectl describe networkpolicy allow-kafka-access

# Test avec kafka client
kubectl run kafka-test --image=confluentinc/cp-kafka:latest --rm -it -- bash
# Dans le pod:
kafka-console-producer --bootstrap-server mercurious-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 --topic test
```

### Database Connection Problems

#### Diagnostic
```bash
# Si databases externes utilisées
kubectl exec deployment/api-generation -- nc -zv database-host 5432

# Vérifier secrets database
kubectl get secret db-credentials -o yaml
kubectl describe secret db-credentials

# Logs applications avec erreurs DB
kubectl logs -l app=api-generation | grep -i "database\|connection\|sql"
```

## Problèmes réseau

### DNS Resolution Issues

#### Diagnostic
```bash
# Test DNS système
nslookup google.com
dig @127.0.0.53 kubernetes.io

# Test DNS cluster
kubectl exec -it test-pod -- nslookup kubernetes.default.svc.cluster.local
kubectl logs -n kube-system -l k8s-app=kube-dns

# Status systemd-resolved
systemctl status systemd-resolved
resolvectl status
```

#### Solutions
```bash
# Restart DNS services
sudo systemctl restart systemd-resolved
kubectl rollout restart deployment -n kube-system coredns

# Flush DNS cache
sudo systemd-resolve --flush-caches
kubectl delete pod -n kube-system -l k8s-app=kube-dns

# Vérifier configuration DNS
cat /etc/systemd/resolved.conf
kubectl get configmap -n kube-system coredns -o yaml
```

### Firewall Blocking

#### Diagnostic
```bash
# Status UFW
sudo ufw status verbose
sudo ufw show added

# Logs firewall
sudo tail -f /var/log/ufw.log
sudo grep "UFW BLOCK" /var/log/syslog

# Test connectivity
telnet 37.59.98.241 443
nc -zv 37.59.98.241 6443
```

#### Solutions
```bash
# Ouvrir port temporairement
sudo ufw allow from any to any port 80 proto tcp

# Vérifier rules UFW
sudo ufw status numbered
sudo ufw delete [number]

# Reset UFW si nécessaire
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw allow 22,80,443,6443
sudo ufw enable
```

## Procédures d'urgence

### Cluster Unresponsive

#### Steps d'urgence
```bash
# 1. Vérifier node status
kubectl get nodes
# Si pas de réponse -> aller étape SSH directe

# 2. SSH direct sur node
ssh ubuntu@37.59.98.241

# 3. Vérifier K3s
sudo systemctl status k3s
sudo journalctl -u k3s --since "30 minutes ago"

# 4. Restart K3s si nécessaire
sudo systemctl restart k3s

# 5. Vérifier récupération
kubectl get nodes
kubectl get pods -A
```

### Data Recovery

#### Backup procedures
```bash
# Backup etcd (K3s intégré)
sudo cp -r /var/lib/rancher/k3s/server/db/etcd /backup/etcd-$(date +%Y%m%d)

# Backup Prometheus data
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- tar czf /tmp/prometheus-backup.tar.gz /prometheus

# Backup Grafana dashboards
kubectl get configmap -n monitoring -o yaml > grafana-dashboards-backup.yaml
```

#### Recovery procedures
```bash
# Restore etcd
sudo systemctl stop k3s
sudo cp -r /backup/etcd-backup/* /var/lib/rancher/k3s/server/db/etcd/
sudo systemctl start k3s

# Restore from Git (Flux)
flux reconcile source git flux-system --with-source
flux reconcile kustomization apps
```

### Emergency Contacts

#### Escalation matrix
1. **L1 - Self-service**: Documentation, logs, redémarrages
2. **L2 - Admin système**: [contact-admin]
3. **L3 - Provider support**: Nova Clouds support
4. **L4 - Critical outage**: Escalation complète

#### Communication
- **Status page**: [URL status page]
- **Incident channel**: #incidents
- **On-call rotation**: [lien PagerDuty/OpsGenie]

### Runbooks automatisés

#### Scripts utilitaires
```bash
# health-check.sh
#!/bin/bash
echo "=== System Health Check ==="
echo "Node status:"
kubectl get nodes
echo "Pod status:"
kubectl get pods -A | grep -v Running | grep -v Completed
echo "Resource usage:"
kubectl top nodes
kubectl top pods -A --sort-by=cpu | head -10

# quick-restart.sh
#!/bin/bash
APP=$1
echo "Restarting $APP..."
kubectl rollout restart deployment/$APP
kubectl rollout status deployment/$APP --timeout=300s
echo "$APP restarted successfully"

# emergency-scale-down.sh
#!/bin/bash
echo "Emergency scale down non-critical services..."
kubectl scale deployment api-enrichment --replicas=0
kubectl scale deployment monitoring-stack --replicas=0
echo "Scaled down completed"
```

## Monitoring proactif

### Alertes critiques
- Node NotReady > 2 minutes
- Pod CrashLooping > 3 restarts
- Disk usage > 90%
- Memory usage > 95%
- API error rate > 10%

### Health checks automatiques
```bash
# Cron job monitoring
0 */6 * * * /home/ubuntu/scripts/health-check.sh > /var/log/health-check.log 2>&1

# Prometheus health
curl -f http://prometheus:9090/-/healthy || alert

# Application health
curl -f https://api.domain.com/health || alert
```

### Métriques de récupération
- **MTTR** (Mean Time To Recovery): Temps moyen de résolution
- **MTBF** (Mean Time Between Failures): Temps moyen entre pannes
- **Availability**: Pourcentage de disponibilité (SLA)
- **Error budget**: Budget d'erreurs autorisées