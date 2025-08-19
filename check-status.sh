#!/bin/bash

# Script de monitoring des déploiements

echo "🚀 État des déploiements - $(date)"
echo "============================================"

echo ""
echo "📊 Images déployées:"
kubectl get deployments -o custom-columns=SERVICE:.metadata.name,IMAGE:.spec.template.spec.containers[0].image --no-headers

echo ""
echo "🟢 État des pods:"
kubectl get pods -l "app in (api-gateway,api-enrichment,api-generation)" --no-headers

echo ""
echo "📈 Dernières détections Flux:"
kubectl get imagepolicies -n flux-system --no-headers

echo ""
echo "📝 Derniers logs auto-deploy:"
tail -10 /home/ubuntu/auto-deploy.log 2>/dev/null || echo "Pas de logs encore"

echo ""
echo "⏰ Prochaine exécution cron: $(date -d '+5 minutes' '+%H:%M:%S')"