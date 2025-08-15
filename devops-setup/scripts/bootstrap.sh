#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
K3S_VERSION="v1.28.5+k3s1"
HELM_VERSION="v3.13.3"
FLUX_VERSION="v2.2.2"
SOPS_VERSION="v3.8.1"
AGE_VERSION="v1.1.1"

# GitHub configuration
GITHUB_USER="team-mercurious"
GITHUB_TOKEN="${GITHUB_TOKEN}"
GITOPS_REPO="k3s-gitops"

# Domains (adapt according to your domain)
DOMAIN="vps.local"  # Change this to your actual domain
GRAFANA_DOMAIN="grafana.${DOMAIN}"
TRAEFIK_DOMAIN="traefik.${DOMAIN}"

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Update OS and install security tools
setup_os() {
    log_info "Updating OS and installing security tools..."
    
    sudo apt update && sudo apt upgrade -y
    
    # Install essential packages
    sudo apt install -y curl wget unzip jq git fail2ban ufw unattended-upgrades
    
    # Configure UFW
    sudo ufw --force enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 6443/tcp  # K3s API server
    
    # Configure unattended-upgrades
    sudo dpkg-reconfigure -plow unattended-upgrades
    
    log_success "OS setup completed"
}

# Install K3s
install_k3s() {
    log_info "Installing K3s..."
    
    # Install K3s with Traefik disabled (we'll use the embedded one but configure it)
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3S_VERSION} K3S_KUBECONFIG_MODE=644 sh -
    
    # Wait for K3s to be ready
    log_info "Waiting for K3s to be ready..."
    sleep 30
    
    # Setup kubeconfig for current user
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    export KUBECONFIG=~/.kube/config
    
    # Verify installation
    kubectl get nodes
    kubectl get pods -A
    
    log_success "K3s installation completed"
}

# Install Helm
install_helm() {
    log_info "Installing Helm..."
    
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    HELM_INSTALL_DIR=/usr/local/bin ./get_helm.sh --version ${HELM_VERSION}
    rm get_helm.sh
    
    # Add common Helm repositories
    helm repo add jetstack https://charts.jetstack.io
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add traefik https://helm.traefik.io/traefik
    helm repo update
    
    log_success "Helm installation completed"
}

# Install FluxCD CLI
install_flux() {
    log_info "Installing FluxCD CLI..."
    
    curl -s https://fluxcd.io/install.sh | sudo bash -s ${FLUX_VERSION}
    
    log_success "FluxCD CLI installation completed"
}

# Install SOPS
install_sops() {
    log_info "Installing SOPS..."
    
    wget -O sops https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64
    chmod +x sops
    sudo mv sops /usr/local/bin/
    
    log_success "SOPS installation completed"
}

# Install age
install_age() {
    log_info "Installing age..."
    
    wget -O age.tar.gz https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-amd64.tar.gz
    tar xzf age.tar.gz
    sudo mv age/age* /usr/local/bin/
    rm -rf age age.tar.gz
    
    log_success "age installation completed"
}

# Generate age key for SOPS
generate_age_key() {
    log_info "Generating age key for SOPS..."
    
    mkdir -p ~/.sops
    age-keygen -o ~/.sops/age.key
    
    # Get the public key for later use
    AGE_PUBLIC_KEY=$(grep "public key:" ~/.sops/age.key | awk '{print $4}')
    echo "Age public key: $AGE_PUBLIC_KEY"
    echo "$AGE_PUBLIC_KEY" > ~/.sops/age.pub
    
    log_success "Age key generated"
}

# Install cert-manager
install_cert_manager() {
    log_info "Installing cert-manager..."
    
    # Install cert-manager CRDs
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.crds.yaml
    
    # Create namespace
    kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
    
    # Install cert-manager using Helm
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --version v1.13.3 \
        --set installCRDs=false
    
    # Wait for cert-manager to be ready
    kubectl wait --namespace cert-manager \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/instance=cert-manager \
        --timeout=300s
    
    log_success "cert-manager installation completed"
}

# Install monitoring stack
install_monitoring() {
    log_info "Installing monitoring stack (Prometheus + Grafana)..."
    
    # Create namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install kube-prometheus-stack
    helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.retention=30d \
        --set grafana.persistence.enabled=true \
        --set grafana.persistence.size=10Gi \
        --set alertmanager.persistence.enabled=true \
        --set alertmanager.persistence.size=5Gi \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
    
    log_info "Installing Loki and Promtail..."
    
    # Install Loki
    helm install loki grafana/loki \
        --namespace monitoring \
        --set loki.persistence.enabled=true \
        --set loki.persistence.size=20Gi
    
    # Install Promtail
    helm install promtail grafana/promtail \
        --namespace monitoring \
        --set config.lokiAddress=http://loki:3100/loki/api/v1/push
    
    log_success "Monitoring stack installation completed"
}

# Install Kafka
install_kafka() {
    log_info "Installing Kafka..."
    
    # Create namespace
    kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
    
    # Add Strimzi operator Helm repo
    helm repo add strimzi https://strimzi.io/charts/
    helm repo update
    
    # Install Strimzi Kafka operator
    helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
        --namespace kafka \
        --set watchAnyNamespace=true
    
    # Wait for the operator to be ready
    kubectl wait --namespace kafka \
        --for=condition=ready pod \
        --selector=name=strimzi-cluster-operator \
        --timeout=300s
    
    log_success "Kafka operator installation completed"
}

# Setup GitOps repository
setup_gitops_repo() {
    log_info "Setting up GitOps repository..."
    
    cd /home/ubuntu/devops-setup
    
    # Clone the current setup to create the GitOps repo structure
    if [ ! -d "k3s-gitops/.git" ]; then
        git init k3s-gitops
        cd k3s-gitops
        git config user.email "devops@mercurious.team"
        git config user.name "DevOps Bot"
        
        # Create initial commit
        touch README.md
        git add .
        git commit -m "Initial commit: GitOps repository structure"
        
        # Add remote and push
        git remote add origin https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITOPS_REPO}.git
        git branch -M main
        
        cd ..
    fi
    
    log_success "GitOps repository setup completed"
}

# Bootstrap FluxCD
bootstrap_flux() {
    log_info "Bootstrapping FluxCD..."
    
    export GITHUB_TOKEN=${GITHUB_TOKEN}
    
    flux bootstrap github \
        --owner=${GITHUB_USER} \
        --repository=${GITOPS_REPO} \
        --branch=main \
        --path=./clusters/vps \
        --personal \
        --components-extra=image-reflector-controller,image-automation-controller
    
    log_success "FluxCD bootstrap completed"
}

# Display information
display_info() {
    log_success "=== Installation completed successfully! ==="
    echo
    log_info "Cluster Information:"
    kubectl get nodes -o wide
    echo
    log_info "Installed Helm releases:"
    helm list -A
    echo
    log_info "Key endpoints (configure DNS or use port-forward):"
    echo "  Grafana: https://${GRAFANA_DOMAIN}"
    echo "  Traefik Dashboard: https://${TRAEFIK_DOMAIN}"
    echo
    log_info "Grafana credentials:"
    echo "  Username: admin"
    GRAFANA_PASSWORD=$(kubectl get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
    echo "  Password: $GRAFANA_PASSWORD"
    echo
    log_info "Age public key for SOPS:"
    cat ~/.sops/age.pub
    echo
    log_info "Next steps:"
    echo "  1. Configure your DNS to point to this server"
    echo "  2. Update domain configuration in the GitOps manifests"
    echo "  3. Push application manifests to the GitOps repository"
    echo "  4. FluxCD will automatically deploy applications"
    echo
    log_warning "Don't forget to:"
    echo "  - Backup the age private key: ~/.sops/age.key"
    echo "  - Configure monitoring alerts"
    echo "  - Setup log retention policies"
}

# Main execution
main() {
    log_info "Starting DevOps infrastructure bootstrap..."
    echo
    
    check_root
    setup_os
    install_k3s
    install_helm
    install_flux
    install_sops
    install_age
    generate_age_key
    install_cert_manager
    install_monitoring
    install_kafka
    setup_gitops_repo
    bootstrap_flux
    
    display_info
}

# Run main function
main "$@"