# Flight Booking System - Kubernetes Manifests

This directory contains all Kubernetes manifests and scripts to deploy the flight booking microservices system.

## 📁 File Structure

```
kubernetes/
├── namespace.yaml                  # Namespace definition
├── configmaps.yaml                 # Application configuration
├── secrets.yaml                    # Sensitive data (CHANGE BEFORE DEPLOY!)
├── storage-class.yaml              # Storage classes for persistent volumes
├── postgres-statefulset.yaml       # PostgreSQL database
├── redis-statefulset.yaml          # Redis cache
├── mongodb-statefulset.yaml        # MongoDB for notifications
├── rabbitmq-statefulset.yaml       # RabbitMQ message queue
├── user-service.yaml               # User service deployment + HPA
├── search-service.yaml             # Search service deployment + HPA
├── booking-service.yaml            # Booking service deployment + HPA
├── other-services.yaml             # Payment, Notification, Review services
├── ingress.yaml                    # NGINX Ingress + TLS configuration
├── monitoring.yaml                 # Prometheus, Grafana setup
├── deploy.sh                       # Automated deployment script
├── rollback.sh                     # Rollback deployments
├── cleanup.sh                      # Delete all resources
└── README.md                       # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Kubernetes Cluster** (GKE, EKS, AKS, or local)
2. **kubectl** configured to access your cluster
3. **Helm 3** (for monitoring stack - optional)
4. **Docker images** pushed to a container registry

### Step 1: Update Configuration

Before deploying, you MUST update the following files:

#### 1. **secrets.yaml**
Replace all `CHANGE_ME_` values with actual secrets:
```bash
# Edit the file
nano secrets.yaml

# Or create secrets from command line
kubectl create secret generic postgres-secret \
  --from-literal=username=booking_admin \
  --from-literal=password=YOUR_STRONG_PASSWORD \
  -n booking-system
```

#### 2. **Update Docker Image References**
In all service YAML files, replace `gcr.io/YOUR_PROJECT/` with your actual registry:
```bash
# For GKE
gcr.io/my-project-id/user-service:latest

# For AWS ECR
123456789.dkr.ecr.us-east-1.amazonaws.com/user-service:latest

# For Docker Hub
myusername/user-service:latest
```

#### 3. **Update Ingress Hostname**
In `ingress.yaml`, change the hostname:
```yaml
- host: api.flightbooking.com  # Change to your domain
```

### Step 2: Deploy Using Script

The easiest way to deploy:

```bash
# Make scripts executable
chmod +x deploy.sh rollback.sh cleanup.sh

# Run deployment
./deploy.sh
```

The script will:
1. ✅ Create namespace
2. ✅ Deploy ConfigMaps and Secrets
3. ✅ Deploy databases (PostgreSQL, Redis, MongoDB, RabbitMQ)
4. ✅ Wait for databases to be ready
5. ✅ Deploy microservices
6. ✅ Install NGINX Ingress Controller
7. ✅ Install cert-manager for TLS
8. ✅ Deploy Ingress
9. ✅ Optionally install monitoring stack

### Step 3: Manual Deployment (Alternative)

If you prefer manual control:

```bash
# 1. Create namespace
kubectl apply -f namespace.yaml

# 2. Create storage class
kubectl apply -f storage-class.yaml

# 3. Create ConfigMaps
kubectl apply -f configmaps.yaml

# 4. Create Secrets (UPDATE FIRST!)
kubectl apply -f secrets.yaml

# 5. Deploy databases
kubectl apply -f postgres-statefulset.yaml
kubectl apply -f redis-statefulset.yaml
kubectl apply -f mongodb-statefulset.yaml
kubectl apply -f rabbitmq-statefulset.yaml

# 6. Wait for databases (check with kubectl get pods -n booking-system)
kubectl wait --for=condition=ready pod -l app=postgres -n booking-system --timeout=600s

# 7. Deploy services
kubectl apply -f user-service.yaml
kubectl apply -f search-service.yaml
kubectl apply -f booking-service.yaml
kubectl apply -f other-services.yaml

# 8. Deploy ingress
kubectl apply -f ingress.yaml
```

## 📊 Verify Deployment

### Check All Resources
```bash
kubectl get all -n booking-system
```

### Check Pods Status
```bash
kubectl get pods -n booking-system -w
```

### Check Services
```bash
kubectl get svc -n booking-system
```

### Check Ingress
```bash
kubectl get ingress -n booking-system
kubectl describe ingress flight-booking-ingress -n booking-system
```

### View Logs
```bash
# User service logs
kubectl logs -f deployment/user-service -n booking-system

# Search service logs
kubectl logs -f deployment/search-service -n booking-system

# All services logs
kubectl logs -f -l tier=backend -n booking-system
```

## 🔄 Update & Rollback

### Update a Service

```bash
# Method 1: Update image
kubectl set image deployment/user-service \
  user-service=gcr.io/YOUR_PROJECT/user-service:v2.0 \
  -n booking-system

# Method 2: Apply new manifest
kubectl apply -f user-service.yaml

# Watch rollout
kubectl rollout status deployment/user-service -n booking-system
```

### Rollback a Service

```bash
# Using script
./rollback.sh

# Or manually
kubectl rollout undo deployment/user-service -n booking-system

# Rollback to specific revision
kubectl rollout history deployment/user-service -n booking-system
kubectl rollout undo deployment/user-service --to-revision=2 -n booking-system
```

## 📈 Scaling

### Manual Scaling
```bash
# Scale user service to 5 replicas
kubectl scale deployment/user-service --replicas=5 -n booking-system

# Scale search service to 10 replicas
kubectl scale deployment/search-service --replicas=10 -n booking-system
```

### Auto-Scaling (HPA)
HPA is already configured in the YAML files. Check status:

```bash
# View HPA status
kubectl get hpa -n booking-system

# Describe HPA
kubectl describe hpa user-service-hpa -n booking-system
```

## 🔐 Security

### Update Secrets
```bash
# Update a secret
kubectl create secret generic postgres-secret \
  --from-literal=username=new_user \
  --from-literal=password=new_password \
  --dry-run=client -o yaml | kubectl apply -n booking-system -f -

# Restart pods to pick up new secrets
kubectl rollout restart deployment/user-service -n booking-system
```

### Network Policies
To enable network policies (restrict traffic between pods):

```bash
# Apply network policy (create networkpolicy.yaml first)
kubectl apply -f networkpolicy.yaml
```

## 📊 Monitoring

### Install Monitoring Stack
```bash
# Using deploy script (option during deployment)
./deploy.sh

# Or manually with Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### Access Grafana
```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser: http://localhost:3000
# Default credentials: admin/admin123
```

### Access Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open: http://localhost:9090
```

## 🗄️ Database Access

### PostgreSQL
```bash
# Connect to PostgreSQL
kubectl exec -it postgres-0 -n booking-system -- psql -U booking_admin -d booking_db

# Run a query
kubectl exec -it postgres-0 -n booking-system -- \
  psql -U booking_admin -d booking_db -c "SELECT * FROM users LIMIT 5;"
```

### Redis
```bash
# Connect to Redis
kubectl exec -it redis-0 -n booking-system -- redis-cli -a YOUR_PASSWORD

# Check keys
kubectl exec -it redis-0 -n booking-system -- \
  redis-cli -a YOUR_PASSWORD --scan --pattern '*'
```

### MongoDB
```bash
# Connect to MongoDB
kubectl exec -it mongodb-0 -n booking-system -- \
  mongosh -u mongo_admin -p YOUR_PASSWORD --authenticationDatabase admin
```

### RabbitMQ Management
```bash
# Port-forward to RabbitMQ management UI
kubectl port-forward -n booking-system svc/rabbitmq 15672:15672

# Open browser: http://localhost:15672
# Default credentials: rabbit_admin/YOUR_PASSWORD
```

## 🔧 Troubleshooting

### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n booking-system

# Describe pod
kubectl describe pod <pod-name> -n booking-system

# View events
kubectl get events -n booking-system --sort-by='.lastTimestamp'
```

### Service Connection Issues
```bash
# Test service connectivity from a pod
kubectl run test-pod --rm -it --image=busybox -n booking-system -- sh

# Inside the pod:
wget -O- http://user-service:3001/health
```

### Database Connection Issues
```bash
# Check if database is ready
kubectl exec -it postgres-0 -n booking-system -- pg_isready

# Check database logs
kubectl logs postgres-0 -n booking-system
```

### Ingress Not Working
```bash
# Check ingress status
kubectl describe ingress flight-booking-ingress -n booking-system

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## 🧹 Cleanup

### Delete Everything
```bash
# Using script (CAUTION: Deletes all data!)
./cleanup.sh

# Or manually
kubectl delete namespace booking-system

# Delete monitoring
kubectl delete namespace monitoring
```

### Delete Specific Service
```bash
kubectl delete -f user-service.yaml
```

## 📝 Environment-Specific Deployments

### Development
```bash
# Use smaller replicas and resources
kubectl apply -f user-service.yaml
kubectl scale deployment/user-service --replicas=1 -n booking-system
```

### Production
```bash
# Ensure high availability
kubectl scale deployment/user-service --replicas=5 -n booking-system
kubectl scale deployment/search-service --replicas=8 -n booking-system
kubectl scale deployment/booking-service --replicas=10 -n booking-system
```

## 🔗 Useful Commands

```bash
# Get all resources
kubectl get all -n booking-system

# Top pods (resource usage)
kubectl top pods -n booking-system

# Top nodes
kubectl top nodes

# Exec into a pod
kubectl exec -it <pod-name> -n booking-system -- /bin/sh

# Copy files from pod
kubectl cp booking-system/<pod-name>:/path/to/file ./local-file

# Port-forward to a service
kubectl port-forward -n booking-system svc/user-service 3001:3001
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Operator](https://prometheus-operator.dev/)

## 🆘 Support

For issues or questions:
1. Check pod logs: `kubectl logs <pod-name> -n booking-system`
2. Check events: `kubectl get events -n booking-system`
3. Review the main deployment guide: `../KUBERNETES_DEPLOYMENT.md`

---

**⚠️ Important Reminders:**
- Always update `secrets.yaml` before deploying
- Use strong passwords for all services
- Enable TLS/SSL for production
- Set up regular backups for databases
- Monitor resource usage and scale accordingly
- Keep Docker images updated with security patches
