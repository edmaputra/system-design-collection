# GCP Deployment Architecture

## 🌐 Google Cloud Platform Architecture Overview

This document outlines the complete deployment architecture for the Flight Booking System on Google Cloud Platform (GCP).

## 🏗️ High-Level Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        WEB[Web Browser]
        MOBILE[Mobile App]
        PARTNER[Partner APIs]
    end

    subgraph "Edge Layer - Cloud CDN"
        CDN[Cloud CDN]
        ARMOR[Cloud Armor<br/>DDoS Protection]
    end

    subgraph "Global Load Balancing"
        GLB[Global HTTP Load Balancer]
        SSL[SSL Certificates<br/>Managed]
    end

    subgraph "Multi-Region Deployment"
        subgraph "US Region - us-central1"
            subgraph "Frontend Tier"
                US_FE1[Cloud Run<br/>Web App]
                US_FE2[Cloud Run<br/>Web App]
            end
            
            subgraph "API Gateway Tier"
                US_APIGW[API Gateway<br/>Kong/Apigee]
            end
            
            subgraph "Application Tier - GKE Cluster"
                US_GKE[GKE Autopilot Cluster]
                subgraph "Microservices Pods"
                    US_USER[User Service]
                    US_FLIGHT[Flight Service]
                    US_BOOKING[Booking Service]
                    US_PAYMENT[Payment Service]
                    US_NOTIFY[Notification Service]
                end
            end
            
            subgraph "Data Tier"
                US_PSQL[(Cloud SQL<br/>PostgreSQL)]
                US_REDIS[(Memorystore<br/>Redis)]
                US_MONGO[(MongoDB Atlas)]
            end
        end

        subgraph "EU Region - europe-west1"
            subgraph "Frontend Tier EU"
                EU_FE1[Cloud Run<br/>Web App]
                EU_FE2[Cloud Run<br/>Web App]
            end
            
            subgraph "API Gateway Tier EU"
                EU_APIGW[API Gateway]
            end
            
            subgraph "Application Tier EU - GKE Cluster"
                EU_GKE[GKE Autopilot Cluster]
                subgraph "Microservices Pods EU"
                    EU_USER[User Service]
                    EU_FLIGHT[Flight Service]
                    EU_BOOKING[Booking Service]
                    EU_PAYMENT[Payment Service]
                    EU_NOTIFY[Notification Service]
                end
            end
            
            subgraph "Data Tier EU"
                EU_PSQL[(Cloud SQL<br/>PostgreSQL)]
                EU_REDIS[(Memorystore<br/>Redis)]
                EU_MONGO[(MongoDB Atlas)]
            end
        end
    end

    subgraph "Message & Event Layer"
        PUBSUB[Cloud Pub/Sub<br/>Event Streaming]
    end

    subgraph "Data & Analytics"
        BQ[BigQuery<br/>Data Warehouse]
        ES[Elasticsearch<br/>on GCE]
        DATAFLOW[Dataflow<br/>Stream Processing]
    end

    subgraph "Storage Layer"
        GCS[Cloud Storage<br/>Static Assets & Backups]
        FILESTORE[Filestore<br/>Shared Files]
    end

    subgraph "Security & Identity"
        IAM[Cloud IAM]
        KMS[Cloud KMS<br/>Key Management]
        SECRET[Secret Manager]
        VPC[VPC Service Controls]
    end

    subgraph "Monitoring & Operations"
        MONITOR[Cloud Monitoring]
        LOGGING[Cloud Logging]
        TRACE[Cloud Trace]
        PROFILER[Cloud Profiler]
        ERROR[Error Reporting]
    end

    subgraph "External Services"
        STRIPE[Stripe API<br/>Payments]
        TWILIO[Twilio<br/>SMS]
        SENDGRID[SendGrid<br/>Email]
        AIRLINE[Airline APIs<br/>GDS Systems]
    end

    WEB --> CDN
    MOBILE --> CDN
    PARTNER --> CDN
    CDN --> ARMOR
    ARMOR --> GLB
    GLB --> SSL
    
    SSL --> US_FE1
    SSL --> US_FE2
    SSL --> EU_FE1
    SSL --> EU_FE2
    
    US_FE1 --> US_APIGW
    US_FE2 --> US_APIGW
    EU_FE1 --> EU_APIGW
    EU_FE2 --> EU_APIGW
    
    US_APIGW --> US_GKE
    EU_APIGW --> EU_GKE
    
    US_GKE --> US_USER
    US_GKE --> US_FLIGHT
    US_GKE --> US_BOOKING
    US_GKE --> US_PAYMENT
    US_GKE --> US_NOTIFY
    
    EU_GKE --> EU_USER
    EU_GKE --> EU_FLIGHT
    EU_GKE --> EU_BOOKING
    EU_GKE --> EU_PAYMENT
    EU_GKE --> EU_NOTIFY
    
    US_USER --> US_PSQL
    US_FLIGHT --> US_PSQL
    US_BOOKING --> US_PSQL
    US_PAYMENT --> US_PSQL
    US_NOTIFY --> US_MONGO
    
    EU_USER --> EU_PSQL
    EU_FLIGHT --> EU_PSQL
    EU_BOOKING --> EU_PSQL
    EU_PAYMENT --> EU_PSQL
    EU_NOTIFY --> EU_MONGO
    
    US_USER --> US_REDIS
    US_FLIGHT --> US_REDIS
    EU_USER --> EU_REDIS
    EU_FLIGHT --> EU_REDIS
    
    US_BOOKING --> PUBSUB
    EU_BOOKING --> PUBSUB
    PUBSUB --> US_NOTIFY
    PUBSUB --> EU_NOTIFY
    PUBSUB --> DATAFLOW
    
    DATAFLOW --> BQ
    US_GKE --> LOGGING
    EU_GKE --> LOGGING
    LOGGING --> ES
    
    US_PAYMENT --> STRIPE
    US_NOTIFY --> TWILIO
    US_NOTIFY --> SENDGRID
    US_FLIGHT --> AIRLINE
    
    US_FE1 --> GCS
    EU_FE1 --> GCS
    
    US_PSQL -.Replication.-> EU_PSQL
    EU_PSQL -.Replication.-> US_PSQL
    
    IAM --> US_GKE
    IAM --> EU_GKE
    KMS --> US_PSQL
    KMS --> EU_PSQL
    SECRET --> US_GKE
    SECRET --> EU_GKE
    
    MONITOR --> US_GKE
    MONITOR --> EU_GKE
    TRACE --> US_GKE
    TRACE --> EU_GKE

    style WEB fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style MOBILE fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style CDN fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style GLB fill:#fbbc04,stroke:#333,stroke-width:2px,color:#000
    style US_GKE fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
    style EU_GKE fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
    style PUBSUB fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style BQ fill:#669df6,stroke:#333,stroke-width:2px,color:#fff
```

## 🌍 Network Architecture

```mermaid
graph TB
    subgraph "Global Network Infrastructure"
        subgraph "Premium Tier Network"
            INTERNET[Internet]
            PEERING[Google Peering Edge]
        end
        
        subgraph "VPC Network - flight-booking-vpc"
            subgraph "US Region Subnets"
                US_PUBLIC[Public Subnet<br/>10.0.1.0/24]
                US_PRIVATE[Private Subnet<br/>10.0.2.0/24]
                US_DB[Database Subnet<br/>10.0.3.0/24]
            end
            
            subgraph "EU Region Subnets"
                EU_PUBLIC[Public Subnet<br/>10.1.1.0/24]
                EU_PRIVATE[Private Subnet<br/>10.1.2.0/24]
                EU_DB[Database Subnet<br/>10.1.3.0/24]
            end
            
            subgraph "Network Security"
                FW[Cloud Firewall Rules]
                NAT_US[Cloud NAT - US]
                NAT_EU[Cloud NAT - EU]
                VPN[Cloud VPN/Interconnect]
            end
        end
        
        subgraph "Service Mesh"
            ISTIO[Istio Service Mesh<br/>on GKE]
            ENVOY[Envoy Proxies]
        end
        
        subgraph "DNS Management"
            CLOUDDNS[Cloud DNS<br/>flightbooking.com]
        end
        
        subgraph "Private Connectivity"
            PSC[Private Service Connect]
            PEER[VPC Peering]
        end
    end

    INTERNET --> PEERING
    PEERING --> CLOUDDNS
    CLOUDDNS --> US_PUBLIC
    CLOUDDNS --> EU_PUBLIC
    
    US_PUBLIC --> FW
    EU_PUBLIC --> FW
    FW --> US_PRIVATE
    FW --> EU_PRIVATE
    
    US_PRIVATE --> NAT_US
    EU_PRIVATE --> NAT_EU
    
    US_PRIVATE --> ISTIO
    EU_PRIVATE --> ISTIO
    ISTIO --> ENVOY
    
    US_PRIVATE --> US_DB
    EU_PRIVATE --> EU_DB
    
    US_DB --> PSC
    EU_DB --> PSC
    
    US_PRIVATE -.VPN Tunnel.-> EU_PRIVATE

    style INTERNET fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style CLOUDDNS fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style ISTIO fill:#fbbc04,stroke:#333,stroke-width:2px,color:#000
    style FW fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
```

## 🔐 Security Architecture

```mermaid
graph TB
    subgraph "Security Layers"
        subgraph "Perimeter Security"
            ARMOR[Cloud Armor<br/>WAF & DDoS]
            RECAPTCHA[reCAPTCHA Enterprise]
        end
        
        subgraph "Identity & Access"
            IAM[Cloud IAM<br/>Role-Based Access]
            IDENTITY[Identity Platform<br/>User Auth]
            WORKLOAD[Workload Identity<br/>Service Auth]
        end
        
        subgraph "Data Security"
            KMS[Cloud KMS<br/>Encryption Keys]
            SECRET[Secret Manager<br/>Credentials]
            DLP[Cloud DLP<br/>Data Loss Prevention]
        end
        
        subgraph "Network Security"
            FW[VPC Firewall]
            SSL[Managed SSL Certs]
            PRIVATE[Private Google Access]
            VPC_SC[VPC Service Controls]
        end
        
        subgraph "Application Security"
            BIN_AUTH[Binary Authorization<br/>Container Security]
            VULN[Container Analysis<br/>Vulnerability Scanning]
            SECURITY_CMD[Security Command Center]
        end
        
        subgraph "Compliance & Audit"
            AUDIT[Cloud Audit Logs]
            ACCESS[Access Transparency]
            COMPLIANCE[Compliance Reports<br/>PCI DSS, SOC2]
        end
    end

    ARMOR --> IAM
    RECAPTCHA --> IDENTITY
    IDENTITY --> WORKLOAD
    
    WORKLOAD --> KMS
    KMS --> SECRET
    SECRET --> DLP
    
    IAM --> FW
    FW --> SSL
    SSL --> PRIVATE
    PRIVATE --> VPC_SC
    
    VPC_SC --> BIN_AUTH
    BIN_AUTH --> VULN
    VULN --> SECURITY_CMD
    
    SECURITY_CMD --> AUDIT
    AUDIT --> ACCESS
    ACCESS --> COMPLIANCE

    style ARMOR fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
    style KMS fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style COMPLIANCE fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
```

## 📊 Data Flow Architecture

```mermaid
sequenceDiagram
    participant User as User/Client
    participant CDN as Cloud CDN
    participant LB as Load Balancer
    participant API as API Gateway
    participant Auth as Auth Service
    participant Flight as Flight Service
    participant Cache as Redis Cache
    participant DB as Cloud SQL
    participant PubSub as Cloud Pub/Sub
    participant Notify as Notification Service
    
    User->>CDN: Search Flights Request
    CDN->>LB: Forward to LB
    LB->>API: Route to API Gateway
    API->>Auth: Validate JWT Token
    Auth-->>API: Token Valid
    
    API->>Flight: Search Flights
    Flight->>Cache: Check Cache
    alt Cache Hit
        Cache-->>Flight: Return Cached Results
    else Cache Miss
        Flight->>DB: Query Database
        DB-->>Flight: Return Results
        Flight->>Cache: Update Cache
    end
    
    Flight-->>API: Flight Results
    API-->>LB: Response
    LB-->>CDN: Response
    CDN-->>User: Display Results
    
    User->>CDN: Create Booking
    CDN->>LB: Forward Request
    LB->>API: Route Request
    API->>Auth: Validate Token
    Auth-->>API: Authorized
    
    API->>Flight: Create Booking
    Flight->>DB: Begin Transaction
    Flight->>DB: Reserve Seats
    Flight->>DB: Create Booking Record
    Flight->>DB: Commit Transaction
    DB-->>Flight: Booking Created
    
    Flight->>PubSub: Publish BookingCreated Event
    Flight-->>API: Booking Response
    API-->>User: Booking Confirmation
    
    PubSub->>Notify: BookingCreated Event
    Notify->>User: Send Confirmation Email
    Notify->>User: Send SMS Notification
```

## 🚀 GKE Cluster Architecture

```mermaid
graph TB
    subgraph "GKE Autopilot Cluster - flight-booking-cluster"
        subgraph "System Namespaces"
            KUBE_SYS[kube-system<br/>Core Components]
            ISTIO_SYS[istio-system<br/>Service Mesh]
            MONITORING[monitoring<br/>Prometheus Stack]
        end
        
        subgraph "Application Namespaces"
            subgraph "Production Namespace"
                PROD_DEPLOY[Deployments]
                
                subgraph "User Service"
                    USER_POD1[Pod 1]
                    USER_POD2[Pod 2]
                    USER_POD3[Pod 3]
                    USER_SVC[Service]
                    USER_HPA[HPA]
                end
                
                subgraph "Flight Service"
                    FLIGHT_POD1[Pod 1]
                    FLIGHT_POD2[Pod 2]
                    FLIGHT_POD3[Pod 3]
                    FLIGHT_SVC[Service]
                    FLIGHT_HPA[HPA]
                end
                
                subgraph "Booking Service"
                    BOOKING_POD1[Pod 1]
                    BOOKING_POD2[Pod 2]
                    BOOKING_SVC[Service]
                    BOOKING_HPA[HPA]
                end
                
                INGRESS[Ingress Controller<br/>nginx/GKE Ingress]
            end
            
            subgraph "Staging Namespace"
                STAGING[Staging Deployments<br/>Mirror of Production]
            end
        end
        
        subgraph "Persistent Storage"
            PVC1[PVC - Logs]
            PVC2[PVC - Config]
        end
        
        subgraph "ConfigMaps & Secrets"
            CM[ConfigMaps]
            SEC[Secrets<br/>from Secret Manager]
        end
    end
    
    subgraph "External Resources"
        SQL[(Cloud SQL)]
        REDIS[(Memorystore)]
        PUBSUB[Cloud Pub/Sub]
    end

    INGRESS --> USER_SVC
    INGRESS --> FLIGHT_SVC
    INGRESS --> BOOKING_SVC
    
    USER_SVC --> USER_POD1
    USER_SVC --> USER_POD2
    USER_SVC --> USER_POD3
    USER_HPA -.Auto-scale.-> USER_POD1
    
    FLIGHT_SVC --> FLIGHT_POD1
    FLIGHT_SVC --> FLIGHT_POD2
    FLIGHT_SVC --> FLIGHT_POD3
    FLIGHT_HPA -.Auto-scale.-> FLIGHT_POD1
    
    BOOKING_SVC --> BOOKING_POD1
    BOOKING_SVC --> BOOKING_POD2
    BOOKING_HPA -.Auto-scale.-> BOOKING_POD1
    
    USER_POD1 --> CM
    USER_POD1 --> SEC
    USER_POD1 --> SQL
    USER_POD1 --> REDIS
    
    FLIGHT_POD1 --> SQL
    FLIGHT_POD1 --> REDIS
    
    BOOKING_POD1 --> SQL
    BOOKING_POD1 --> PUBSUB
    
    ISTIO_SYS -.Manages.-> USER_POD1
    ISTIO_SYS -.Manages.-> FLIGHT_POD1
    ISTIO_SYS -.Manages.-> BOOKING_POD1
    
    MONITORING -.Monitors.-> USER_POD1
    MONITORING -.Monitors.-> FLIGHT_POD1
    MONITORING -.Monitors.-> BOOKING_POD1

    style INGRESS fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style USER_SVC fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style FLIGHT_SVC fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style BOOKING_SVC fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style ISTIO_SYS fill:#fbbc04,stroke:#333,stroke-width:2px,color:#000
```

## 💾 Data Storage Architecture

```mermaid
graph TB
    subgraph "Primary Databases"
        subgraph "Cloud SQL - PostgreSQL"
            SQL_PRIMARY[(Primary Instance<br/>us-central1<br/>High Availability)]
            SQL_REPLICA1[(Read Replica 1<br/>us-central1)]
            SQL_REPLICA2[(Read Replica 2<br/>europe-west1)]
            SQL_BACKUP[Automated Backups<br/>Point-in-Time Recovery]
        end
        
        subgraph "Memorystore - Redis"
            REDIS_PRIMARY[(Primary Instance<br/>6GB Memory)]
            REDIS_REPLICA[(Replica Instance<br/>Auto-failover)]
        end
        
        subgraph "MongoDB Atlas"
            MONGO_PRIMARY[(Primary<br/>M30 Cluster)]
            MONGO_SECONDARY1[(Secondary 1)]
            MONGO_SECONDARY2[(Secondary 2)]
        end
    end
    
    subgraph "Analytics & Search"
        BQ[(BigQuery<br/>Data Warehouse)]
        ES[(Elasticsearch<br/>Search Engine)]
    end
    
    subgraph "Object Storage"
        GCS_STATIC[Cloud Storage<br/>Static Assets<br/>Multi-region]
        GCS_BACKUP[Cloud Storage<br/>Database Backups<br/>Nearline Storage]
        GCS_LOGS[Cloud Storage<br/>Log Archives<br/>Coldline Storage]
    end
    
    subgraph "Data Pipeline"
        DATAFLOW[Cloud Dataflow<br/>ETL Pipeline]
        COMPOSER[Cloud Composer<br/>Workflow Orchestration]
    end

    SQL_PRIMARY --> SQL_REPLICA1
    SQL_PRIMARY --> SQL_REPLICA2
    SQL_PRIMARY --> SQL_BACKUP
    SQL_BACKUP --> GCS_BACKUP
    
    REDIS_PRIMARY --> REDIS_REPLICA
    
    MONGO_PRIMARY --> MONGO_SECONDARY1
    MONGO_PRIMARY --> MONGO_SECONDARY2
    
    SQL_PRIMARY --> DATAFLOW
    MONGO_PRIMARY --> DATAFLOW
    DATAFLOW --> BQ
    DATAFLOW --> ES
    
    COMPOSER -.Orchestrates.-> DATAFLOW
    
    SQL_PRIMARY -.Archive.-> GCS_LOGS

    style SQL_PRIMARY fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style BQ fill:#669df6,stroke:#333,stroke-width:2px,color:#fff
    style GCS_STATIC fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
```

## 📈 Auto-Scaling Strategy

```mermaid
graph TB
    subgraph "Auto-Scaling Components"
        subgraph "Application Auto-Scaling"
            HPA[Horizontal Pod Autoscaler<br/>CPU/Memory Based]
            VPA[Vertical Pod Autoscaler<br/>Resource Optimization]
            CUSTOM[Custom Metrics Autoscaler<br/>Business Metrics]
        end
        
        subgraph "Infrastructure Auto-Scaling"
            GKE_AUTO[GKE Autopilot<br/>Node Auto-Scaling]
            CLOUD_RUN[Cloud Run<br/>Request-Based Scaling]
        end
        
        subgraph "Database Auto-Scaling"
            SQL_SCALE[Cloud SQL<br/>Automatic Storage Increase]
            REDIS_SCALE[Memorystore<br/>Instance Size Adjustment]
        end
        
        subgraph "Metrics & Monitoring"
            METRICS[Cloud Monitoring<br/>Custom Metrics]
            ALERTS[Alerting Policies]
        end
    end
    
    subgraph "Scaling Triggers"
        CPU_TRIGGER[CPU > 70%]
        MEM_TRIGGER[Memory > 80%]
        RPS_TRIGGER[RPS > 1000]
        QUEUE_TRIGGER[Queue Depth > 100]
    end
    
    subgraph "Scaling Actions"
        SCALE_UP[Scale Up Pods/Instances]
        SCALE_DOWN[Scale Down Pods/Instances]
        ALERT_TEAM[Alert Operations Team]
    end

    METRICS --> CPU_TRIGGER
    METRICS --> MEM_TRIGGER
    METRICS --> RPS_TRIGGER
    METRICS --> QUEUE_TRIGGER
    
    CPU_TRIGGER --> HPA
    MEM_TRIGGER --> HPA
    RPS_TRIGGER --> CUSTOM
    QUEUE_TRIGGER --> CUSTOM
    
    HPA --> SCALE_UP
    CUSTOM --> SCALE_UP
    CLOUD_RUN --> SCALE_UP
    
    SCALE_UP --> GKE_AUTO
    SCALE_DOWN --> GKE_AUTO
    
    ALERTS --> ALERT_TEAM

    style HPA fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style SCALE_UP fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style ALERT_TEAM fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
```

## 🔄 CI/CD Pipeline on GCP

```mermaid
graph LR
    subgraph "Source Control"
        GIT[GitHub Repository]
    end
    
    subgraph "Build & Test - Cloud Build"
        TRIGGER[Cloud Build Trigger]
        BUILD[Build Docker Images]
        TEST[Run Tests<br/>Unit & Integration]
        SCAN[Security Scan<br/>Container Analysis]
    end
    
    subgraph "Artifact Storage"
        AR[Artifact Registry<br/>Docker Images]
    end
    
    subgraph "Deployment"
        subgraph "Staging"
            DEPLOY_STG[Deploy to GKE Staging]
            TEST_STG[Smoke Tests]
        end
        
        subgraph "Production"
            APPROVE[Manual Approval]
            DEPLOY_PROD[Blue-Green Deploy<br/>to Production]
            VERIFY[Health Checks]
            ROLLBACK{Success?}
        end
    end
    
    subgraph "Monitoring"
        MONITOR[Cloud Monitoring<br/>Track Deployment]
        ALERT[Alert on Failure]
    end

    GIT -->|Push| TRIGGER
    TRIGGER --> BUILD
    BUILD --> TEST
    TEST -->|Pass| SCAN
    SCAN -->|Pass| AR
    
    AR --> DEPLOY_STG
    DEPLOY_STG --> TEST_STG
    TEST_STG -->|Pass| APPROVE
    
    APPROVE -->|Approved| DEPLOY_PROD
    DEPLOY_PROD --> VERIFY
    VERIFY --> ROLLBACK
    ROLLBACK -->|Success| MONITOR
    ROLLBACK -->|Failure| ALERT
    ALERT -.Automatic Rollback.-> DEPLOY_PROD

    style GIT fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style BUILD fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style DEPLOY_PROD fill:#fbbc04,stroke:#333,stroke-width:2px,color:#000
    style ROLLBACK fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
```

## 📊 Monitoring & Observability

```mermaid
graph TB
    subgraph "Data Collection"
        APP[Applications<br/>Microservices]
        INFRA[Infrastructure<br/>GKE, VMs]
        DB[Databases<br/>Cloud SQL, etc]
    end
    
    subgraph "Metrics & Logs"
        METRICS[Cloud Monitoring<br/>Time-series Metrics]
        LOGS[Cloud Logging<br/>Centralized Logs]
        TRACE[Cloud Trace<br/>Distributed Tracing]
        PROFILER[Cloud Profiler<br/>Performance Analysis]
    end
    
    subgraph "Analysis & Alerting"
        DASHBOARD[Custom Dashboards<br/>Real-time Metrics]
        ALERT_POLICY[Alerting Policies<br/>SLO/SLA Monitoring]
        LOG_ANALYTICS[Log Analytics<br/>Query & Analysis]
    end
    
    subgraph "Incident Response"
        ONCALL[On-Call<br/>PagerDuty/Opsgenie]
        INCIDENT[Incident Management]
        POSTMORTEM[Post-Mortem Analysis]
    end
    
    subgraph "Visualization"
        GRAFANA[Grafana Dashboards]
        LOOKER[Looker Studio<br/>Business Analytics]
    end

    APP --> METRICS
    APP --> LOGS
    APP --> TRACE
    APP --> PROFILER
    
    INFRA --> METRICS
    INFRA --> LOGS
    
    DB --> METRICS
    DB --> LOGS
    
    METRICS --> DASHBOARD
    LOGS --> LOG_ANALYTICS
    TRACE --> DASHBOARD
    
    DASHBOARD --> ALERT_POLICY
    LOG_ANALYTICS --> ALERT_POLICY
    
    ALERT_POLICY --> ONCALL
    ONCALL --> INCIDENT
    INCIDENT --> POSTMORTEM
    
    METRICS --> GRAFANA
    LOGS --> GRAFANA
    METRICS --> LOOKER

    style METRICS fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style ALERT_POLICY fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
    style GRAFANA fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
```

## 💰 Cost Optimization Strategy

```mermaid
graph TB
    subgraph "Cost Management"
        subgraph "Compute Optimization"
            GKE_AUTO[GKE Autopilot<br/>Pay per Pod]
            PREEMPT[Preemptible VMs<br/>Non-critical Workloads]
            SPOT[Spot VMs<br/>80% Cost Reduction]
        end
        
        subgraph "Storage Optimization"
            STORAGE_CLASS[Storage Classes<br/>Standard/Nearline/Coldline]
            LIFECYCLE[Lifecycle Policies<br/>Auto-archive Old Data]
        end
        
        subgraph "Network Optimization"
            CDN_CACHE[CDN Caching<br/>Reduce Egress]
            REGION[Regional Resources<br/>Minimize Cross-region Traffic]
        end
        
        subgraph "Resource Management"
            COMMIT[Committed Use Discounts<br/>1-3 Year Terms]
            SUSTAINED[Sustained Use Discounts<br/>Automatic]
            RIGHTSIZING[Rightsizing Recommendations]
        end
        
        subgraph "Monitoring & Analysis"
            BILLING[Cloud Billing<br/>Cost Reports]
            BUDGET[Budget Alerts]
            RECOMMEND[Recommender<br/>Cost Optimization]
        end
    end

    GKE_AUTO --> BILLING
    PREEMPT --> BILLING
    SPOT --> BILLING
    STORAGE_CLASS --> BILLING
    LIFECYCLE --> BILLING
    CDN_CACHE --> BILLING
    
    BILLING --> BUDGET
    BILLING --> RECOMMEND
    RECOMMEND --> RIGHTSIZING
    BUDGET -.Alert.-> RIGHTSIZING
    
    RIGHTSIZING -.Apply.-> GKE_AUTO
    RIGHTSIZING -.Apply.-> STORAGE_CLASS

    style BILLING fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style COMMIT fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style RECOMMEND fill:#fbbc04,stroke:#333,stroke-width:2px,color:#000
```

## 🔧 GCP Services Summary

| Category | Service | Purpose |
|----------|---------|---------|
| **Compute** | GKE Autopilot | Kubernetes cluster for microservices |
| | Cloud Run | Serverless containers for frontend |
| | Compute Engine | Custom VMs for specialized workloads |
| **Storage** | Cloud SQL | PostgreSQL managed database |
| | Memorystore | Redis cache |
| | Cloud Storage | Object storage for files/backups |
| **Networking** | Cloud Load Balancing | Global HTTP(S) load balancing |
| | Cloud CDN | Content delivery network |
| | Cloud Armor | DDoS protection & WAF |
| | Cloud DNS | DNS management |
| **Data & Analytics** | BigQuery | Data warehouse |
| | Cloud Pub/Sub | Message queue & event streaming |
| | Dataflow | Stream/batch data processing |
| **Security** | Cloud IAM | Identity & access management |
| | Cloud KMS | Encryption key management |
| | Secret Manager | Secrets management |
| | Security Command Center | Security & compliance monitoring |
| **Operations** | Cloud Monitoring | Metrics & dashboards |
| | Cloud Logging | Centralized logging |
| | Cloud Trace | Distributed tracing |
| | Error Reporting | Error tracking |
| **CI/CD** | Cloud Build | Build & deployment automation |
| | Artifact Registry | Container image registry |
| | Binary Authorization | Container security |
| **AI/ML** | Vertex AI | ML model deployment (future) |
| | Recommendations AI | Personalization (future) |

This GCP architecture provides a production-ready, scalable, and secure infrastructure for the Flight Booking System with industry best practices and cost optimization strategies.