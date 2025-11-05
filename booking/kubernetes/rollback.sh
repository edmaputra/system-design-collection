#!/bin/bash

# Flight Booking System - Kubernetes Rollback Script
# This script helps rollback deployments to previous versions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# List all deployments
log_info "Available deployments in $NAMESPACE:"
$KUBECTL get deployments -n $NAMESPACE

echo ""
echo "Select a deployment to rollback:"
echo "1) user-service"
echo "2) search-service"
echo "3) booking-service"
echo "4) payment-service"
echo "5) notification-service"
echo "6) review-service"
echo "7) All services"
echo "8) Cancel"
read -p "Enter your choice (1-8): " choice

case $choice in
    1) DEPLOYMENT="user-service" ;;
    2) DEPLOYMENT="search-service" ;;
    3) DEPLOYMENT="booking-service" ;;
    4) DEPLOYMENT="payment-service" ;;
    5) DEPLOYMENT="notification-service" ;;
    6) DEPLOYMENT="review-service" ;;
    7) DEPLOYMENT="all" ;;
    8) log_info "Cancelled."; exit 0 ;;
    *) log_error "Invalid choice"; exit 1 ;;
esac

rollback_deployment() {
    local deployment=$1
    
    log_info "Rollout history for $deployment:"
    $KUBECTL rollout history deployment/$deployment -n $NAMESPACE
    
    echo ""
    read -p "Enter revision number to rollback to (or 'previous' for last revision): " revision
    
    if [ "$revision" = "previous" ]; then
        log_info "Rolling back $deployment to previous version..."
        $KUBECTL rollout undo deployment/$deployment -n $NAMESPACE
    else
        log_info "Rolling back $deployment to revision $revision..."
        $KUBECTL rollout undo deployment/$deployment --to-revision=$revision -n $NAMESPACE
    fi
    
    log_info "Waiting for rollout to complete..."
    $KUBECTL rollout status deployment/$deployment -n $NAMESPACE
    
    log_info "Rollback completed for $deployment"
}

if [ "$DEPLOYMENT" = "all" ]; then
    log_warn "This will rollback ALL services to their previous versions!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Cancelled."
        exit 0
    fi
    
    for service in user-service search-service booking-service payment-service notification-service review-service; do
        log_info "Rolling back $service..."
        $KUBECTL rollout undo deployment/$service -n $NAMESPACE
    done
    
    log_info "Waiting for all rollouts to complete..."
    for service in user-service search-service booking-service payment-service notification-service review-service; do
        $KUBECTL rollout status deployment/$service -n $NAMESPACE
    done
else
    rollback_deployment $DEPLOYMENT
fi

log_info "Rollback completed successfully! 🎉"
log_info "Current pod status:"
$KUBECTL get pods -n $NAMESPACE
