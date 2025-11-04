# Flight Booking System - Visual Architecture Guide

This document provides a comprehensive visual overview of the Flight Booking System architecture using Mermaid diagrams.

## 📊 Quick Reference

All diagrams in this guide are created using Mermaid.js and can be viewed directly in:
- GitHub (native Mermaid support)
- VS Code (with Mermaid extensions)
- Any Markdown viewer with Mermaid support

## 🎯 Table of Contents

1. [High-Level System Architecture](#high-level-system-architecture)
2. [Backend Application Architecture](#backend-application-architecture) **NEW**
3. [Microservices Communication](#microservices-communication)
4. [Data Flow & Sequences](#data-flow--sequences)
5. [Database Architecture](#database-architecture)
6. [Security Layers](#security-layers)
7. [Deployment Pipeline](#deployment-pipeline)
8. [GCP Cloud Architecture](#gcp-cloud-architecture)
9. [Monitoring & Observability](#monitoring--observability)

---

## High-Level System Architecture

This diagram shows the overall system structure from client to data layer.

**Location**: `/docs/architecture/README.md`

```mermaid
graph TB
    subgraph "Client Layer"
        WEB[Web Application]
        MOBILE[Mobile App]
        PARTNER[Partner APIs]
    end

    subgraph "Edge & Gateway"
        CDN[CDN - CloudFront]
        GATEWAY[API Gateway]
    end

    subgraph "Microservices"
        USER[User Service]
        FLIGHT[Flight Service]
        BOOKING[Booking Service]
        PAYMENT[Payment Service]
    end

    subgraph "Data Layer"
        POSTGRES[(PostgreSQL)]
        REDIS[(Redis Cache)]
        KAFKA[Apache Kafka]
    end

    WEB --> CDN
    MOBILE --> CDN
    CDN --> GATEWAY
    GATEWAY --> USER
    GATEWAY --> FLIGHT
    GATEWAY --> BOOKING
    GATEWAY --> PAYMENT
    
    USER --> POSTGRES
    FLIGHT --> POSTGRES
    FLIGHT --> REDIS
    BOOKING --> KAFKA
    PAYMENT --> KAFKA

    style CDN fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style GATEWAY fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
    style KAFKA fill:#fbbc04,stroke:#333,stroke-width:2px,color:#000
```

---

## Backend Application Architecture

Shows the internal structure of backend services with clean architecture patterns.

**Location**: `/docs/architecture/backend-architecture.md`

```mermaid
graph TB
    subgraph "Hexagonal Architecture Pattern"
        subgraph "External Adapters"
            REST[REST API Controller]
            GRPC_ADAPTER[gRPC Adapter]
            EVENT_LISTENER[Event Listener]
        end

        subgraph "Application Layer"
            USE_CASES[Use Cases/Application Services]
            HANDLERS[Command/Query Handlers]
            VALIDATORS[Input Validators]
        end

        subgraph "Domain Layer"
            ENTITIES[Domain Entities]
            VALUE_OBJECTS[Value Objects]
            DOMAIN_SERVICES[Domain Services]
            BUSINESS_RULES[Business Rules]
        end

        subgraph "Infrastructure Layer"
            REPOS[Repository Implementations]
            DB_ADAPTERS[Database Adapters]
            EXTERNAL_APIS[External API Clients]
            CACHE[Cache Adapters]
        end
    end

    REST --> USE_CASES
    GRPC_ADAPTER --> USE_CASES
    EVENT_LISTENER --> HANDLERS
    USE_CASES --> DOMAIN_SERVICES
    HANDLERS --> ENTITIES
    DOMAIN_SERVICES --> REPOS
    REPOS --> DB_ADAPTERS

    classDef adapters fill:#e1f5fe
    classDef application fill:#f3e5f5
    classDef domain fill:#e8f5e8
    classDef infrastructure fill:#fff3e0

    class REST,GRPC_ADAPTER,EVENT_LISTENER adapters
    class USE_CASES,HANDLERS,VALIDATORS application
    class ENTITIES,VALUE_OBJECTS,DOMAIN_SERVICES,BUSINESS_RULES domain
    class REPOS,DB_ADAPTERS,EXTERNAL_APIS,CACHE infrastructure
```

### Technology Stack Overview

```mermaid
graph TB
    subgraph "Programming Languages"
        JAVA[Java 17+ Spring Boot]
        NODE[Node.js 18+ Express]
        PYTHON[Python 3.11+ FastAPI]
        GO[Go 1.21+ Gin]
    end

    subgraph "Data & Messaging"
        POSTGRES[PostgreSQL 15+]
        REDIS[Redis 7+ Cache]
        KAFKA[Apache Kafka]
        ELASTIC[Elasticsearch 8+]
    end

    subgraph "Observability"
        PROMETHEUS[Prometheus Metrics]
        JAEGER[Jaeger Tracing]
        ELK[ELK Stack Logging]
        GRAFANA[Grafana Dashboards]
    end

    JAVA --> POSTGRES
    NODE --> REDIS
    PYTHON --> KAFKA
    GO --> ELASTIC

    POSTGRES --> PROMETHEUS
    REDIS --> JAEGER
    KAFKA --> ELK
    ELASTIC --> GRAFANA

    classDef languages fill:#4285f4,color:#fff
    classDef data fill:#34a853,color:#fff
    classDef monitoring fill:#ea4335,color:#fff

    class JAVA,NODE,PYTHON,GO languages
    class POSTGRES,REDIS,KAFKA,ELASTIC data
    class PROMETHEUS,JAEGER,ELK,GRAFANA monitoring
```

---

## Microservices Communication

Shows how services communicate synchronously (REST) and asynchronously (Events).

**Location**: `/docs/architecture/README.md`

```mermaid
sequenceDiagram
    participant User
    participant API as API Gateway
    participant Flight as Flight Service
    participant Booking as Booking Service
    participant Kafka
    participant Notify as Notification Service

    User->>API: Search Flights
    API->>Flight: GET /flights/search
    Flight-->>API: Flight Results
    API-->>User: Display Results

    User->>API: Create Booking
    API->>Booking: POST /bookings
    Booking->>Kafka: Publish BookingCreated Event
    Booking-->>API: Booking Confirmation
    API-->>User: Success Response

    Kafka->>Notify: BookingCreated Event
    Notify->>User: Send Email Confirmation
    Notify->>User: Send SMS Alert
```

---

## Data Flow & Sequences

Complete end-to-end booking flow with all service interactions.

**Location**: `/docs/deployment/gcp-architecture.md`

```mermaid
sequenceDiagram
    actor User
    participant Gateway
    participant Flight
    participant Cache
    participant DB
    participant Booking
    participant Payment
    participant Kafka
    participant Notify

    Note over User,Notify: Flight Search Phase
    User->>Gateway: Search Flights
    Gateway->>Flight: Search Request
    Flight->>Cache: Check Cache
    alt Cache Hit
        Cache-->>Flight: Return Results
    else Cache Miss
        Flight->>DB: Query Database
        DB-->>Flight: Results
        Flight->>Cache: Update Cache
    end
    Flight-->>User: Display Flights

    Note over User,Notify: Booking Phase
    User->>Gateway: Book Flight
    Gateway->>Booking: Create Booking
    Booking->>DB: Save Booking
    Booking->>Kafka: BookingCreated Event
    Booking-->>User: Confirmation

    Note over User,Notify: Payment Phase
    User->>Payment: Process Payment
    Payment->>DB: Save Transaction
    Payment->>Kafka: PaymentSuccess Event
    Payment-->>User: Receipt

    Kafka->>Notify: Events
    Notify->>User: Email & SMS
```

---

## Database Architecture

Multi-layer data storage with replication and caching.

**Location**: `/docs/deployment/gcp-architecture.md`

```mermaid
graph TB
    subgraph "Application Layer"
        APP1[User Service]
        APP2[Flight Service]
        APP3[Booking Service]
    end
    
    subgraph "Primary Database"
        PRIMARY[(PostgreSQL Primary<br/>Read/Write)]
        REPLICA1[(Read Replica 1)]
        REPLICA2[(Read Replica 2)]
        
        PRIMARY -.Streaming Replication.-> REPLICA1
        PRIMARY -.Streaming Replication.-> REPLICA2
    end
    
    subgraph "Caching Layer"
        REDIS_M[(Redis Master)]
        REDIS_S[(Redis Replica)]
        
        REDIS_M -.Replication.-> REDIS_S
    end
    
    subgraph "Search & Analytics"
        ELASTIC[(Elasticsearch)]
        WAREHOUSE[(BigQuery)]
    end
    
    subgraph "Backup & Archive"
        BACKUP[Automated Backups<br/>Daily/Hourly]
        ARCHIVE[7-Year Archive<br/>Compliance]
    end

    APP1 -->|Write| PRIMARY
    APP2 -->|Write| PRIMARY
    APP3 -->|Write| PRIMARY
    
    APP1 -->|Read| REPLICA1
    APP2 -->|Read| REPLICA1
    
    APP1 -->|Cache| REDIS_M
    APP2 -->|Cache| REDIS_M
    
    APP2 -->|Search| ELASTIC
    
    PRIMARY --> BACKUP
    BACKUP --> ARCHIVE
    PRIMARY -.ETL.-> WAREHOUSE

    style PRIMARY fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style REDIS_M fill:#dc382d,stroke:#333,stroke-width:2px,color:#fff
    style ELASTIC fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
```

---

## Security Layers

Defense-in-depth security architecture.

**Location**: `/docs/deployment/gcp-architecture.md`

```mermaid
graph TB
    subgraph "Layer 1: Edge Security"
        WAF[Web Application Firewall]
        DDOS[DDoS Protection]
        CDN[CDN with SSL]
    end
    
    subgraph "Layer 2: Authentication"
        JWT[JWT Tokens]
        MFA[Multi-Factor Auth]
        OAUTH[OAuth 2.0]
    end
    
    subgraph "Layer 3: Authorization"
        RBAC[Role-Based Access]
        POLICY[Policy Enforcement]
    end
    
    subgraph "Layer 4: Data Protection"
        ENCRYPT_REST[Encryption at Rest<br/>AES-256]
        ENCRYPT_TRANSIT[TLS 1.3 in Transit]
        TOKENIZE[Card Tokenization]
    end
    
    subgraph "Layer 5: Monitoring"
        IDS[Intrusion Detection]
        AUDIT[Audit Logs]
        SIEM[Security Analytics]
    end
    
    subgraph "Compliance"
        PCI[PCI DSS]
        GDPR[GDPR]
        SOC2[SOC 2]
    end

    WAF --> JWT
    DDOS --> MFA
    CDN --> OAUTH
    
    JWT --> RBAC
    MFA --> RBAC
    OAUTH --> POLICY
    
    RBAC --> ENCRYPT_REST
    POLICY --> ENCRYPT_TRANSIT
    ENCRYPT_TRANSIT --> TOKENIZE
    
    TOKENIZE --> IDS
    IDS --> AUDIT
    AUDIT --> SIEM
    
    SIEM --> PCI
    SIEM --> GDPR
    SIEM --> SOC2

    style WAF fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
    style JWT fill:#fbbc04,stroke:#333,stroke-width:2px,color:#000
    style ENCRYPT_REST fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style PCI fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
```

---

## Deployment Pipeline

Complete CI/CD workflow from code to production.

**Location**: `/docs/deployment/gcp-architecture.md`

```mermaid
graph LR
    subgraph "Source"
        GIT[Git Repository]
    end
    
    subgraph "Build"
        TRIGGER[Cloud Build Trigger]
        COMPILE[Build & Compile]
        TEST[Unit Tests]
        SCAN[Security Scan]
    end
    
    subgraph "Artifact"
        REGISTRY[Container Registry]
    end
    
    subgraph "Deploy Staging"
        STG[Staging GKE]
        SMOKE[Smoke Tests]
    end
    
    subgraph "Deploy Production"
        APPROVAL[Manual Approval]
        CANARY[Canary 10%]
        BLUE_GREEN[Blue-Green Deploy]
        MONITOR[Health Monitoring]
    end
    
    subgraph "Post-Deploy"
        VERIFY[Verification Tests]
        ROLLBACK{Success?}
        COMPLETE[Deployment Complete]
    end

    GIT -->|Push| TRIGGER
    TRIGGER --> COMPILE
    COMPILE --> TEST
    TEST --> SCAN
    SCAN -->|Pass| REGISTRY
    
    REGISTRY --> STG
    STG --> SMOKE
    SMOKE -->|Pass| APPROVAL
    
    APPROVAL -->|Approved| CANARY
    CANARY --> BLUE_GREEN
    BLUE_GREEN --> MONITOR
    MONITOR --> VERIFY
    
    VERIFY --> ROLLBACK
    ROLLBACK -->|Yes| COMPLETE
    ROLLBACK -->|No| BLUE_GREEN

    style GIT fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style REGISTRY fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style APPROVAL fill:#fbbc04,stroke:#333,stroke-width:2px,color:#000
    style ROLLBACK fill:#ea4335,stroke:#333,stroke-width:2px,color:#fff
```

---

## GCP Cloud Architecture

Complete Google Cloud Platform deployment architecture.

**Location**: `/docs/deployment/gcp-architecture.md`

```mermaid
graph TB
    subgraph "Global Edge"
        CDN[Cloud CDN]
        ARMOR[Cloud Armor]
        LB[Global Load Balancer]
    end
    
    subgraph "US Region"
        subgraph "Compute"
            US_GKE[GKE Cluster]
            US_RUN[Cloud Run]
        end
        
        subgraph "Data"
            US_SQL[(Cloud SQL)]
            US_REDIS[(Memorystore)]
        end
    end
    
    subgraph "EU Region"
        subgraph "Compute EU"
            EU_GKE[GKE Cluster]
            EU_RUN[Cloud Run]
        end
        
        subgraph "Data EU"
            EU_SQL[(Cloud SQL)]
            EU_REDIS[(Memorystore)]
        end
    end
    
    subgraph "Shared Services"
        PUBSUB[Cloud Pub/Sub]
        STORAGE[Cloud Storage]
        BQ[BigQuery]
    end
    
    subgraph "Security"
        IAM[Cloud IAM]
        KMS[Cloud KMS]
        SECRET[Secret Manager]
    end
    
    subgraph "Operations"
        MONITOR[Cloud Monitoring]
        LOGGING[Cloud Logging]
        TRACE[Cloud Trace]
    end

    CDN --> ARMOR
    ARMOR --> LB
    
    LB --> US_GKE
    LB --> EU_GKE
    
    US_GKE --> US_SQL
    US_GKE --> US_REDIS
    US_GKE --> PUBSUB
    
    EU_GKE --> EU_SQL
    EU_GKE --> EU_REDIS
    EU_GKE --> PUBSUB
    
    US_SQL -.Replication.-> EU_SQL
    
    PUBSUB --> STORAGE
    PUBSUB --> BQ
    
    IAM --> US_GKE
    IAM --> EU_GKE
    KMS --> US_SQL
    KMS --> EU_SQL
    SECRET --> US_GKE
    
    US_GKE --> MONITOR
    EU_GKE --> MONITOR
    US_GKE --> LOGGING
    US_GKE --> TRACE

    style CDN fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style US_GKE fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
    style PUBSUB fill:#fbbc04,stroke:#333,stroke-width:2px,color:#000
```

---

## Monitoring & Observability

Three pillars of observability: Metrics, Logs, and Traces.

**Location**: `/docs/architecture/monitoring-observability.md`

```mermaid
graph TB
    subgraph "Applications"
        SERVICES[Microservices]
    end
    
    subgraph "Metrics Collection"
        PROM[Prometheus]
        GRAFANA[Grafana Dashboards]
    end
    
    subgraph "Log Aggregation"
        LOGS[Application Logs]
        ELASTIC[Elasticsearch]
        KIBANA[Kibana]
    end
    
    subgraph "Distributed Tracing"
        OTEL[OpenTelemetry]
        JAEGER[Jaeger]
    end
    
    subgraph "Alerting"
        ALERT_MGR[Alert Manager]
        PAGERDUTY[PagerDuty]
        SLACK[Slack]
    end
    
    subgraph "Analytics"
        BUSINESS[Business Metrics]
        TECHNICAL[Technical Metrics]
        SLO[SLO/SLA Tracking]
    end

    SERVICES -->|Metrics| PROM
    SERVICES -->|Logs| LOGS
    SERVICES -->|Traces| OTEL
    
    PROM --> GRAFANA
    PROM --> ALERT_MGR
    
    LOGS --> ELASTIC
    ELASTIC --> KIBANA
    
    OTEL --> JAEGER
    
    ALERT_MGR --> PAGERDUTY
    ALERT_MGR --> SLACK
    
    GRAFANA --> BUSINESS
    GRAFANA --> TECHNICAL
    GRAFANA --> SLO

    style PROM fill:#e6522c,stroke:#333,stroke-width:2px,color:#fff
    style ELASTIC fill:#34a853,stroke:#333,stroke-width:2px,color:#fff
    style JAEGER fill:#4285f4,stroke:#333,stroke-width:2px,color:#fff
```

---

## 🎨 Diagram Legend

### Colors Used

- **Blue (#4285f4)**: Primary services and databases
- **Green (#34a853)**: Supporting services and successful states
- **Yellow (#fbbc04)**: Warning states and decision points
- **Red (#ea4335)**: Critical services and error states

### Node Shapes

- **Rectangles**: Services and applications
- **Cylinders**: Databases and data stores
- **Diamonds**: Decision points
- **Circles/Ellipses**: External systems

### Line Styles

- **Solid arrows (→)**: Direct dependencies and data flow
- **Dashed arrows (--)**: Asynchronous communication
- **Dotted arrows (..)**: Replication or backup

---

## 📖 Additional Resources

For detailed implementation of each component, refer to:

1. **Architecture Details**: `/docs/architecture/README.md`
2. **Database Design**: `/docs/architecture/database-design.md`
3. **Security Design**: `/docs/architecture/security-design.md`
4. **GCP Deployment**: `/docs/deployment/gcp-architecture.md`
5. **API Documentation**: `/docs/api/README.md`

---

## 🔄 Diagram Updates

All diagrams in this guide are version-controlled and should be updated when:
- Architecture changes are made
- New services are added
- Deployment topology changes
- Security measures are updated

To update diagrams, simply modify the Mermaid code in the respective markdown files.
