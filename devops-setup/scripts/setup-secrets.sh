#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if age key exists
check_age_key() {
    if [ ! -f ~/.sops/age.key ]; then
        log_error "Age key not found. Please run bootstrap.sh first."
        exit 1
    fi
    
    AGE_PUBLIC_KEY=$(cat ~/.sops/age.pub)
    log_info "Using age public key: $AGE_PUBLIC_KEY"
}

# Create SOPS configuration
create_sops_config() {
    log_info "Creating SOPS configuration..."
    
    AGE_PUBLIC_KEY=$(cat ~/.sops/age.pub)
    
    cat > /home/ubuntu/devops-setup/k3s-gitops/.sops.yaml << EOF
creation_rules:
  - path_regex: \.sops\.yaml$
    age: ${AGE_PUBLIC_KEY}
EOF
    
    log_success "SOPS configuration created"
}

# Create Kafka secrets
create_kafka_secrets() {
    log_info "Creating Kafka secrets..."
    
    cd /home/ubuntu/devops-setup/k3s-gitops/security
    
    # Generate random password for Kafka user
    KAFKA_PASSWORD=$(openssl rand -base64 32)
    
    # Create the secret manifest (unencrypted first)
    cat > secret-kafka-temp.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: kafka-credentials
  namespace: default
type: Opaque
stringData:
  username: mercurious-app-user
  password: ${KAFKA_PASSWORD}
---
apiVersion: v1
kind: Secret
metadata:
  name: external-services
  namespace: default
type: Opaque
stringData:
  mongodb-uri: "CHANGE_ME_MONGODB_CONNECTION_STRING"
  redis-uri: "CHANGE_ME_REDIS_CONNECTION_STRING"
EOF
    
    # Encrypt with SOPS
    sops --encrypt secret-kafka-temp.yaml > secret-kafka.sops.yaml
    rm secret-kafka-temp.yaml
    
    log_success "Kafka secrets created and encrypted"
    log_warning "Don't forget to update MongoDB and Redis URIs in secret-kafka.sops.yaml"
}

# Create kustomization for security
create_security_kustomization() {
    log_info "Creating security kustomization..."
    
    cat > /home/ubuntu/devops-setup/k3s-gitops/security/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - secret-kafka.sops.yaml
EOF
    
    log_success "Security kustomization created"
}

main() {
    log_info "Setting up SOPS encrypted secrets..."
    
    check_age_key
    create_sops_config
    create_kafka_secrets
    create_security_kustomization
    
    log_success "Secrets setup completed!"
    echo
    log_info "Next steps:"
    echo "1. Edit k3s-gitops/security/secret-kafka.sops.yaml to update external service URIs"
    echo "2. Use: sops k3s-gitops/security/secret-kafka.sops.yaml"
    echo "3. Update the MongoDB and Redis connection strings"
}

main "$@"