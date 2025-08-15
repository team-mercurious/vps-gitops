# Structure des Secrets (SANS LES VALEURS)

## Secrets dans le namespace `default`:

### kafka-credentials (Opaque)
- username: [SECRET]
- password: [SECRET]

### api-keys (Opaque) 
- openai-api-key: [SECRET]
- google-places-api-key: [SECRET]
- google-client-id: [SECRET] 
- google-client-secret: [SECRET]
- openweather-api-key: [SECRET]
- better-auth-secret: [SECRET]

### external-services (Opaque)
- mongodb-uri: [SECRET]
- redis-uri: [SECRET]

### api-gateway-tls (kubernetes.io/tls)
- tls.crt: [CERTIFICATE]
- tls.key: [PRIVATE_KEY]

### api-gateway-auth (Opaque)
- 4 clés de configuration

### api-gateway-config (Opaque) 
- 7 clés de configuration

### ghcr-pull-secret (kubernetes.io/dockerconfigjson)
- .dockerconfigjson: [DOCKER_CONFIG]

### resend-secret (Opaque)
- 1 clé de configuration

## ConfigMaps publiques dans le namespace `default`:

### microservices-config
Voir le fichier `../applications/microservices-config.yaml` pour les valeurs complètes.

## Secrets critiques à sauvegarder:
- `/home/ubuntu/.sops/age.key` (clé privée SOPS)
- `/home/ubuntu/.kube/config` (accès cluster)
- Token GitHub pour GitOps