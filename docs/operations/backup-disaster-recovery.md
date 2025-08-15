# Backup et Disaster Recovery - Stratégies de sauvegarde

## Stratégie de backup globale

### Approche 3-2-1
- **3** copies des données critiques
- **2** médias de stockage différents
- **1** copie hors site (géographiquement distante)

### Classification des données

#### Données critiques (RPO: 1h, RTO: 4h)
- **etcd Kubernetes**: Configuration cluster et secrets
- **Prometheus data**: Métriques historiques
- **Grafana dashboards**: Configuration monitoring
- **Flux configuration**: État GitOps

#### Données importantes (RPO: 24h, RTO: 8h)
- **Application logs**: Historique applicatif
- **System logs**: Logs système et audit
- **Monitoring configs**: Alertes et rules

#### Données reconstructibles (RPO: 7j, RTO: 24h)
- **Container images**: Disponibles dans registries
- **OS packages**: Réinstallables
- **Application code**: Disponible dans Git

## Backup des données Kubernetes

### etcd Backup (K3s)

#### Backup automatique
```bash
#!/bin/bash
# /home/ubuntu/scripts/backup-etcd.sh

BACKUP_DIR="/backup/etcd"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/etcd-backup-$DATE"

# Créer répertoire de backup
mkdir -p $BACKUP_DIR

# Arrêter K3s temporairement pour consistance
sudo systemctl stop k3s

# Copier base etcd
sudo cp -r /var/lib/rancher/k3s/server/db/etcd "$BACKUP_PATH"

# Redémarrer K3s
sudo systemctl start k3s

# Vérifier que le cluster fonctionne
sleep 30
kubectl get nodes || echo "ERREUR: Cluster non accessible après backup"

# Compression du backup
tar czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "etcd-backup-$DATE"
rm -rf "$BACKUP_PATH"

# Retention: garder 7 jours
find $BACKUP_DIR -name "etcd-backup-*.tar.gz" -mtime +7 -delete

echo "Backup etcd terminé: $BACKUP_PATH.tar.gz"
```

#### Backup via snapshot API
```bash
#!/bin/bash
# Alternative: backup via API etcd (si exposé)

ETCDCTL_API=3 etcdctl snapshot save /backup/etcd/snapshot-$(date +%Y%m%d_%H%M%S).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key
```

### Backup des secrets chiffrés

#### SOPS Age key backup
```bash
#!/bin/bash
# /home/ubuntu/scripts/backup-sops.sh

BACKUP_DIR="/backup/sops"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup clé Age
cp /home/ubuntu/.sops/age.key "$BACKUP_DIR/age.key.$DATE"

# Backup des secrets chiffrés
cp -r /home/ubuntu/devops-setup/k3s-gitops/security "$BACKUP_DIR/secrets-$DATE"

# Chiffrer le backup de la clé
gpg --cipher-algo AES256 --compress-algo 1 --s2k-cipher-algo AES256 \
    --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65536 \
    --symmetric --output "$BACKUP_DIR/age.key.$DATE.gpg" \
    "$BACKUP_DIR/age.key.$DATE"

# Supprimer clé en clair
rm "$BACKUP_DIR/age.key.$DATE"

echo "Backup SOPS/Age terminé: $BACKUP_DIR"
```

### Backup configuration Flux

#### GitOps state backup
```bash
#!/bin/bash
# /home/ubuntu/scripts/backup-flux.sh

BACKUP_DIR="/backup/flux"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR/$DATE"

# Backup CRDs Flux
kubectl get gitrepositories.source.toolkit.fluxcd.io -A -o yaml > "$BACKUP_DIR/$DATE/gitrepositories.yaml"
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o yaml > "$BACKUP_DIR/$DATE/kustomizations.yaml"
kubectl get helmreleases.helm.toolkit.fluxcd.io -A -o yaml > "$BACKUP_DIR/$DATE/helmreleases.yaml"
kubectl get imagerepositories.image.toolkit.fluxcd.io -A -o yaml > "$BACKUP_DIR/$DATE/imagerepositories.yaml"
kubectl get imagepolicies.image.toolkit.fluxcd.io -A -o yaml > "$BACKUP_DIR/$DATE/imagepolicies.yaml"

# Backup secrets Flux
kubectl get secrets -n flux-system -o yaml > "$BACKUP_DIR/$DATE/flux-secrets.yaml"

# Compression
tar czf "$BACKUP_DIR/flux-config-$DATE.tar.gz" -C "$BACKUP_DIR" "$DATE"
rm -rf "$BACKUP_DIR/$DATE"

echo "Backup Flux terminé: $BACKUP_DIR/flux-config-$DATE.tar.gz"
```

## Backup des données de monitoring

### Prometheus data backup

#### Snapshot-based backup
```bash
#!/bin/bash
# /home/ubuntu/scripts/backup-prometheus.sh

BACKUP_DIR="/backup/prometheus"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Créer snapshot Prometheus
SNAPSHOT_NAME=$(kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot | \
  jq -r '.data.name')

if [ "$SNAPSHOT_NAME" != "null" ]; then
  # Copier snapshot hors du pod
  kubectl cp monitoring/prometheus-kube-prometheus-stack-prometheus-0:/prometheus/snapshots/$SNAPSHOT_NAME \
    "$BACKUP_DIR/prometheus-snapshot-$DATE"
  
  # Compression
  tar czf "$BACKUP_DIR/prometheus-$DATE.tar.gz" -C "$BACKUP_DIR" "prometheus-snapshot-$DATE"
  rm -rf "$BACKUP_DIR/prometheus-snapshot-$DATE"
  
  # Nettoyer snapshot dans Prometheus
  kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
    rm -rf /prometheus/snapshots/$SNAPSHOT_NAME
  
  echo "Backup Prometheus terminé: $BACKUP_DIR/prometheus-$DATE.tar.gz"
else
  echo "ERREUR: Impossible de créer snapshot Prometheus"
  exit 1
fi
```

### Grafana backup

#### Dashboards et datasources
```bash
#!/bin/bash
# /home/ubuntu/scripts/backup-grafana.sh

BACKUP_DIR="/backup/grafana"
DATE=$(date +%Y%m%d_%H%M%S)
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

mkdir -p "$BACKUP_DIR/$DATE"

# Backup base de données Grafana (SQLite)
kubectl cp "monitoring/$GRAFANA_POD:/var/lib/grafana/grafana.db" "$BACKUP_DIR/$DATE/grafana.db"

# Backup configuration
kubectl get configmaps -n monitoring -l app.kubernetes.io/name=grafana -o yaml > "$BACKUP_DIR/$DATE/grafana-config.yaml"
kubectl get secrets -n monitoring -l app.kubernetes.io/name=grafana -o yaml > "$BACKUP_DIR/$DATE/grafana-secrets.yaml"

# Export dashboards via API (si configuré)
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
PF_PID=$!
sleep 5

# Export des dashboards
curl -u admin:$GRAFANA_PASSWORD http://localhost:3000/api/search | jq -r '.[].uid' | while read uid; do
  curl -u admin:$GRAFANA_PASSWORD "http://localhost:3000/api/dashboards/uid/$uid" > "$BACKUP_DIR/$DATE/dashboard-$uid.json"
done

kill $PF_PID

# Compression
tar czf "$BACKUP_DIR/grafana-$DATE.tar.gz" -C "$BACKUP_DIR" "$DATE"
rm -rf "$BACKUP_DIR/$DATE"

echo "Backup Grafana terminé: $BACKUP_DIR/grafana-$DATE.tar.gz"
```

### Loki backup

#### Logs backup
```bash
#!/bin/bash
# /home/ubuntu/scripts/backup-loki.sh

BACKUP_DIR="/backup/loki"
DATE=$(date +%Y%m%d_%H%M%S)
LOKI_POD="loki-0"

mkdir -p $BACKUP_DIR

# Backup données Loki
kubectl cp "monitoring/$LOKI_POD:/loki" "$BACKUP_DIR/loki-data-$DATE"

# Compression
tar czf "$BACKUP_DIR/loki-$DATE.tar.gz" -C "$BACKUP_DIR" "loki-data-$DATE"
rm -rf "$BACKUP_DIR/loki-data-$DATE"

echo "Backup Loki terminé: $BACKUP_DIR/loki-$DATE.tar.gz"
```

## Backup système

### System configuration backup

#### OS et services
```bash
#!/bin/bash
# /home/ubuntu/scripts/backup-system.sh

BACKUP_DIR="/backup/system"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR/$DATE"

# Configuration système critique
sudo cp -r /etc/systemd "$BACKUP_DIR/$DATE/"
sudo cp -r /etc/ufw "$BACKUP_DIR/$DATE/"
sudo cp /etc/fstab "$BACKUP_DIR/$DATE/"
sudo cp /etc/hosts "$BACKUP_DIR/$DATE/"
sudo cp -r /etc/fail2ban "$BACKUP_DIR/$DATE/"

# Configuration réseau
sudo cp -r /etc/systemd/network "$BACKUP_DIR/$DATE/"
sudo cp /etc/systemd/resolved.conf "$BACKUP_DIR/$DATE/"

# Configuration K3s
sudo cp -r /etc/rancher "$BACKUP_DIR/$DATE/" 2>/dev/null || true

# SSH config
cp -r ~/.ssh "$BACKUP_DIR/$DATE/ssh-ubuntu"

# Scripts custom
cp -r /home/ubuntu/scripts "$BACKUP_DIR/$DATE/" 2>/dev/null || true

# Crontabs
sudo crontab -l > "$BACKUP_DIR/$DATE/crontab-root" 2>/dev/null || true
crontab -l > "$BACKUP_DIR/$DATE/crontab-ubuntu" 2>/dev/null || true

# Compression
tar czf "$BACKUP_DIR/system-config-$DATE.tar.gz" -C "$BACKUP_DIR" "$DATE"
sudo rm -rf "$BACKUP_DIR/$DATE"

echo "Backup system terminé: $BACKUP_DIR/system-config-$DATE.tar.gz"
```

### Package list backup
```bash
#!/bin/bash
# /home/ubuntu/scripts/backup-packages.sh

BACKUP_DIR="/backup/system"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Liste packages APT
dpkg --get-selections > "$BACKUP_DIR/packages-$DATE.txt"
apt-mark showmanual > "$BACKUP_DIR/packages-manual-$DATE.txt"

# Snap packages
snap list > "$BACKUP_DIR/snap-packages-$DATE.txt" 2>/dev/null || true

echo "Backup packages terminé: $BACKUP_DIR/packages-$DATE.txt"
```

## Automatisation des backups

### Cron jobs configuration

```bash
# /etc/crontab additions
# Backup etcd quotidien à 2h
0 2 * * * ubuntu /home/ubuntu/scripts/backup-etcd.sh >> /var/log/backup-etcd.log 2>&1

# Backup système hebdomadaire dimanche 3h
0 3 * * 0 ubuntu /home/ubuntu/scripts/backup-system.sh >> /var/log/backup-system.log 2>&1

# Backup monitoring quotidien à 4h
0 4 * * * ubuntu /home/ubuntu/scripts/backup-prometheus.sh >> /var/log/backup-prometheus.log 2>&1
30 4 * * * ubuntu /home/ubuntu/scripts/backup-grafana.sh >> /var/log/backup-grafana.log 2>&1

# Backup Flux quotidien à 1h
0 1 * * * ubuntu /home/ubuntu/scripts/backup-flux.sh >> /var/log/backup-flux.log 2>&1

# Backup SOPS hebdomadaire samedi 5h
0 5 * * 6 ubuntu /home/ubuntu/scripts/backup-sops.sh >> /var/log/backup-sops.log 2>&1

# Nettoyage logs quotidien à 6h
0 6 * * * root find /var/log -name "backup-*.log" -mtime +30 -delete
```

### Script de backup complet
```bash
#!/bin/bash
# /home/ubuntu/scripts/backup-all.sh

LOG_FILE="/var/log/backup-all.log"
DATE=$(date +%Y%m%d_%H%M%S)

echo "=== Backup complet démarré: $DATE ===" >> $LOG_FILE

# Backup dans l'ordre de priorité
/home/ubuntu/scripts/backup-etcd.sh >> $LOG_FILE 2>&1
/home/ubuntu/scripts/backup-flux.sh >> $LOG_FILE 2>&1
/home/ubuntu/scripts/backup-sops.sh >> $LOG_FILE 2>&1
/home/ubuntu/scripts/backup-prometheus.sh >> $LOG_FILE 2>&1
/home/ubuntu/scripts/backup-grafana.sh >> $LOG_FILE 2>&1
/home/ubuntu/scripts/backup-system.sh >> $LOG_FILE 2>&1

echo "=== Backup complet terminé: $(date +%Y%m%d_%H%M%S) ===" >> $LOG_FILE

# Notification (Slack/Discord)
if [ $? -eq 0 ]; then
  echo "✅ Backup complet réussi" # | send-notification.sh
else
  echo "❌ Backup complet échoué" # | send-notification.sh
fi
```

## Stratégies de stockage

### Local storage
**Path**: `/backup/`
**Retention**: 7 jours pour backups quotidiens, 4 semaines pour hebdomadaires
**Chiffrement**: GPG pour données sensibles
**Compression**: gzip/tar.gz standard

### Remote storage (à configurer)

#### S3-compatible storage
```bash
#!/bin/bash
# Script sync vers stockage externe

BACKUP_SOURCE="/backup"
S3_BUCKET="s3://vps-backups"
AWS_PROFILE="backup-profile"

# Sync quotidien vers S3
aws s3 sync $BACKUP_SOURCE $S3_BUCKET --profile $AWS_PROFILE --delete

# Lifecycle policy: 
# - Transition vers IA après 30 jours
# - Transition vers Glacier après 90 jours  
# - Suppression après 365 jours
```

#### rsync vers serveur distant
```bash
#!/bin/bash
# Sync vers serveur backup distant

BACKUP_SOURCE="/backup"
REMOTE_HOST="backup-server.domain.com"
REMOTE_PATH="/srv/backups/vps-6227e9e1"
SSH_KEY="/home/ubuntu/.ssh/backup-key"

rsync -avz --delete \
  -e "ssh -i $SSH_KEY" \
  $BACKUP_SOURCE/ \
  backup-user@$REMOTE_HOST:$REMOTE_PATH/
```

## Procédures de recovery

### Recovery etcd/Kubernetes

#### Restauration complète cluster
```bash
#!/bin/bash
# /home/ubuntu/scripts/restore-etcd.sh

BACKUP_FILE="$1"
if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 /backup/etcd/etcd-backup-YYYYMMDD_HHMMSS.tar.gz"
  exit 1
fi

echo "⚠️ ATTENTION: Restoration va arrêter le cluster Kubernetes"
read -p "Continuer? (y/N): " confirm
if [ "$confirm" != "y" ]; then
  exit 0
fi

# Arrêter K3s
sudo systemctl stop k3s

# Backup current state
sudo mv /var/lib/rancher/k3s/server/db/etcd /var/lib/rancher/k3s/server/db/etcd.backup.$(date +%s)

# Extraire backup
TEMP_DIR=$(mktemp -d)
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"
sudo mv "$TEMP_DIR"/* /var/lib/rancher/k3s/server/db/etcd

# Redémarrer K3s
sudo systemctl start k3s

# Vérifier recovery
sleep 30
kubectl get nodes
if [ $? -eq 0 ]; then
  echo "✅ Recovery réussie"
else
  echo "❌ Recovery échouée - vérifier logs: journalctl -u k3s"
fi

rm -rf "$TEMP_DIR"
```

### Recovery applications via GitOps

#### Restauration via Flux
```bash
#!/bin/bash
# Recovery automatique via GitOps

echo "Recovery des applications via Flux GitOps..."

# Force reconciliation complète
flux reconcile source git flux-system --with-source
flux reconcile kustomization apps
flux reconcile kustomization infra

# Vérifier deployments
kubectl get deployments -A
kubectl get pods -A

echo "Recovery GitOps terminée"
```

#### Recovery manuel applications
```bash
#!/bin/bash
# Recovery manuel si GitOps indisponible

# Redéployer applications critiques
kubectl apply -f /backup/manifests/api-gateway.yaml
kubectl apply -f /backup/manifests/api-generation.yaml
kubectl apply -f /backup/manifests/api-enrichment.yaml

# Attendre readiness
kubectl wait --for=condition=available deployment/api-gateway --timeout=300s
kubectl wait --for=condition=available deployment/api-generation --timeout=300s
kubectl wait --for=condition=available deployment/api-enrichment --timeout=300s
```

### Recovery monitoring stack

#### Prometheus restoration
```bash
#!/bin/bash
# restore-prometheus.sh

BACKUP_FILE="$1"
PROMETHEUS_POD="prometheus-kube-prometheus-stack-prometheus-0"

# Extraire backup
TEMP_DIR=$(mktemp -d)
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Arrêter Prometheus
kubectl scale statefulset -n monitoring kube-prometheus-stack-prometheus --replicas=0

# Attendre arrêt complet
kubectl wait --for=delete pod/$PROMETHEUS_POD -n monitoring --timeout=300s

# Copier données
kubectl cp "$TEMP_DIR/" monitoring/$PROMETHEUS_POD:/prometheus/ --no-preserve=true

# Redémarrer Prometheus
kubectl scale statefulset -n monitoring kube-prometheus-stack-prometheus --replicas=1

rm -rf "$TEMP_DIR"
echo "Prometheus restauré"
```

## Tests de recovery

### Drill procedures

#### Test recovery mensuel
```bash
#!/bin/bash
# /home/ubuntu/scripts/test-recovery.sh

echo "=== TEST DE RECOVERY - $(date) ==="

# 1. Backup état actuel
./backup-all.sh

# 2. Test restore sur namespace test
kubectl create namespace recovery-test

# 3. Deploy application test
kubectl apply -n recovery-test -f test-app.yaml

# 4. Simuler panne
kubectl delete deployment -n recovery-test test-app

# 5. Test recovery
kubectl apply -n recovery-test -f test-app.yaml
kubectl wait --for=condition=available deployment/test-app -n recovery-test --timeout=300s

# 6. Cleanup
kubectl delete namespace recovery-test

echo "✅ Test recovery réussi"
```

### RTO/RPO Monitoring

#### Métriques recovery
```promql
# Recovery Time Objective tracking
backup_duration_seconds{job="backup-etcd"}
restore_duration_seconds{job="restore-etcd"}

# Recovery Point Objective tracking  
time() - backup_last_success_timestamp{job="backup-etcd"}
```

### Documentation incidents

#### Template incident report
```markdown
# Incident Report - [Date]

## Résumé
- **Date/Heure**: 
- **Durée**: 
- **Impact**: 
- **Root cause**: 

## Timeline
- **[Heure]**: Détection
- **[Heure]**: Investigation
- **[Heure]**: Recovery initié
- **[Heure]**: Service restauré

## Recovery utilisé
- **Backup**: [fichier/date]
- **Méthode**: [procédure utilisée]
- **Données perdues**: [RPO réel]
- **Temps total**: [RTO réel]

## Actions post-incident
- [ ] Amélioration backup
- [ ] Test procédures
- [ ] Mise à jour documentation
```