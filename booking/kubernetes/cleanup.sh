#!/bin/bash

# Flight Booking System - Kubernetes Cleanup Script
# This script removes all deployed resources

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="booking-system"
KUBECTL="kubectl"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn "⚠️  WARNING: This will DELETE all resources in the $NAMESPACE namespace!"
log_warn "This includes:"
log_warn "  - All microservices"
log_warn "  - All databases (PostgreSQL, Redis, MongoDB, RabbitMQ)"
log_warn "  - All persistent data"
log_warn "  - ConfigMaps and Secrets"
echo ""
read -p "Are you absolutely sure you want to continue? (type 'DELETE' to confirm): " confirm

if [ "$confirm" != "DELETE" ]; then
    log_info "Cleanup cancelled."
    exit 0
fi

echo ""
read -p "Do you also want to delete the monitoring stack? (yes/no): " delete_monitoring

# Delete application resources
log_info "Deleting application deployments..."
$KUBECTL delete -f user-service.yaml --ignore-not-found=true
$KUBECTL delete -f search-service.yaml --ignore-not-found=true
$KUBECTL delete -f booking-service.yaml --ignore-not-found=true
$KUBECTL delete -f other-services.yaml --ignore-not-found=true

log_info "Deleting ingress..."
$KUBECTL delete -f ingress.yaml --ignore-not-found=true

log_info "Deleting databases..."
$KUBECTL delete -f postgres-statefulset.yaml --ignore-not-found=true
$KUBECTL delete -f redis-statefulset.yaml --ignore-not-found=true
$KUBECTL delete -f mongodb-statefulset.yaml --ignore-not-found=true
$KUBECTL delete -f rabbitmq-statefulset.yaml --ignore-not-found=true

log_info "Deleting ConfigMaps and Secrets..."
$KUBECTL delete -f configmaps.yaml --ignore-not-found=true
$KUBECTL delete -f secrets.yaml --ignore-not-found=true

log_info "Deleting PersistentVolumeClaims..."
$KUBECTL delete pvc --all -n $NAMESPACE

log_info "Deleting namespace..."
$KUBECTL delete -f namespace.yaml --ignore-not-found=true

# Delete monitoring stack if requested
if [ "$delete_monitoring" = "yes" ]; then
    log_info "Deleting monitoring stack..."
    if command -v helm &> /dev/null; then
        helm uninstall prometheus -n monitoring --ignore-not-found 2>/dev/null || true
        $KUBECTL delete namespace monitoring --ignore-not-found=true
    fi
fi

log_info "Cleanup completed! ✨"
log_info "All resources have been removed."
