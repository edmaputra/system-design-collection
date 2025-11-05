# Flight Booking System - Kubernetes Deployment Guide

## Table of Contents
1. [Kubernetes Architecture Overview](#kubernetes-architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Cluster Setup](#cluster-setup)
4. [Namespace & Resource Organization](#namespace--resource-organization)
5. [Storage Configuration](#storage-configuration)
6. [Database Deployments](#database-deployments)
7. [Microservices Deployments](#microservices-deployments)
8. [Service Discovery & Load Balancing](#service-discovery--load-balancing)
9. [Ingress Configuration](#ingress-configuration)
10. [Auto-Scaling Configuration](#auto-scaling-configuration)
11. [Monitoring & Logging](#monitoring--logging)
12. [CI/CD Pipeline](#cicd-pipeline)
13. [Security Best Practices](#security-best-practices)
14. [Disaster Recovery](#disaster-recovery)
15. [Cost Optimization](#cost-optimization)

---

## Kubernetes Architecture Overview

### High-Level Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                          KUBERNETES CLUSTER (GKE/EKS/AKS)                          │
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐ │
│  │                         INGRESS CONTROLLER (NGINX)                            │ │
│  │                         External Load Balancer                                │ │
│  │                    TLS Termination | Rate Limiting                            │ │
│  └────────────────────────┬──────────────────────────────────────────────────────┘ │
│                           │                                                        │
│  ┌────────────────────────┴──────────────────────────────────────────────────────┐ │
│  │                          NAMESPACE: booking-system                             │ │
│  │                                                                                │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │                     APPLICATION LAYER (Deployments)                      │  │ │
│  │  │                                                                          │  │ │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │  │ │
│  │  │  │   User   │  │  Search  │  │ Booking  │  │ Payment  │  │  Notif.  │  │  │ │
│  │  │  │ Service  │  │ Service  │  │ Service  │  │ Service  │  │ Service  │  │  │ │
│  │  │  │ (Node.js)│  │  (Golang)│  │  (Java)  │  │(Node.js) │  │ (Python) │  │  │ │
│  │  │  │          │  │          │  │          │  │          │  │          │  │  │ │
│  │  │  │ Replicas:│  │ Replicas:│  │ Replicas:│  │ Replicas:│  │ Replicas:│  │  │ │
│  │  │  │   2-5    │  │   3-8    │  │   3-10   │  │   2-5    │  │   2-4    │  │  │ │
│  │  │  │          │  │          │  │          │  │          │  │          │  │  │ │
│  │  │  │ HPA: CPU │  │ HPA: CPU │  │ HPA: CPU │  │ HPA: CPU │  │ HPA: CPU │  │  │ │
│  │  │  │   70%    │  │   70%    │  │   70%    │  │   70%    │  │   70%    │  │  │ │
│  │  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  │  │ │
│  │  │       │             │             │             │             │         │  │ │
│  │  │  ┌────┴─────────────┴─────────────┴─────────────┴─────────────┴──────┐  │  │ │
│  │  │  │                      ClusterIP Services                            │  │  │ │
│  │  │  │  user-svc | search-svc | booking-svc | payment-svc | notif-svc    │  │  │ │
│  │  │  └─────────────────────────────────────────────────────────────────────┘  │  │ │
│  │  └───────────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                                  │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐    │ │
│  │  │                   DATA LAYER (StatefulSets)                              │    │ │
│  │  │                                                                          │    │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐        │    │ │
│  │  │  │ PostgreSQL │  │   Redis    │  │  MongoDB   │  │  RabbitMQ  │        │    │ │
│  │  │  │            │  │            │  │            │  │            │        │    │ │
│  │  │  │ Replicas:3 │  │ Replicas:3 │  │ Replicas:3 │  │ Replicas:3 │        │    │ │
│  │  │  │ (Primary+  │  │ (Master+   │  │ (Primary+  │  │ (Cluster)  │        │    │ │
│  │  │  │  Replicas) │  │  Replicas) │  │  Replicas) │  │            │        │    │ │
│  │  │  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘        │    │ │
│  │  │        │               │               │               │               │    │ │
│  │  │  ┌─────▼───────────────▼───────────────▼───────────────▼──────┐        │    │ │
│  │  │  │              Persistent Volume Claims (PVCs)                │        │    │ │
│  │  │  └─────┬───────────────┬───────────────┬───────────────┬──────┘        │    │ │
│  │  │        │               │               │               │               │    │ │
│  │  │  ┌─────▼───────────────▼───────────────▼───────────────▼──────┐        │    │ │
│  │  │  │     Persistent Volumes (Cloud Storage: EBS/GCE/Azure)       │        │    │ │
│  │  │  │     Storage Class: SSD (gp3/pd-ssd/premium-ssd)             │        │    │ │
│  │  │  └─────────────────────────────────────────────────────────────┘        │    │ │
│  │  └──────────────────────────────────────────────────────────────────────────    │ │
│  │                                                                                  │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐    │ │
│  │  │              MONITORING & LOGGING (Namespace: monitoring)                │    │ │
│  │  │                                                                          │    │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐        │    │ │
│  │  │  │ Prometheus │  │  Grafana   │  │    ELK     │  │   Jaeger   │        │    │ │
│  │  │  │  Operator  │  │            │  │   Stack    │  │            │        │    │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘        │    │ │
│  │  └──────────────────────────────────────────────────────────────────────────    │ │
│  │                                                                                  │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐    │ │
│  │  │                    CONFIG & SECRETS MANAGEMENT                           │    │ │
│  │  │                                                                          │    │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                        │    │ │
│  │  │  │ ConfigMaps │  │  Secrets   │  │   RBAC     │                        │    │ │
│  │  │  │            │  │ (Encrypted)│  │  Policies  │                        │    │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘                        │    │ │
│  │  └──────────────────────────────────────────────────────────────────────────    │ │
│  └──────────────────────────────────────────────────────────────────────────────── │ │
│                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────┐ │
│  │                         NODE POOLS (Worker Nodes)                             │ │
│  │                                                                               │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │ │
│  │  │  App Pool       │  │  DB Pool        │  │  Monitoring Pool│              │ │
│  │  │                 │  │                 │  │                 │              │ │
│  │  │  Node Type:     │  │  Node Type:     │  │  Node Type:     │              │ │
│  │  │  n1-standard-4  │  │  n1-highmem-8   │  │  n1-standard-2  │              │ │
│  │  │  (4 vCPU, 15GB) │  │  (8 vCPU, 52GB) │  │  (2 vCPU, 7.5GB)│              │ │
│  │  │                 │  │                 │  │                 │              │ │
│  │  │  Min Nodes: 3   │  │  Min Nodes: 3   │  │  Min Nodes: 2   │              │ │
│  │  │  Max Nodes: 20  │  │  Max Nodes: 6   │  │  Max Nodes: 4   │              │ │
│  │  │                 │  │                 │  │                 │              │ │
│  │  │  Auto-scaling:  │  │  Auto-scaling:  │  │  Auto-scaling:  │              │ │
│  │  │  Enabled        │  │  Disabled       │  │  Disabled       │              │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘              │ │
│  └──────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │
                    ┌─────────────────┴─────────────────┐
                    │     External Dependencies          │
                    ├────────────────────────────────────┤
                    │  • Amadeus GDS API                 │
                    │  • Stripe Payment Gateway          │
                    │  • SendGrid Email Service          │
                    │  • Twilio SMS Service              │
                    │  • Cloud Storage (Backups)         │
                    └────────────────────────────────────┘
```

---

## Prerequisites

### 1. Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| `kubectl` | 1.28+ | Kubernetes CLI |
| `helm` | 3.12+ | Package manager |
| `docker` | 24.0+ | Container runtime |
| `gcloud`/`aws`/`az` | Latest | Cloud provider CLI |
| `kustomize` | 5.0+ | Configuration management |

### 2. Cloud Provider Setup

#### Google Kubernetes Engine (GKE)
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash

# Authenticate
gcloud auth login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Create GKE cluster
gcloud container clusters create flight-booking-cluster \
  --zone=us-central1-a \
  --num-nodes=3 \
  --machine-type=n1-standard-4 \
  --enable-autoscaling \
  --min-nodes=3 \
  --max-nodes=20 \
  --enable-autorepair \
  --enable-autoupgrade \
  --disk-size=100 \
  --disk-type=pd-ssd \
  --network=default \
  --subnetwork=default \
  --enable-ip-alias \
  --enable-stackdriver-kubernetes \
  --addons=HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver

# Get cluster credentials
gcloud container clusters get-credentials flight-booking-cluster --zone=us-central1-a
```

#### Amazon EKS
```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create EKS cluster
eksctl create cluster \
  --name=flight-booking-cluster \
  --region=us-east-1 \
  --nodegroup-name=standard-workers \
  --node-type=t3.xlarge \
  --nodes=3 \
  --nodes-min=3 \
  --nodes-max=20 \
  --managed \
  --with-oidc \
  --ssh-access \
  --ssh-public-key=~/.ssh/id_rsa.pub
```

#### Azure Kubernetes Service (AKS)
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Create resource group
az group create --name flight-booking-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group flight-booking-rg \
  --name flight-booking-cluster \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 20 \
  --enable-addons monitoring \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group flight-booking-rg --name flight-booking-cluster
```

### 3. Verify Cluster Access

```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check kubectl version
kubectl version --short
```

---

## Namespace & Resource Organization

### Directory Structure

```
kubernetes/
├── base/
│   ├── namespace.yaml
│   ├── configmaps/
│   │   ├── app-config.yaml
│   │   └── nginx-config.yaml
│   ├── secrets/
│   │   ├── db-secrets.yaml
│   │   ├── api-secrets.yaml
│   │   └── tls-secrets.yaml
│   ├── storage/
│   │   ├── storage-class.yaml
│   │   └── persistent-volumes.yaml
│   ├── databases/
│   │   ├── postgres-statefulset.yaml
│   │   ├── redis-statefulset.yaml
│   │   ├── mongodb-statefulset.yaml
│   │   └── rabbitmq-statefulset.yaml
│   ├── services/
│   │   ├── user-service/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── hpa.yaml
│   │   ├── search-service/
│   │   ├── booking-service/
│   │   ├── payment-service/
│   │   ├── notification-service/
│   │   └── review-service/
│   ├── ingress/
│   │   └── ingress.yaml
│   └── monitoring/
│       ├── prometheus/
│       ├── grafana/
│       └── elk/
├── overlays/
│   ├── development/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── production/
│       └── kustomization.yaml
└── scripts/
    ├── deploy.sh
    ├── rollback.sh
    ├── backup.sh
    └── restore.sh
```

---

## Storage Configuration

### Storage Class (base/storage/storage-class.yaml)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/gce-pd  # For GKE (change for EKS/AKS)
parameters:
  type: pd-ssd
  replication-type: regional-pd
  fstype: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-hdd
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  replication-type: regional-pd
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

**For AWS EKS**, use:
```yaml
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
```

**For Azure AKS**, use:
```yaml
provisioner: disk.csi.azure.com
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
```

---

## Database Deployments

### PostgreSQL StatefulSet (base/databases/postgres-statefulset.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: booking-system
  labels:
    app: postgres
spec:
  ports:
  - port: 5432
    name: postgres
  clusterIP: None  # Headless service for StatefulSet
  selector:
    app: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: booking-system
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - postgres
            topologyKey: kubernetes.io/hostname
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: POSTGRES_DB
          value: booking_db
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: postgres-init
          mountPath: /docker-entrypoint-initdb.d
        resources:
          requests:
            cpu: 1000m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
      volumes:
      - name: postgres-init
        configMap:
          name: postgres-init-scripts
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
```

### Redis StatefulSet (base/databases/redis-statefulset.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: booking-system
  labels:
    app: redis
spec:
  ports:
  - port: 6379
    name: redis
  clusterIP: None
  selector:
    app: redis
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: booking-system
spec:
  serviceName: redis
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - redis
            topologyKey: kubernetes.io/hostname
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - --requirepass
        - $(REDIS_PASSWORD)
        - --maxmemory
        - 2gb
        - --maxmemory-policy
        - allkeys-lru
        - --appendonly
        - "yes"
        ports:
        - containerPort: 6379
          name: redis
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        volumeMounts:
        - name: redis-storage
          mountPath: /data
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 1000m
            memory: 3Gi
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: redis-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 50Gi
```

### MongoDB StatefulSet (base/databases/mongodb-statefulset.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: booking-system
  labels:
    app: mongodb
spec:
  ports:
  - port: 27017
    name: mongodb
  clusterIP: None
  selector:
    app: mongodb
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: booking-system
spec:
  serviceName: mongodb
  replicas: 3
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - mongodb
            topologyKey: kubernetes.io/hostname
      containers:
      - name: mongodb
        image: mongo:6
        ports:
        - containerPort: 27017
          name: mongodb
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: username
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: password
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
        livenessProbe:
          exec:
            command:
            - mongosh
            - --eval
            - db.adminCommand('ping')
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - mongosh
            - --eval
            - db.adminCommand('ping')
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: mongodb-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 50Gi
```

### RabbitMQ StatefulSet (base/databases/rabbitmq-statefulset.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: booking-system
  labels:
    app: rabbitmq
spec:
  ports:
  - port: 5672
    name: amqp
  - port: 15672
    name: management
  clusterIP: None
  selector:
    app: rabbitmq
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rabbitmq
  namespace: booking-system
spec:
  serviceName: rabbitmq
  replicas: 3
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - rabbitmq
            topologyKey: kubernetes.io/hostname
      containers:
      - name: rabbitmq
        image: rabbitmq:3-management-alpine
        ports:
        - containerPort: 5672
          name: amqp
        - containerPort: 15672
          name: management
        env:
        - name: RABBITMQ_DEFAULT_USER
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secret
              key: username
        - name: RABBITMQ_DEFAULT_PASS
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secret
              key: password
        - name: RABBITMQ_ERLANG_COOKIE
          value: "secret-cookie-change-me"
        volumeMounts:
        - name: rabbitmq-storage
          mountPath: /var/lib/rabbitmq
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          exec:
            command:
            - rabbitmq-diagnostics
            - -q
            - ping
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          exec:
            command:
            - rabbitmq-diagnostics
            - -q
            - check_port_connectivity
          initialDelaySeconds: 20
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: rabbitmq-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 20Gi
```

---

## Microservices Deployments

### User Service Deployment (base/services/user-service/deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: booking-system
  labels:
    app: user-service
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
        tier: backend
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - user-service
              topologyKey: kubernetes.io/hostname
      containers:
      - name: user-service
        image: gcr.io/YOUR_PROJECT/user-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3001
          name: http
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3001"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: user-db-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        - name: NOTIFICATION_SERVICE_URL
          value: "http://notification-service:3005"
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
```

### Search Service Deployment (base/services/search-service/deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: search-service
  namespace: booking-system
  labels:
    app: search-service
    tier: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: search-service
  template:
    metadata:
      labels:
        app: search-service
        tier: backend
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - search-service
              topologyKey: kubernetes.io/hostname
      containers:
      - name: search-service
        image: gcr.io/YOUR_PROJECT/search-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3002
          name: http
        env:
        - name: PORT
          value: "3002"
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: url
        - name: POSTGRES_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: search-db-url
        - name: AMADEUS_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: amadeus-api-key
        - name: AMADEUS_API_SECRET
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: amadeus-api-secret
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /health
            port: 3002
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3002
          initialDelaySeconds: 10
          periodSeconds: 5
```

### Booking Service Deployment (base/services/booking-service/deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: booking-service
  namespace: booking-system
  labels:
    app: booking-service
    tier: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: booking-service
  template:
    metadata:
      labels:
        app: booking-service
        tier: backend
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - booking-service
              topologyKey: kubernetes.io/hostname
      containers:
      - name: booking-service
        image: gcr.io/YOUR_PROJECT/booking-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3003
          name: http
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "production"
        - name: SERVER_PORT
          value: "3003"
        - name: SPRING_DATASOURCE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: booking-db-jdbc-url
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: SPRING_REDIS_HOST
          value: "redis"
        - name: SPRING_REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        - name: RABBITMQ_HOST
          value: "rabbitmq"
        - name: RABBITMQ_USERNAME
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secret
              key: username
        - name: RABBITMQ_PASSWORD
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secret
              key: password
        - name: PAYMENT_SERVICE_URL
          value: "http://payment-service:3004"
        - name: NOTIFICATION_SERVICE_URL
          value: "http://notification-service:3005"
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 3003
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 3003
          initialDelaySeconds: 30
          periodSeconds: 5
```

### Payment Service, Notification Service, Review Service
*(Similar structure to above services - adjust image, env vars, and resource limits accordingly)*

---

## Service Discovery & Load Balancing

### ClusterIP Services (base/services/*/service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: booking-system
  labels:
    app: user-service
spec:
  type: ClusterIP
  ports:
  - port: 3001
    targetPort: 3001
    protocol: TCP
    name: http
  selector:
    app: user-service
---
apiVersion: v1
kind: Service
metadata:
  name: search-service
  namespace: booking-system
  labels:
    app: search-service
spec:
  type: ClusterIP
  ports:
  - port: 3002
    targetPort: 3002
    protocol: TCP
    name: http
  selector:
    app: search-service
---
apiVersion: v1
kind: Service
metadata:
  name: booking-service
  namespace: booking-system
  labels:
    app: booking-service
spec:
  type: ClusterIP
  ports:
  - port: 3003
    targetPort: 3003
    protocol: TCP
    name: http
  selector:
    app: booking-service
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: booking-system
  labels:
    app: payment-service
spec:
  type: ClusterIP
  ports:
  - port: 3004
    targetPort: 3004
    protocol: TCP
    name: http
  selector:
    app: payment-service
---
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: booking-system
  labels:
    app: notification-service
spec:
  type: ClusterIP
  ports:
  - port: 3005
    targetPort: 3005
    protocol: TCP
    name: http
  selector:
    app: notification-service
---
apiVersion: v1
kind: Service
metadata:
  name: review-service
  namespace: booking-system
  labels:
    app: review-service
spec:
  type: ClusterIP
  ports:
  - port: 3006
    targetPort: 3006
    protocol: TCP
    name: http
  selector:
    app: review-service
```

---

## Ingress Configuration

### NGINX Ingress Controller Installation

```bash
# Install NGINX Ingress Controller using Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.service.externalTrafficPolicy=Local
```

### Ingress Resource (base/ingress/ingress.yaml)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flight-booking-ingress
  namespace: booking-system
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/limit-connections: "10"
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "30"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.flightbooking.com
    secretName: tls-secret
  rules:
  - host: api.flightbooking.com
    http:
      paths:
      - path: /api/v1/auth
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 3001
      - path: /api/v1/users
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 3001
      - path: /api/v1/search
        pathType: Prefix
        backend:
          service:
            name: search-service
            port:
              number: 3002
      - path: /api/v1/bookings
        pathType: Prefix
        backend:
          service:
            name: booking-service
            port:
              number: 3003
      - path: /api/v1/payments
        pathType: Prefix
        backend:
          service:
            name: payment-service
            port:
              number: 3004
      - path: /api/v1/notifications
        pathType: Prefix
        backend:
          service:
            name: notification-service
            port:
              number: 3005
      - path: /api/v1/reviews
        pathType: Prefix
        backend:
          service:
            name: review-service
            port:
              number: 3006
```

---

## Auto-Scaling Configuration

### Horizontal Pod Autoscaler (base/services/*/hpa.yaml)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
  namespace: booking-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: search-service-hpa
  namespace: booking-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: search-service
  minReplicas: 3
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: booking-service-hpa
  namespace: booking-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: booking-service
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Cluster Autoscaler (for GKE)

```bash
# Cluster autoscaler is automatically enabled when creating cluster with --enable-autoscaling
# To adjust settings:
gcloud container clusters update flight-booking-cluster \
  --enable-autoscaling \
  --min-nodes=3 \
  --max-nodes=20 \
  --zone=us-central1-a
```

---

## Monitoring & Logging

### Install Prometheus Operator

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus Operator
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=fast-ssd \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=100Gi \
  --set grafana.adminPassword=admin123
```

### Install ELK Stack

```bash
# Add Elastic Helm repo
helm repo add elastic https://helm.elastic.co
helm repo update

# Install Elasticsearch
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --create-namespace \
  --set replicas=3 \
  --set volumeClaimTemplate.storageClassName=fast-ssd \
  --set volumeClaimTemplate.resources.requests.storage=100Gi

# Install Kibana
helm install kibana elastic/kibana \
  --namespace logging \
  --set service.type=LoadBalancer

# Install Filebeat (log shipper)
helm install filebeat elastic/filebeat \
  --namespace logging
```

---

## CI/CD Pipeline

### GitHub Actions Example (.github/workflows/deploy.yaml)

```yaml
name: Build and Deploy to GKE

on:
  push:
    branches:
      - main
      - develop

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  GKE_CLUSTER: flight-booking-cluster
  GKE_ZONE: us-central1-a
  IMAGE: user-service

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Setup Google Cloud CLI
      uses: google-github-actions/setup-gcloud@v1
      with:
        service_account_key: ${{ secrets.GCP_SA_KEY }}
        project_id: ${{ secrets.GCP_PROJECT_ID }}

    - name: Configure Docker
      run: gcloud auth configure-docker

    - name: Build Docker image
      run: |
        docker build -t gcr.io/$PROJECT_ID/$IMAGE:$GITHUB_SHA \
          -t gcr.io/$PROJECT_ID/$IMAGE:latest \
          ./services/user-service

    - name: Push Docker image
      run: |
        docker push gcr.io/$PROJECT_ID/$IMAGE:$GITHUB_SHA
        docker push gcr.io/$PROJECT_ID/$IMAGE:latest

    - name: Get GKE credentials
      run: |
        gcloud container clusters get-credentials $GKE_CLUSTER --zone $GKE_ZONE

    - name: Deploy to Kubernetes
      run: |
        kubectl set image deployment/user-service \
          user-service=gcr.io/$PROJECT_ID/$IMAGE:$GITHUB_SHA \
          -n booking-system
        
        kubectl rollout status deployment/user-service -n booking-system
```

---

## Security Best Practices

### 1. Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: booking-service-network-policy
  namespace: booking-system
spec:
  podSelector:
    matchLabels:
      app: booking-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 3003
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
```

### 2. Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: booking-system
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 3. Secret Management with External Secrets Operator

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace
```

---

## Disaster Recovery

### Backup Strategy

```bash
# Install Velero for cluster backups
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz
tar -xvf velero-v1.12.0-linux-amd64.tar.gz
sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/

# Configure Velero with GCS (Google Cloud Storage)
velero install \
  --provider gcp \
  --plugins velero/velero-plugin-for-gcp:v1.8.0 \
  --bucket flight-booking-backups \
  --secret-file ./credentials-velero

# Create daily backup schedule
velero schedule create daily-backup --schedule="0 2 * * *"
```

---

## Cost Optimization

### Resource Optimization Tips

1. **Use Preemptible/Spot Instances** for non-critical workloads
2. **Right-size pods** based on actual usage metrics
3. **Enable Cluster Autoscaler** to scale down during low traffic
4. **Use Regional Storage** instead of Multi-Regional when possible
5. **Implement Pod Disruption Budgets** for graceful scaling
6. **Use Resource Quotas** to prevent over-provisioning

---

## Deployment Commands

### Deploy Everything

```bash
# Create namespace
kubectl apply -f base/namespace.yaml

# Create secrets
kubectl apply -f base/secrets/

# Create ConfigMaps
kubectl apply -f base/configmaps/

# Deploy databases
kubectl apply -f base/databases/

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n booking-system --timeout=300s

# Deploy microservices
kubectl apply -f base/services/

# Deploy ingress
kubectl apply -f base/ingress/

# Verify deployment
kubectl get all -n booking-system
```

---

## Summary

This Kubernetes deployment provides:

✅ **High Availability** - Multi-replica deployments with pod anti-affinity  
✅ **Auto-Scaling** - HPA for services, Cluster Autoscaler for nodes  
✅ **Persistent Storage** - StatefulSets with PVCs for databases  
✅ **Service Discovery** - ClusterIP services with DNS  
✅ **Load Balancing** - Ingress with NGINX controller  
✅ **Monitoring** - Prometheus + Grafana + ELK  
✅ **Security** - Network policies, RBAC, secrets management  
✅ **Disaster Recovery** - Velero backups  
✅ **CI/CD Ready** - GitHub Actions integration  

**Next Steps**:
1. Set up cloud provider account (GCP/AWS/Azure)
2. Create Kubernetes cluster
3. Configure kubectl access
4. Create and push Docker images
5. Deploy infrastructure (databases first)
6. Deploy application services
7. Configure monitoring and logging
8. Set up CI/CD pipeline
9. Implement backup strategy
10. Monitor and optimize costs
