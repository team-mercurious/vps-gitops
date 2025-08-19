#!/bin/bash

# Script de déploiement automatique simplifié
# Utilise directement les ImagePolicies de Flux pour détecter les nouveaux SHA

LOG_FILE="/home/ubuntu/auto-deploy.log"
SERVICES=("api-gateway" "api-enrichment" "api-generation")

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction pour obtenir la dernière image complète détectée par Flux
get_flux_latest_image() {
    local service=$1
    kubectl get imagepolicies -n flux-system "$service" -o jsonpath='{.status.latestImage}' 2>/dev/null
}

# Fonction pour obtenir l'image actuellement déployée
get_current_image() {
    local service=$1
    kubectl get deployment "$service" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null
}

# Fonction pour déployer une nouvelle image
deploy_service() {
    local service=$1
    local new_image=$2
    
    log "🚀 Déploiement de $service vers $new_image"
    
    # Mettre à jour le déploiement
    if kubectl set image "deployment/$service" "$service=$new_image"; then
        log "✅ Image mise à jour pour $service"
        
        # Attendre le déploiement (timeout 5min)
        if kubectl rollout status "deployment/$service" --timeout=300s >/dev/null 2>&1; then
            log "✅ Déploiement réussi: $service"
            return 0
        else
            log "❌ Timeout ou échec du déploiement: $service"
            return 1
        fi
    else
        log "❌ Échec mise à jour image: $service"
        return 1
    fi
}

# Fonction principale
main() {
    log "🚀 Démarrage auto-deploy"
    
    # Forcer la synchronisation Flux d'abord
    log "🔄 Synchronisation Flux..."
    flux reconcile image repository api-gateway >/dev/null 2>&1 &
    flux reconcile image repository api-enrichment >/dev/null 2>&1 &  
    flux reconcile image repository api-generation >/dev/null 2>&1 &
    wait
    
    local updated=0
    
    for service in "${SERVICES[@]}"; do
        log "🔍 Vérification $service..."
        
        # Obtenir la dernière image complète Flux
        local flux_image=$(get_flux_latest_image "$service")
        if [[ -z "$flux_image" ]]; then
            log "⚠️  Pas d'image Flux pour $service"
            continue
        fi
        
        # Obtenir l'image actuelle
        local current_image=$(get_current_image "$service")
        if [[ -z "$current_image" ]]; then
            log "⚠️  Service $service introuvable"
            continue
        fi
        
        log "📊 $service: actuel=$current_image"
        log "📊 $service: flux=$flux_image"
        
        # Si différent, déployer
        if [[ "$current_image" != "$flux_image" ]]; then
            log "🆕 Mise à jour détectée pour $service"
            
            if deploy_service "$service" "$flux_image"; then
                updated=$((updated + 1))
                log "🎉 $service mis à jour avec succès"
            else
                log "💥 Échec mise à jour $service"
            fi
        else
            log "✅ $service à jour"
        fi
        
        sleep 1
    done
    
    if [[ $updated -gt 0 ]]; then
        log "🎯 Terminé: $updated services mis à jour"
        
        # Vérifier la santé des services
        log "🏥 Vérification santé services..."
        sleep 10
        kubectl get pods -l "app in (api-gateway,api-enrichment,api-generation)" --no-headers | while read line; do
            echo "$line" | tee -a "$LOG_FILE"
        done
        
    else
        log "💤 Aucune mise à jour nécessaire"
    fi
}

# Vérifications
if ! command -v kubectl >/dev/null 2>&1; then
    log "❌ kubectl manquant"
    exit 1
fi

if ! command -v flux >/dev/null 2>&1; then
    log "⚠️  flux CLI manquant"
fi

# Exécution
main