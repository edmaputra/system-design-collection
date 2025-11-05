#!/bin/bash

# Flight Booking System - Kubernetes Deployment Script
# This script deploys the entire application stack to Kubernetes

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="booking-system"
KUBECTL="kubectl"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

wait_for_pods() {
    local label=$1
    local timeout=${2:-300}
    
    log_info "Waiting for pods with label $label to be ready..."
    $KUBECTL wait --for=condition=ready pod \
        -l "$label" \
        -n $NAMESPACE \
        --timeout=${timeout}s || {
        log_error "Pods with label $label did not become ready in time"
        return 1
    }
}

# Check if kubectl is installed
if ! command -v $KUBECTL &> /dev/null; then
    log_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check cluster connectivity
log_info "Checking cluster connectivity..."
if ! $KUBECTL cluster-info &> /dev/null; then
    log_error "Unable to connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

log_info "Connected to cluster: $($KUBECTL config current-context)"

# Create namespace
log_info "Creating namespace..."
$KUBECTL apply -f namespace.yaml

# Create storage class
log_info "Creating storage class..."
$KUBECTL apply -f storage-class.yaml

# Create ConfigMaps
log_info "Creating ConfigMaps..."
$KUBECTL apply -f configmaps.yaml

# Create Secrets
log_info "Creating Secrets..."
log_warn "Make sure you've updated secrets.yaml with actual values!"
read -p "Have you updated the secrets.yaml file? (yes/no): " answer
if [ "$answer" != "yes" ]; then
    log_error "Please update secrets.yaml before deploying."
    exit 1
fi
$KUBECTL apply -f secrets.yaml

# Deploy databases (StatefulSets)
log_info "Deploying PostgreSQL..."
$KUBECTL apply -f postgres-statefulset.yaml
sleep 10

log_info "Deploying Redis..."
$KUBECTL apply -f redis-statefulset.yaml
sleep 10

log_info "Deploying MongoDB..."
$KUBECTL apply -f mongodb-statefulset.yaml
sleep 10

log_info "Deploying RabbitMQ..."
$KUBECTL apply -f rabbitmq-statefulset.yaml
sleep 10

# Wait for databases to be ready
log_info "Waiting for databases to be ready (this may take several minutes)..."
wait_for_pods "app=postgres" 600
wait_for_pods "app=redis" 300
wait_for_pods "app=mongodb" 300
wait_for_pods "app=rabbitmq" 300

log_info "All databases are ready!"

# Deploy microservices
log_info "Deploying microservices..."
$KUBECTL apply -f user-service.yaml
$KUBECTL apply -f search-service.yaml
$KUBECTL apply -f booking-service.yaml
$KUBECTL apply -f other-services.yaml

# Wait for services to be ready
log_info "Waiting for services to be ready..."
sleep 20
wait_for_pods "tier=backend" 300

# Install NGINX Ingress Controller (if not already installed)
log_info "Checking for NGINX Ingress Controller..."
if ! $KUBECTL get namespace ingress-nginx &> /dev/null; then
    log_info "Installing NGINX Ingress Controller..."
    $KUBECTL apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    
    log_info "Waiting for Ingress Controller to be ready..."
    sleep 30
    wait_for_pods "app.kubernetes.io/name=ingress-nginx" 300
else
    log_info "NGINX Ingress Controller already installed"
fi

# Install cert-manager (if not already installed)
log_info "Checking for cert-manager..."
if ! $KUBECTL get namespace cert-manager &> /dev/null; then
    log_info "Installing cert-manager..."
    $KUBECTL apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    log_info "Waiting for cert-manager to be ready..."
    sleep 30
    $KUBECTL wait --for=condition=ready pod \
        -l app.kubernetes.io/instance=cert-manager \
        -n cert-manager \
        --timeout=300s
else
    log_info "cert-manager already installed"
fi

# Deploy Ingress
log_info "Deploying Ingress..."
$KUBECTL apply -f ingress.yaml

# Deploy monitoring (optional)
read -p "Do you want to deploy the monitoring stack (Prometheus, Grafana)? (yes/no): " deploy_monitoring
if [ "$deploy_monitoring" = "yes" ]; then
    log_info "Installing Prometheus and Grafana..."
    
    # Add Helm repo if not exists
    if command -v helm &> /dev/null; then
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        
        helm install prometheus prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --create-namespace \
            --set prometheus.prometheusSpec.retention=30d \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=fast-ssd \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=100Gi \
            --set grafana.adminPassword=admin123 \
            --set grafana.persistence.enabled=true \
            --set grafana.persistence.storageClassName=fast-ssd \
            --set grafana.persistence.size=10Gi
        
        log_info "Applying ServiceMonitors..."
        $KUBECTL apply -f monitoring.yaml
    else
        log_warn "Helm is not installed. Skipping monitoring stack installation."
        log_warn "Install Helm from https://helm.sh/docs/intro/install/"
    fi
fi

# Display deployment status
log_info "Deployment completed! Here's the status:"
echo ""
echo "=== PODS ==="
$KUBECTL get pods -n $NAMESPACE
echo ""
echo "=== SERVICES ==="
$KUBECTL get svc -n $NAMESPACE
echo ""
echo "=== INGRESS ==="
$KUBECTL get ingress -n $NAMESPACE
echo ""

# Get Ingress IP/Hostname
log_info "Getting Ingress external IP/Hostname..."
INGRESS_IP=$($KUBECTL get ingress flight-booking-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
INGRESS_HOSTNAME=$($KUBECTL get ingress flight-booking-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -n "$INGRESS_IP" ]; then
    log_info "Ingress IP: $INGRESS_IP"
    log_info "Add this to your DNS: api.flightbooking.com -> $INGRESS_IP"
elif [ -n "$INGRESS_HOSTNAME" ]; then
    log_info "Ingress Hostname: $INGRESS_HOSTNAME"
    log_info "Add this CNAME to your DNS: api.flightbooking.com -> $INGRESS_HOSTNAME"
else
    log_warn "Ingress IP/Hostname not yet assigned. Run 'kubectl get ingress -n $NAMESPACE' to check later."
fi

# Get monitoring URLs
if [ "$deploy_monitoring" = "yes" ]; then
    echo ""
    log_info "Monitoring access:"
    log_info "Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    log_info "Then open: http://localhost:3000 (admin/admin123)"
    log_info "Prometheus: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
fi

echo ""
log_info "Deployment successful! 🎉"
log_info "To check the status: kubectl get all -n $NAMESPACE"
log_info "To view logs: kubectl logs -f <pod-name> -n $NAMESPACE"
log_info "To scale a service: kubectl scale deployment/<service-name> --replicas=<count> -n $NAMESPACE"
