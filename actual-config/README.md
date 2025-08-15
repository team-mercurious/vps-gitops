# Configuration Actuelle du VPS (ARCHIVE FONCTIONNELLE)

Ce répertoire contient une copie exacte de toutes les configurations qui fonctionnent actuellement sur le VPS.

**⚠️ ATTENTION :** Ces fichiers sont une ARCHIVE en lecture seule de la configuration qui fonctionne. 
Ne pas modifier le VPS basé sur ces fichiers - ils sont pour référence et sauvegarde uniquement.

## Structure

- `k3s/` - Configuration complète du cluster K3s
- `kafka/` - Configuration complète du cluster Kafka 
- `applications/` - Déploiements des microservices
- `system/` - Configuration système (services, firewall)
- `secrets/` - Structure des secrets (sans les valeurs sensibles)
- `monitoring/` - Configuration complète du monitoring

## Version figée le : 2025-08-15 08:00 UTC

## Cluster Status au moment de l'archive :
- K3s v1.28.5+k3s1 - FONCTIONNEL ✅
- Kafka 3.7.0 avec Strimzi - FONCTIONNEL ✅  
- 3 Microservices déployés - FONCTIONNEL ✅
- Monitoring Grafana/Prometheus - FONCTIONNEL ✅
- GitOps Flux v2.2.2 - FONCTIONNEL ✅
- Ingress SSL avec Let's Encrypt - FONCTIONNEL ✅