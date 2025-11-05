# Booking System - Architecture Design

## Table of Contents
1. [High-Level Architecture](#high-level-architecture)
2. [Architecture Patterns](#architecture-patterns)
3. [Service Definitions](#service-definitions)
4. [Service Relationships](#service-relationships)
5. [External Dependencies](#external-dependencies)
6. [Communication Patterns](#communication-patterns)
7. [Data Storage Strategy](#data-storage-strategy)

## High-Level Architecture

### Use Case: Flight Booking System

This architecture is designed for a **flight booking system** that integrates with Global Distribution Systems (GDS) and airline APIs to search, book, and manage flight reservations.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  Web App  │  iOS App  │  Android App  │  Admin Dashboard  │  Partner API    │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          API GATEWAY LAYER                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  • Request Routing          • Rate Limiting         • API Versioning         │
│  • Authentication           • Load Balancing        • SSL Termination        │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      APPLICATION SERVICES LAYER                              │
├──────────────┬──────────────┬──────────────┬──────────────┬────────────────┤
│              │              │              │              │                │
│    User      │   Search     │   Booking    │   Payment    │  Notification  │
│   Service    │   Service    │   Service    │   Service    │    Service     │
│              │              │              │              │                │
├──────────────┼──────────────┼──────────────┼──────────────┼────────────────┤
│              │              │              │              │                │
│  Analytics   │   Review     │   (Optional: Pricing for markup/discounts)   │
│   Service    │   Service    │                                              │
│              │              │                                              │
└──────────────┴──────────────┴──────────────────────────────────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        ▼                          ▼                          ▼
┌──────────────┐         ┌─────────────────┐        ┌─────────────────────┐
│              │         │                 │        │                     │
│ Search/Book  │         │  GDS PROVIDERS  │        │   NDC DIRECT APIs   │
│  Services    │────────▶│  • Amadeus      │        │  • Delta            │
│              │         │  • Sabre        │        │  • United           │
│              │         │  • Travelport   │        │  • American         │
└──────────────┘         └─────────────────┘        └─────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA LAYER                                      │
├──────────────┬──────────────┬──────────────┬──────────────┬────────────────┤
│              │              │              │              │                │
│  PostgreSQL  │    Redis     │Elasticsearch │   MongoDB    │      S3        │
│  (Primary)   │   (Cache)    │   (Search)   │  (Logs/Docs) │    (Files)     │
│              │              │              │              │                │
└──────────────┴──────────────┴──────────────┴──────────────┴────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MESSAGE QUEUE LAYER                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│              RabbitMQ / Apache Kafka (Event Streaming)                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL SERVICES                                    │
├──────────────┬──────────────┬──────────────┬──────────────┬────────────────┤
│              │              │              │              │                │
│ Stripe/PayPal│   Twilio     │   SendGrid   │    AWS/GCP   │      CDN       │
│  (Payment)   │    (SMS)     │   (Email)    │    (Cloud)   │   (Content)    │
│              │              │              │              │                │
└──────────────┴──────────────┴──────────────┴──────────────┴────────────────┘
```

## Architecture Patterns

### Flight Booking Specific Patterns

#### 1. GDS Integration Pattern
Real-world flight booking systems don't own flight inventory. Instead, they integrate with:

**Global Distribution Systems (GDS)**:
- **Amadeus**: Market leader, extensive global coverage
- **Sabre**: Strong in North America
- **Travelport**: Includes Galileo, Worldspan, Apollo systems

**How it works**:
```mermaid
sequenceDiagram
    participant User
    participant SearchSvc as Search Service
    participant Cache as Redis Cache
    participant GDS as GDS Provider<br/>(Amadeus/Sabre)
    participant Airlines as Multiple Airlines
    
    User->>SearchSvc: Search flights (NYC to LAX)
    SearchSvc->>Cache: Check cached results
    
    alt Cache Hit (< 5 min old)
        Cache-->>SearchSvc: Return cached results
        SearchSvc-->>User: Display flights (< 200ms)
    else Cache Miss
        SearchSvc->>GDS: Low Fare Search API
        GDS->>Airlines: Query inventory from multiple airlines
        Airlines-->>GDS: Return availability & prices
        GDS-->>SearchSvc: Aggregated results (100+ flights)
        SearchSvc->>Cache: Cache results (TTL: 5 min)
        SearchSvc-->>User: Display flights (3-5 sec)
    end
```

**NDC (New Distribution Capability)**:
- Modern IATA standard for direct airline connections
- Bypasses GDS, connects directly to airlines
- Allows access to airline-specific offers (seats, baggage, meals)
- Lower distribution costs for airlines

**Flight Aggregation Strategy**:
```
Search Service
    ├── GDS Provider (Primary): Amadeus API
    ├── GDS Provider (Secondary): Sabre API
    ├── NDC Direct: Delta, United, American Airlines
    ├── Low-Cost Carriers: Ryanair, Southwest (Direct APIs)
    └── Cache Layer: Redis (5-minute TTL)
```

---

#### 2. PNR (Passenger Name Record) Management

**What is PNR?**
- Unique booking record identifier in GDS
- Contains passenger details, flight segments, pricing
- Format: 6-character alphanumeric (e.g., ABC123)
- Shared across airlines via GDS

**PNR Lifecycle**:
```
┌──────────────┐
│   [START]    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   QUOTED     │  ← Get fare quote from GDS
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   BOOKED     │  ← Create PNR (seats reserved, unpaid)
└──────┬───────┘    Time limit: 24-48 hours
       │
       ├──────────────────┐
       │                  │
       ▼                  ▼
┌──────────────┐    ┌──────────────┐
│   TICKETED   │    │  CANCELLED   │  ← Cancel before payment
└──────┬───────┘    └──────┬───────┘
       │                   │
       ▼                   │
┌──────────────┐           │
│  CHECKED-IN  │           │
└──────┬───────┘           │
       │                   │
       ▼                   │
┌──────────────┐           │
│    FLOWN     │           │
└──────┬───────┘           │
       │                   │
       ▼                   ▼
    [END]              [END]
```

---

### 1. Microservices Architecture
- **Principle**: Decompose application into small, independent services
- **Benefits**: 
  - Independent deployment and scaling
  - Technology diversity
  - Fault isolation
  - Team autonomy

### 2. Event-Driven Architecture
- **Principle**: Services communicate via asynchronous events
- **Benefits**:
  - Loose coupling
  - Better scalability
  - Resilience
  - Real-time processing

### 3. CQRS (Command Query Responsibility Segregation)
- **Principle**: Separate read and write operations
- **Benefits**:
  - Optimized read/write models
  - Better performance
  - Scalability
  - Applies to: Booking Service, Inventory Service

### 4. API Gateway Pattern
- **Principle**: Single entry point for all client requests
- **Benefits**:
  - Simplified client code
  - Cross-cutting concerns handling
  - Backend flexibility

### 5. Saga Pattern (Distributed Transactions)
- **Principle**: Manage distributed transactions across multiple services without 2PC (Two-Phase Commit)
- **Benefits**:
  - Maintains data consistency across services
  - Better fault tolerance
  - No distributed locks
  - Applies to: Flight Booking Flow

#### What is the Saga Pattern?

The Saga pattern is a way to manage **distributed transactions** across multiple microservices. Instead of using a traditional ACID transaction (which doesn't work across multiple databases/services), a saga breaks the transaction into a series of **local transactions**, each with its own **compensating transaction** to undo it if something fails.

#### Why Do We Need It?

In our flight booking system, a single booking involves multiple services:

```
Booking Flow Steps:
1. Verify Price (Search Service → GDS)
2. Create PNR (Booking Service → GDS)
3. Process Payment (Payment Service → Stripe)
4. Issue Ticket (Booking Service → GDS)
5. Send Notification (Notification Service)
```

**Problem**: What happens if Step 3 (Payment) fails after Step 2 (PNR created)?
- PNR is already created in the GDS
- Seats are reserved
- But customer hasn't paid!
- GDS will eventually charge you for the unpaid PNR

**Solution**: Saga Pattern with compensating transactions

---

#### How Saga Pattern Works in Flight Booking

There are two types of Saga patterns:

##### 1. Choreography-based Saga
Services communicate via events (no central coordinator)

##### 2. Orchestration-based Saga ⭐ (We use this)
A central orchestrator (Booking Service) coordinates the saga

---

#### Flight Booking Saga: Step-by-Step

```
┌─────────────────────────────────────────────────────────────────┐
│                  FLIGHT BOOKING SAGA FLOW                        │
│                  (Orchestration Pattern)                         │
└─────────────────────────────────────────────────────────────────┘

Step 1: VERIFY PRICE
┌──────────────────────────────────────────────────────────┐
│ Action:    BookingService → GDS.verifyPrice()           │
│ Success:   Continue to Step 2                           │
│ Failure:   Return error to user (nothing to compensate) │
│ Compensate: N/A (read-only operation)                   │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼ (Price OK)
                            
Step 2: CREATE PNR (Hold Seats)
┌──────────────────────────────────────────────────────────┐
│ Action:    BookingService → GDS.createPNR()             │
│            Store booking (status: PENDING_PAYMENT)       │
│            PNR: ABC123 created                           │
│ Success:   Continue to Step 3                           │
│ Failure:   Return error (PNR not created, stop here)    │
│ Compensate: GDS.cancelPNR(ABC123) ← if later step fails │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼ (PNR Created)
                            
Step 3: PROCESS PAYMENT 💰
┌──────────────────────────────────────────────────────────┐
│ Action:    BookingService → PaymentService.charge()     │
│            PaymentService → Stripe.charge()              │
│ Success:   Continue to Step 4                           │
│ Failure:   ⚠️  TRIGGER COMPENSATION!                     │
│ Compensate: Refund payment (if partially charged)       │
│            Cancel PNR (Step 2 rollback)                  │
└──────────────────────────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼ SUCCESS               ▼ FAILURE
                │                       │
        Step 4: Issue Ticket      COMPENSATION FLOW
                │                       │
                │                       └──────┐
                │                              │
Step 4: ISSUE E-TICKET                         │
┌────────────────────────────────────┐         │
│ Action:    BookingService →        │         │
│            GDS.issueTicket(ABC123) │         │
│            Update status: CONFIRMED│         │
│ Success:   Continue to Step 5      │         │
│ Failure:   ⚠️  TRIGGER COMPENSATION!│         │
│ Compensate: Cancel ticket          │         │
│            Refund payment           │         │
│            Cancel PNR               │         │
└────────────────────────────────────┘         │
                │                              │
                ▼ (Ticket Issued)              │
                                               │
Step 5: SEND NOTIFICATIONS                     │
┌────────────────────────────────────┐         │
│ Action:    BookingService →        │         │
│            NotificationService      │         │
│ Success:   Booking complete! ✅     │         │
│ Failure:   Log error (non-critical)│         │
│ Compensate: Retry notification     │         │
└────────────────────────────────────┘         │
                │                              │
                ▼                              │
         ┌─────────────┐                       │
         │  COMPLETED  │                       │
         └─────────────┘                       │
                                               │
                                               ▼
                               ┌─────────────────────────────┐
                               │   COMPENSATION FLOW         │
                               │   (Rollback Transactions)   │
                               └─────────────────────────────┘
                                               │
                                               ▼
                                   Step 3 Failed: Payment Failed
                                               │
                                    ┌──────────┴──────────┐
                                    │  Compensate Step 2  │
                                    │  Cancel PNR: ABC123 │
                                    └──────────┬──────────┘
                                               │
                                               ▼
                                    ┌──────────────────────┐
                                    │ Update booking       │
                                    │ status: FAILED       │
                                    │ Reason: Payment fail │
                                    └──────────┬───────────┘
                                               │
                                               ▼
                                    ┌──────────────────────┐
                                    │ Notify user:         │
                                    │ "Payment failed"     │
                                    └──────────────────────┘
```

---

#### Saga Implementation in Code

**Booking Service (Saga Orchestrator)**:

```javascript
class BookingService {
  
  async createFlightBooking(bookingRequest) {
    // Initialize saga state
    const sagaState = {
      bookingId: generateId(),
      status: 'STARTED',
      steps: [],
      compensations: []
    };
    
    try {
      // ────────────────────────────────────────
      // STEP 1: Verify Price
      // ────────────────────────────────────────
      console.log('Saga Step 1: Verify Price');
      const priceCheck = await this.gdsService.verifyPrice(
        bookingRequest.offerId
      );
      
      if (!priceCheck.available || priceCheck.price !== bookingRequest.expectedPrice) {
        throw new Error('Price changed or unavailable');
      }
      
      sagaState.steps.push({ step: 1, action: 'VERIFY_PRICE', status: 'SUCCESS' });
      
      // ────────────────────────────────────────
      // STEP 2: Create PNR (Critical!)
      // ────────────────────────────────────────
      console.log('Saga Step 2: Create PNR');
      const pnr = await this.gdsService.createPNR({
        flights: bookingRequest.flights,
        passengers: bookingRequest.passengers
      });
      
      // Save to database with PENDING status
      await this.bookingRepository.save({
        id: sagaState.bookingId,
        pnr: pnr.recordLocator,
        status: 'PENDING_PAYMENT',
        amount: priceCheck.price,
        ...bookingRequest
      });
      
      sagaState.steps.push({ 
        step: 2, 
        action: 'CREATE_PNR', 
        status: 'SUCCESS',
        pnr: pnr.recordLocator 
      });
      
      // Register compensation (rollback) for Step 2
      sagaState.compensations.push(async () => {
        console.log('COMPENSATE: Cancelling PNR', pnr.recordLocator);
        await this.gdsService.cancelPNR(pnr.recordLocator);
        await this.bookingRepository.updateStatus(
          sagaState.bookingId, 
          'CANCELLED'
        );
      });
      
      // ────────────────────────────────────────
      // STEP 3: Process Payment (Critical!)
      // ────────────────────────────────────────
      console.log('Saga Step 3: Process Payment');
      const payment = await this.paymentService.charge({
        amount: priceCheck.price,
        currency: priceCheck.currency,
        paymentMethod: bookingRequest.paymentToken,
        idempotencyKey: sagaState.bookingId // Prevent duplicate charges
      });
      
      sagaState.steps.push({ 
        step: 3, 
        action: 'PROCESS_PAYMENT', 
        status: 'SUCCESS',
        paymentId: payment.id 
      });
      
      // Register compensation for Step 3
      sagaState.compensations.push(async () => {
        console.log('COMPENSATE: Refunding payment', payment.id);
        await this.paymentService.refund(payment.id);
      });
      
      // ────────────────────────────────────────
      // STEP 4: Issue Ticket (Critical!)
      // ────────────────────────────────────────
      console.log('Saga Step 4: Issue Ticket');
      const ticket = await this.gdsService.issueTicket(pnr.recordLocator);
      
      // Update booking to CONFIRMED
      await this.bookingRepository.update(sagaState.bookingId, {
        status: 'CONFIRMED',
        eTicketNumber: ticket.ticketNumber,
        confirmedAt: new Date()
      });
      
      sagaState.steps.push({ 
        step: 4, 
        action: 'ISSUE_TICKET', 
        status: 'SUCCESS',
        ticketNumber: ticket.ticketNumber 
      });
      
      // Register compensation for Step 4 (void ticket)
      sagaState.compensations.push(async () => {
        console.log('COMPENSATE: Voiding ticket', ticket.ticketNumber);
        await this.gdsService.voidTicket(ticket.ticketNumber);
      });
      
      // ────────────────────────────────────────
      // STEP 5: Send Notifications (Non-critical)
      // ────────────────────────────────────────
      console.log('Saga Step 5: Send Notifications');
      // Fire and forget (async, non-blocking)
      this.notificationService.sendBookingConfirmation({
        bookingId: sagaState.bookingId,
        pnr: pnr.recordLocator,
        email: bookingRequest.email
      }).catch(err => {
        console.error('Notification failed (non-critical):', err);
      });
      
      sagaState.status = 'COMPLETED';
      
      // Return successful booking
      return {
        success: true,
        bookingId: sagaState.bookingId,
        pnr: pnr.recordLocator,
        ticketNumber: ticket.ticketNumber,
        status: 'CONFIRMED'
      };
      
    } catch (error) {
      // ════════════════════════════════════════════════════
      // SAGA FAILED - EXECUTE COMPENSATING TRANSACTIONS
      // ════════════════════════════════════════════════════
      console.error('Saga failed at step:', sagaState.steps.length + 1);
      console.error('Error:', error.message);
      
      sagaState.status = 'COMPENSATING';
      
      // Execute compensations in REVERSE order (LIFO)
      for (let i = sagaState.compensations.length - 1; i >= 0; i--) {
        try {
          console.log(`Executing compensation ${i + 1}/${sagaState.compensations.length}`);
          await sagaState.compensations[i]();
        } catch (compensationError) {
          console.error('Compensation failed:', compensationError);
          // Log to monitoring system (critical!)
          this.monitoringService.alert({
            severity: 'CRITICAL',
            message: 'Saga compensation failed',
            sagaState,
            error: compensationError
          });
        }
      }
      
      sagaState.status = 'COMPENSATED';
      
      // Update booking status to FAILED
      await this.bookingRepository.updateStatus(
        sagaState.bookingId, 
        'FAILED'
      );
      
      // Return failure to user
      return {
        success: false,
        bookingId: sagaState.bookingId,
        error: error.message,
        failedAt: sagaState.steps[sagaState.steps.length - 1]?.action
      };
    }
  }
}
```

---

#### Key Concepts Explained

##### 1. **Local Transactions**
Each step is a local transaction in its own service:
- Step 2: Write to PostgreSQL (booking record)
- Step 3: Charge via Stripe (payment transaction)
- Step 4: Call GDS API (ticket issuance)

##### 2. **Compensating Transactions**
For each step that modifies state, we define how to **undo** it:
- Step 2 compensation: `cancelPNR()`
- Step 3 compensation: `refundPayment()`
- Step 4 compensation: `voidTicket()`

##### 3. **Execution Order**
- **Forward**: Steps execute in order (1 → 2 → 3 → 4 → 5)
- **Rollback**: Compensations execute in **reverse** order (4 → 3 → 2)

##### 4. **Idempotency**
Each operation must be idempotent (safe to retry):
```javascript
// Use idempotency key to prevent duplicate charges
const payment = await stripe.charge({
  amount: 45680,
  idempotencyKey: bookingId // Same key = same charge
});
```

##### 5. **Saga State Persistence**
Store saga state in database for recovery:
```javascript
{
  "sagaId": "saga_123",
  "bookingId": "bkg_456",
  "status": "COMPENSATING",
  "steps": [
    { "step": 1, "action": "VERIFY_PRICE", "status": "SUCCESS" },
    { "step": 2, "action": "CREATE_PNR", "status": "SUCCESS", "pnr": "ABC123" },
    { "step": 3, "action": "PROCESS_PAYMENT", "status": "FAILED" }
  ],
  "currentStep": 3,
  "lastError": "Card declined"
}
```

---

#### Common Failure Scenarios

##### Scenario 1: Payment Fails

```
✅ Step 1: Price verified
✅ Step 2: PNR created (ABC123)
❌ Step 3: Payment FAILED (card declined)

COMPENSATION TRIGGERED:
  ↓
💡 Compensate Step 2: Cancel PNR ABC123
  ↓
✅ Booking status: FAILED
  ↓
📧 Notify user: "Payment failed, please try again"
```

##### Scenario 2: Ticket Issuance Fails

```
✅ Step 1: Price verified
✅ Step 2: PNR created (ABC123)
✅ Step 3: Payment successful ($456.80 charged)
❌ Step 4: Ticket issuance FAILED (GDS timeout)

COMPENSATION TRIGGERED:
  ↓
💡 Compensate Step 3: Refund $456.80
  ↓
💡 Compensate Step 2: Cancel PNR ABC123
  ↓
✅ Booking status: FAILED
  ↓
📧 Notify user: "Booking failed, refund processed"
```

##### Scenario 3: Partial Compensation Failure (Worst Case!)

```
✅ Step 1: Price verified
✅ Step 2: PNR created (ABC123)
✅ Step 3: Payment successful ($456.80 charged)
❌ Step 4: Ticket issuance FAILED

COMPENSATION TRIGGERED:
  ↓
💡 Try to refund payment... ❌ FAILED (Stripe timeout)
  ↓
🚨 CRITICAL ALERT: Manual intervention required!
  ↓
📊 Log to incident management system
  ↓
👨‍💼 Customer support team notified
  ↓
🔄 Retry compensation job (scheduled)
```

**Handling**:
- Retry compensation with exponential backoff
- Alert operations team
- Create ticket in incident management system
- Manual reconciliation if retries fail

---

#### Benefits of Saga Pattern

✅ **No Distributed Locks**: Each service uses its own database
✅ **Better Performance**: No blocking on 2PC coordinator
✅ **Fault Tolerance**: Can recover from partial failures
✅ **Scalability**: Services remain independent
✅ **Clear Rollback Logic**: Explicit compensations
✅ **Auditability**: Complete transaction history

#### Challenges

⚠️ **Complexity**: More code than simple ACID transaction
⚠️ **Eventual Consistency**: Brief inconsistency during compensation
⚠️ **Compensation Failures**: Need retry + manual fallback
⚠️ **Testing**: Complex failure scenarios to test

---

#### Saga Pattern vs Traditional Transaction

**Traditional ACID Transaction** (NOT possible in microservices):
```sql
BEGIN TRANSACTION;
  INSERT INTO bookings (...);
  INSERT INTO payments (...);
  -- Call external GDS API ❌ Can't include in transaction!
COMMIT;
```

**Saga Pattern** (Microservices):
```
Transaction 1: Create PNR → Can rollback with cancelPNR()
Transaction 2: Charge payment → Can rollback with refund()
Transaction 3: Issue ticket → Can rollback with voidTicket()
```

---

#### Monitoring & Observability

**Metrics to Track**:
- Saga success rate
- Average compensation rate
- Failed compensation count (critical!)
- Saga execution time per step

**Alerts**:
- Compensation failure (page on-call engineer)
- High compensation rate (> 5%)
- Saga timeout (> 60 seconds)

**Logging**:
```json
{
  "sagaId": "saga_123",
  "timestamp": "2025-11-05T10:30:00Z",
  "event": "STEP_COMPLETED",
  "step": 2,
  "action": "CREATE_PNR",
  "duration_ms": 3420,
  "pnr": "ABC123"
}
```

---

## Service Definitions

### Core Services for Flight Booking

**Essential Services** (Required):
1. ✅ **User Service** - Authentication and user management
2. ✅ **Search Service** - Query GDS for flight options
3. ✅ **Booking Service** - Create PNR, manage bookings
4. ✅ **Payment Service** - Process payments
5. ✅ **Notification Service** - Email/SMS confirmations

**Optional Services** (Nice to have):
6. 🔸 **Analytics Service** - Business intelligence and metrics
7. 🔸 **Review Service** - User reviews and ratings
8. 🔸 **Pricing Service** - Only if you add markup/discounts/promotions

**NOT Needed for Flight Booking** (GDS handles these):
- ❌ **Inventory Service** - Airlines manage inventory via GDS
- ❌ **Resource Service** - Flight data comes from GDS APIs

---

### 1. User Service

**Purpose**: Manage user accounts, authentication, and profiles

**Responsibilities**:
- User registration and login
- Authentication token generation (JWT)
- Profile management
- Session management
- Password reset and recovery
- User preferences and settings

**Technology Stack**:
- Runtime: Node.js / Go
- Database: PostgreSQL (user data)
- Cache: Redis (sessions, tokens)

**Endpoints**:
- `POST /auth/register` - Register new user
- `POST /auth/login` - User login
- `POST /auth/refresh` - Refresh token
- `GET /users/{id}` - Get user profile
- `PUT /users/{id}` - Update profile
- `POST /auth/reset-password` - Reset password

**Dependencies**:
- Redis (session storage)
- PostgreSQL (user data)
- Notification Service (email verification)

---

### 2. Search Service

**Purpose**: Enable fast and efficient flight search across multiple sources

**Responsibilities**:
- Aggregate flights from GDS providers (Amadeus, Sabre)
- Query direct airline NDC APIs
- Merge and deduplicate results
- Apply filters (price, stops, airlines, duration)
- Sort results (price, duration, best value)
- Cache search results
- Track search analytics

**Technology Stack**:
- Runtime: Go / Java (high-performance)
- GDS SDKs: Amadeus Self-Service APIs, Sabre REST APIs
- Cache: Redis (search results with 5-min TTL)
- Database: PostgreSQL (search history, popular routes)

**Endpoints**:
- `POST /search/flights` - Search flights
- `GET /search/flight-offers/{offerId}` - Get specific offer details
- `POST /search/price-calendar` - Get cheapest dates
- `GET /search/autocomplete` - Airport/city autocomplete
- `POST /search/multi-city` - Multi-city search

**Flight Search Request Example**:
```json
POST /search/flights
{
  "origin": "JFK",
  "destination": "LAX",
  "departureDate": "2025-12-15",
  "returnDate": "2025-12-22",
  "passengers": {
    "adults": 2,
    "children": 1,
    "infants": 0
  },
  "cabinClass": "ECONOMY",
  "directFlightsOnly": false,
  "maxStops": 1,
  "preferredAirlines": ["UA", "AA", "DL"]
}
```

**Flight Search Response Example**:
```json
{
  "searchId": "search_123abc",
  "results": [
    {
      "offerId": "offer_xyz789",
      "source": "AMADEUS_GDS",
      "validUntil": "2025-11-05T15:30:00Z",
      "price": {
        "total": 456.80,
        "currency": "USD",
        "breakdown": {
          "baseFare": 380.00,
          "taxes": 76.80
        }
      },
      "outbound": {
        "segments": [
          {
            "flight": "UA1234",
            "airline": "United Airlines",
            "departure": {
              "airport": "JFK",
              "terminal": "4",
              "time": "2025-12-15T08:00:00"
            },
            "arrival": {
              "airport": "LAX",
              "terminal": "7",
              "time": "2025-12-15T11:30:00"
            },
            "duration": "6h 30m",
            "aircraft": "Boeing 777-200",
            "cabinClass": "ECONOMY",
            "bookingClass": "Y",
            "baggageAllowance": "1 checked bag"
          }
        ],
        "totalDuration": "6h 30m",
        "stops": 0
      },
      "return": { /* similar structure */ },
      "amenities": ["wifi", "power", "entertainment"]
    }
  ],
  "pagination": {
    "page": 1,
    "total": 87
  },
  "filters": {
    "airlines": ["UA", "AA", "DL", "B6"],
    "priceRange": { "min": 320, "max": 1200 },
    "stops": [0, 1, 2]
  }
}
```

**GDS Integration Flow**:
```mermaid
sequenceDiagram
    participant Client
    participant SearchSvc as Search Service
    participant Cache
    participant Amadeus as Amadeus GDS
    participant Sabre as Sabre GDS
    participant NDC as Airline NDC APIs
    
    Client->>SearchSvc: POST /search/flights
    SearchSvc->>Cache: Check cache (key: origin+dest+date)
    
    alt Cache exists & fresh
        Cache-->>SearchSvc: Return cached results
        SearchSvc-->>Client: Return results (< 200ms)
    else Cache miss or stale
        par Parallel GDS Queries
            SearchSvc->>Amadeus: Flight Offers Search API
            SearchSvc->>Sabre: BargainFinderMax API
            SearchSvc->>NDC: Query direct airlines
        end
        
        Amadeus-->>SearchSvc: Results (50 offers)
        Sabre-->>SearchSvc: Results (45 offers)
        NDC-->>SearchSvc: Results (12 offers)
        
        SearchSvc->>SearchSvc: Merge & deduplicate (107 results)
        SearchSvc->>SearchSvc: Apply filters & sorting
        SearchSvc->>Cache: Store results (TTL: 5 min)
        SearchSvc-->>Client: Return sorted results (3-5 sec)
    end
```

**Caching Strategy**:
- **Search Results**: 5-minute TTL (prices change frequently)
- **Airport Data**: 24-hour TTL (rarely changes)
- **Popular Routes**: 1-hour TTL
- **Cache Key Pattern**: `flight:search:{origin}:{dest}:{date}:{passengers}:{class}`

**Dependencies**:
- Redis (cache)
- Amadeus API (primary GDS)
- Sabre API (secondary GDS)
- Airline NDC APIs (direct connections)
- PostgreSQL (search analytics, popular routes)

**Challenges & Solutions**:

| Challenge | Solution |
|-----------|----------|
| Different GDS response formats | Adapter pattern to normalize responses |
| API rate limits | Request queuing, multiple API credentials |
| Slow GDS responses (2-5s) | Parallel queries, aggressive caching |
| Price volatility | Short cache TTL, real-time price verification |
| Duplicate flights across GDS | Deduplication by flight number + times |

---

### 3. Booking Service

**Purpose**: Flight booking operations and PNR management

**Responsibilities**:
- Create PNR (Passenger Name Record) in GDS
- Price verification before booking
- Passenger details validation
- Ticket issuance
- Booking modifications (rebooking, upgrades)
- Cancellations and refunds
- Split PNR handling (multiple passengers)
- Ancillary services (seat selection, baggage, meals)

**Technology Stack**:
- Runtime: Java / Go
- Database: PostgreSQL (bookings, PNRs)
- Cache: Redis (booking locks, PNR cache)
- Message Queue: RabbitMQ/Kafka

**Endpoints**:
- `POST /bookings/verify-price` - Verify current price
- `POST /bookings/create` - Create booking & PNR
- `POST /bookings/{id}/ticket` - Issue ticket
- `GET /bookings/{id}` - Get booking details
- `GET /bookings/pnr/{pnr}` - Retrieve by PNR
- `POST /bookings/{id}/cancel` - Cancel booking
- `POST /bookings/{id}/modify` - Modify booking
- `POST /bookings/{id}/ancillaries` - Add seat/baggage/meal

**Flight Booking Flow**:
```mermaid
sequenceDiagram
    participant User
    participant BookingSvc as Booking Service
    participant GDS as Amadeus GDS
    participant PaymentSvc as Payment Service
    participant NotifSvc as Notification Service
    
    User->>BookingSvc: Select flight offer
    
    Note over BookingSvc,GDS: Step 1: Verify Price
    BookingSvc->>GDS: Flight Price Verification API
    GDS-->>BookingSvc: Confirmed price & availability
    
    alt Price changed or unavailable
        BookingSvc-->>User: Price changed notification
    else Price confirmed
        User->>BookingSvc: Enter passenger details
        
        Note over BookingSvc,GDS: Step 2: Create PNR (Hold)
        BookingSvc->>GDS: Create PNR (without ticketing)
        GDS-->>BookingSvc: PNR created (ABC123)
        BookingSvc->>BookingSvc: Store booking (status: PENDING)
        
        Note over BookingSvc,PaymentSvc: Step 3: Process Payment
        BookingSvc->>PaymentSvc: Charge customer
        PaymentSvc-->>BookingSvc: Payment successful
        
        Note over BookingSvc,GDS: Step 4: Issue Ticket
        BookingSvc->>GDS: Ticket Issuance API
        GDS-->>BookingSvc: E-ticket number (0012345678901)
        
        BookingSvc->>BookingSvc: Update status: CONFIRMED
        BookingSvc->>NotifSvc: Send confirmation
        NotifSvc-->>User: Email with e-ticket
        
        BookingSvc-->>User: Booking confirmed
    end
```

**Create Booking Request**:
```json
POST /bookings/create
{
  "offerId": "offer_xyz789",
  "searchId": "search_123abc",
  "passengers": [
    {
      "type": "ADULT",
      "title": "MR",
      "firstName": "John",
      "lastName": "Doe",
      "dateOfBirth": "1985-06-15",
      "gender": "M",
      "nationality": "US",
      "passportNumber": "X12345678",
      "passportExpiry": "2028-06-15",
      "email": "john.doe@example.com",
      "phone": "+1234567890",
      "frequentFlyer": {
        "airline": "UA",
        "number": "MileagePlus123456"
      }
    }
  ],
  "contactDetails": {
    "email": "john.doe@example.com",
    "phone": "+1234567890"
  },
  "ancillaries": {
    "seats": [
      {
        "passengerId": 0,
        "segment": 0,
        "seatNumber": "12A"
      }
    ],
    "baggage": [
      {
        "passengerId": 0,
        "extraBags": 1
      }
    ],
    "meals": [
      {
        "passengerId": 0,
        "segment": 0,
        "mealType": "VEGETARIAN"
      }
    ]
  },
  "paymentMethod": "credit_card",
  "paymentToken": "tok_xyz123"
}
```

**Booking Response**:
```json
{
  "bookingId": "bkg_456789",
  "pnr": "ABC123",
  "status": "CONFIRMED",
  "eTickets": [
    {
      "passengerId": 0,
      "ticketNumber": "0012345678901",
      "passengerName": "DOE/JOHN MR"
    }
  ],
  "flights": {
    "outbound": { /* flight details */ },
    "return": { /* flight details */ }
  },
  "price": {
    "total": 456.80,
    "currency": "USD"
  },
  "confirmationCode": "ABC123XYZ",
  "timeLimit": "2025-11-06T10:00:00Z",
  "createdAt": "2025-11-05T10:30:00Z"
}
```

**Key Operations**:

**1. Price Verification**:
- Always verify price before creating PNR
- Flight prices change rapidly (supply/demand)
- GDS API: `Flight_PriceFlightOffersPost`

**2. PNR Creation**:
- Creates reservation in GDS without payment
- Has time limit (usually 24-48 hours)
- Can be cancelled without penalty before ticketing

**3. Ticket Issuance**:
- Final step after payment
- Generates e-ticket number
- Non-refundable or refundable based on fare rules

**4. Split PNR**:
- One PNR per passenger or group
- Important for separate bookings

**Dependencies**:
- PostgreSQL (booking data)
- Amadeus GDS (PNR creation, ticketing)
- Payment Service (payment processing)
- Notification Service (confirmations)
- User Service (user validation)

**Key Patterns**:
- **Saga Pattern**: Distributed transaction (PNR → Payment → Ticketing)
- **Compensating Transactions**: Cancel PNR if payment fails
- **Time-Limited Holds**: Auto-cancel unpaid bookings after time limit
- **Idempotency**: Prevent duplicate bookings with idempotency keys

---

### 4. Payment Service

**Purpose**: Handle all payment-related operations

**Responsibilities**:
- Payment processing
- Payment gateway integration
- Transaction management
- Refund processing
- Payment retry logic
- Payment status tracking
- Invoice generation

**Technology Stack**:
- Runtime: Java / Node.js
- Database: PostgreSQL (transactions)
- Message Queue: RabbitMQ/Kafka

**Endpoints**:
- `POST /payments/process` - Process payment
- `POST /payments/refund` - Process refund
- `GET /payments/{id}` - Get payment details
- `POST /payments/retry` - Retry failed payment

**Dependencies**:
- PostgreSQL (payment records)
- Stripe/PayPal API (payment gateway)
- Booking Service (booking confirmation)
- Notification Service (payment receipts)

**Key Patterns**:
- **Idempotency**: Prevent duplicate charges
- **Retry with Exponential Backoff**: Handle failures
- **PCI DSS Compliance**: Security standards

---

### 5. Notification Service

**Purpose**: Multi-channel notification delivery

**Responsibilities**:
- Email notifications
- SMS notifications
- Push notifications
- In-app notifications
- Template management
- Delivery tracking
- Retry failed deliveries

**Technology Stack**:
- Runtime: Python / Node.js
- Database: MongoDB (notification logs)
- Message Queue: RabbitMQ/Kafka
- Cache: Redis (notification queue)

**Endpoints**:
- `POST /notifications/send` - Send notification
- `GET /notifications/{id}` - Get notification status
- `GET /users/{userId}/notifications` - Get user notifications

**Dependencies**:
- SendGrid (email)
- Twilio (SMS)
- Firebase Cloud Messaging (push)
- MongoDB (logs)
- RabbitMQ (message queue)

**Key Patterns**:
- **Queue-based Processing**: Async delivery
- **Template Engine**: Dynamic content
- **Circuit Breaker**: Handle provider failures

---

### 6. Analytics Service

**Purpose**: Business intelligence and reporting

**Responsibilities**:
- Booking metrics and KPIs
- Revenue analytics
- User behavior tracking
- Performance monitoring
- Custom reports generation
- Data aggregation

**Technology Stack**:
- Runtime: Python
- Database: MongoDB (analytics data)
- Data Warehouse: PostgreSQL / BigQuery
- Cache: Redis

**Endpoints**:
- `GET /analytics/bookings` - Booking metrics
- `GET /analytics/revenue` - Revenue reports
- `GET /analytics/users` - User analytics

**Dependencies**:
- MongoDB (event logs)
- PostgreSQL (aggregated data)
- All services (event consumption)

---

### 7. Review Service

**Purpose**: User reviews and ratings

**Responsibilities**:
- Create and manage reviews
- Rating calculations
- Review moderation
- Review analytics
- Reputation scoring

**Technology Stack**:
- Runtime: Node.js
- Database: PostgreSQL (reviews)
- Cache: Redis (aggregated ratings)

**Endpoints**:
- `POST /reviews` - Create review
- `GET /resources/{id}/reviews` - Get reviews
- `GET /users/{id}/reviews` - Get user reviews

**Dependencies**:
- PostgreSQL (reviews)
- Booking Service (verify booking)

---

### 8. Pricing Service (Optional for Flight Booking)

**Purpose**: Add markup, discounts, and promotions on top of GDS prices

**Why Optional?**
- GDS already provides flight prices
- Airlines set the base fares
- Only needed if you want to add business logic on top

**Use Cases**:
- Apply markup/commission to GDS prices
- Promotional discounts and coupon codes
- Loyalty points redemption
- Corporate/group booking discounts
- Currency conversion with custom exchange rates
- Service fees calculation

**Technology Stack**:
- Runtime: Python / Java
- Database: PostgreSQL (pricing rules, promotions)
- Cache: Redis (calculated prices)

**Endpoints**:
- `POST /pricing/calculate-final` - Add markup to GDS price
- `POST /pricing/apply-promo` - Apply promo code
- `POST /pricing/redeem-points` - Calculate loyalty points value
- `GET /pricing/promotions` - Get active promotions

**Example Flow**:
```
GDS Price: $400.00
  ↓
Your markup: +$20.00 (5%)
Promo code: -$30.00
Service fee: +$15.00
  ↓
Final price: $405.00
```

**Dependencies**:
- PostgreSQL (pricing rules, promotions)
- Redis (price cache)
- Booking Service (price validation)
- User Service (loyalty program data)

**When to Build**:
- ✅ You want to add markup on flights
- ✅ You offer promotional discounts
- ✅ You have a loyalty/rewards program
- ❌ You're just starting (keep it simple, skip this)

---

## Service Relationships

### Service Interaction Diagram

```
                            ┌──────────────┐
                            │  API Gateway │
                            └──────┬───────┘
                                   │
                   ┌───────────────┼───────────────┐
                   │               │               │
                   ▼               ▼               ▼
            ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
            │    User     │ │   Search    │ │   Booking   │
            │   Service   │ │   Service   │ │   Service   │
            └─────────────┘ └──────┬──────┘ └──────┬──────┘
                                   │               │
                   ┌───────────────┴───────────────┤
                   │                               │
                   ▼                               ▼
            ┌─────────────┐                 ┌─────────────┐
            │  GDS APIs   │                 │   Payment   │
            │  (Amadeus,  │                 │   Service   │
            │   Sabre)    │                 └──────┬──────┘
            └──────┬──────┘                        │
                   │                               │
                   │                               ▼
                   │                        ┌─────────────┐
                   │                        │Notification │
                   │                        │   Service   │
                   │                        └──────┬──────┘
                   │                               │
                   │                               │ (async)
                   │                               ▼
                   │                        ┌─────────────┐
                   │                        │  Analytics  │
                   │                        │   Service   │
                   │                        └─────────────┘
                   │
                   ▼
         ┌──────────────────┐
         │  Airlines'       │
         │  Inventory &     │
         │  Pricing Systems │
         └──────────────────┘

Key Dependencies:
─────  Synchronous REST calls
- - -  Asynchronous event-based communication

Note: Inventory & Pricing managed by GDS/Airlines, not separate services
```

### Service Dependencies Matrix

| Service       | Depends On |
|---------------|------------|
| User Service  | PostgreSQL, Redis, Notification Service |
| Search Service | Redis, Amadeus GDS, Sabre GDS, Airline NDC APIs |
| Booking Service | PostgreSQL, Redis, Amadeus GDS, Payment Service, Notification Service, User Service |
| Payment Service | PostgreSQL, Stripe/PayPal, Booking Service, Notification Service |
| Notification Service | MongoDB, RabbitMQ, SendGrid, Twilio, FCM |
| Analytics Service | MongoDB, PostgreSQL, All Services (events) |
| Review Service | PostgreSQL, Redis, Booking Service |

**Note**: For flight booking systems:
- **No Inventory Service needed** - GDS manages airline inventory
- **No Resource Service needed** - Flight data comes from GDS
- **Pricing Service optional** - Only if you add markup/discounts on top of GDS prices

## External Dependencies

### 1. Database Layer

#### PostgreSQL (Primary Database)
**Purpose**: Transactional data storage

**Used By**:
- User Service (users, profiles)
- Booking Service (bookings, transactions)
- Inventory Service (inventory, capacity)
- Payment Service (payment records)
- Resource Service (resources, metadata)
- Pricing Service (pricing rules)
- Review Service (reviews, ratings)

**Configuration**:
- Master-Slave replication for read scaling
- Connection pooling (PgBouncer)
- Partitioning by date for bookings table
- Indexes on frequently queried columns

---

#### Redis (Cache & Session Store)
**Purpose**: Caching, session management, distributed locks

**Used By**:
- User Service (sessions, tokens)
- Search Service (search results cache)
- Booking Service (locks, active bookings)
- Inventory Service (availability cache, holds)
- Resource Service (resource cache)
- Pricing Service (calculated prices)

**Data Patterns**:
- **Sessions**: TTL 24 hours
- **Locks**: TTL 5 minutes
- **Holds**: TTL 15 minutes
- **Cache**: TTL varies by data type

---

#### Elasticsearch (Search Engine)
**Purpose**: Full-text search and analytics

**Used By**:
- Search Service (resource indexing)
- Analytics Service (log analysis)

**Configuration**:
- Cluster with 3+ nodes
- Replicas for high availability
- Index aliases for zero-downtime reindexing

---

#### MongoDB (Document Store)
**Purpose**: Logs, notifications, analytics events

**Used By**:
- Notification Service (notification logs)
- Analytics Service (event logs, metrics)

**Configuration**:
- Replica set for high availability
- Sharding for large datasets
- TTL indexes for log rotation

---

#### S3 / Object Storage
**Purpose**: File and media storage

**Used By**:
- Resource Service (images, documents)
- User Service (profile pictures)
- Analytics Service (report exports)

**Configuration**:
- Public bucket with CDN
- Private bucket for user data
- Lifecycle policies for archival

---

### 2. Message Queue Layer

#### RabbitMQ / Apache Kafka
**Purpose**: Asynchronous messaging and event streaming

**Usage Patterns**:

**Event Publishing** (Producers):
- Booking Service → `booking.created`, `booking.cancelled`
- Payment Service → `payment.completed`, `payment.failed`
- User Service → `user.registered`, `user.updated`
- Inventory Service → `inventory.updated`

**Event Consumption** (Consumers):
- Notification Service → All events for notifications
- Analytics Service → All events for analytics
- Search Service → Resource and inventory events
- Inventory Service → Booking events

**Configuration**:
- Durable queues for critical events
- Dead letter queues for failed messages
- Message TTL and retry policies

---

### 3. Flight Distribution Systems (GDS & NDC)

#### Global Distribution Systems (GDS)

**What is GDS?**
- Centralized reservation systems connecting airlines, travel agencies, and booking platforms
- Store real-time airline inventory, fares, and schedules
- Industry standard for flight bookings worldwide

**Major GDS Providers**:

**1. Amadeus**
- Market leader (~40% market share)
- Strong in Europe, Asia, Latin America
- **APIs Used**:
  - `Flight Offers Search` - Search flights
  - `Flight Offers Price` - Price verification
  - `Flight Create Orders` - Create booking
  - `Flight Order Management` - Ticketing, modifications
- **Pricing**: Pay-per-transaction (~$0.50-2.00 per search)
- **Integration**: REST APIs, SOAP (legacy)

**2. Sabre**
- Strong in North America (~35% market share)
- **APIs Used**:
  - `BargainFinderMax` - Low fare search
  - `EnhancedAirBook` - Create PNR
  - `InstaFlights Search` - Fast cached search
  - `TravelItinerary` - PNR management
- **Pricing**: Subscription + transaction fees
- **Integration**: REST APIs, SOAP

**3. Travelport**
- Includes Galileo, Worldspan, Apollo (~25% market share)
- **APIs Used**:
  - `Air Low Fare Search` - Search
  - `Air Price` - Pricing
  - `Universal Record` - Booking management
- **Pricing**: Pay-per-transaction
- **Integration**: XML-based APIs

**GDS Integration Architecture**:
```
┌─────────────────────────────────────────────────────────────────┐
│                      YOUR SYSTEM                                 │
│                                                                  │
│  ┌──────────────┐                    ┌──────────────┐          │
│  │    Search    │                    │   Booking    │          │
│  │   Service    │                    │   Service    │          │
│  └──────┬───────┘                    └──────┬───────┘          │
│         │                                    │                  │
│         └────────────────┬───────────────────┘                  │
│                          │                                      │
│                          ▼                                      │
│              ┌───────────────────────┐                          │
│              │   GDS Adapter Layer   │                          │
│              │  (Normalize formats)  │                          │
│              └───────────┬───────────┘                          │
│                          │                                      │
└──────────────────────────┼──────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │  Amadeus    │ │   Sabre     │ │ Travelport  │
    │     GDS     │ │    GDS      │ │     GDS     │
    └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
           │               │               │
           └───────────────┼───────────────┘
                           │
           ┌───────────────┴───────────────┐
           │                               │
           ▼                               ▼
    ┌─────────────┐                 ┌─────────────┐
    │  American   │                 │   British   │
    │   Airlines  │   ... 400+      │   Airways   │
    │             │    Airlines     │             │
    └─────────────┘                 └─────────────┘

Benefits of Adapter Layer:
• Normalize different GDS API formats
• Easy to switch or add providers
• Centralized error handling
• Rate limiting and retry logic
• Response caching
```

**Why Use GDS Adapter Layer?**
- Normalize different GDS API formats
- Easy to switch or add GDS providers
- Centralized error handling
- Rate limiting and retry logic
- Response caching

**Adapter Pattern Implementation**:
```javascript
// Pseudo-code example
interface GDSProvider {
  searchFlights(params): FlightResults
  createBooking(params): Booking
  issueTicket(pnr): Ticket
}

class AmadeusAdapter implements GDSProvider {
  searchFlights(params) {
    // Convert to Amadeus format
    // Call Amadeus API
    // Normalize response
  }
}

class SabreAdapter implements GDSProvider {
  searchFlights(params) {
    // Convert to Sabre format
    // Call Sabre API
    // Normalize response
  }
}

// Usage
const gdsProviders = [
  new AmadeusAdapter(),
  new SabreAdapter()
]

// Parallel search across all providers
const results = await Promise.all(
  gdsProviders.map(gds => gds.searchFlights(params))
)
```

---

#### NDC (New Distribution Capability)

**What is NDC?**
- XML-based data standard by IATA (International Air Transport Association)
- Direct connection between airlines and booking platforms
- Bypasses GDS, reducing distribution costs
- Enables rich content (seat maps, ancillaries)

**Benefits over GDS**:
- Lower transaction fees
- Access to airline-exclusive offers
- Real-time pricing and availability
- Better ancillary options (seats, bags, meals)

**NDC vs GDS Comparison**:

| Feature | GDS | NDC |
|---------|-----|-----|
| Distribution | Centralized | Direct to airline |
| Cost | $0.50-2.00 per transaction | Lower or free |
| Content | Standard fares | Airline-specific offers |
| Ancillaries | Limited | Full range |
| Integration | One API for many airlines | One API per airline |
| Adoption | Universal | Growing (~40 airlines) |

**NDC-Enabled Airlines**:
- Lufthansa Group (mandatory NDC since 2015)
- American Airlines
- United Airlines
- Delta Air Lines
- Air France-KLM
- British Airways
- Qatar Airways

**Integration Strategy**:
```
Primary: GDS (Amadeus) - 80% of searches
  ↓
  Comprehensive coverage
  Single integration point
  
Secondary: NDC Direct APIs - 20% of searches
  ↓
  Airline-exclusive offers
  Better margins
  Premium content
```

---

### 4. External Services

#### Payment Gateways
**Providers**: Stripe, PayPal, Square

**Integration**:
- Payment Service acts as abstraction layer
- Webhook handling for async updates
- PCI DSS compliant implementation
- Multiple gateway support for redundancy

---

#### Communication Services

**SendGrid (Email)**:
- Transactional emails
- Marketing campaigns
- Email templates
- Delivery tracking

**Twilio (SMS)**:
- OTP verification
- Booking confirmations
- Reminders
- Alerts

**Firebase Cloud Messaging (Push)**:
- Mobile app notifications
- Real-time updates
- Device management

---

#### Cloud Infrastructure

**AWS / GCP / Azure**:
- Compute (EC2, ECS, EKS)
- Storage (S3, Cloud Storage)
- Networking (VPC, Load Balancers)
- Monitoring (CloudWatch, Stackdriver)

**CDN (CloudFlare / AWS CloudFront)**:
- Static asset delivery
- Image optimization
- DDoS protection
- SSL/TLS termination

## Communication Patterns

### 1. Synchronous Communication (REST)

**When to Use**:
- Real-time responses required
- Simple request-response operations
- Client-initiated actions

**Examples**:
- User login → User Service
- Search query → Search Service
- Get booking details → Booking Service

**Protocol**: HTTP/HTTPS with REST APIs

---

### 2. Asynchronous Communication (Events)

**When to Use**:
- Non-blocking operations
- Event-driven workflows
- Multiple consumers for same event

**Examples**:
- Booking created → Notify user + Update analytics
- Payment completed → Confirm booking + Send receipt
- Inventory updated → Update search index

**Protocol**: Message Queue (RabbitMQ/Kafka)

---

### 3. Service-to-Service Communication

**Patterns**:

**Direct REST Calls**:
```
Booking Service → Inventory Service (check availability)
Booking Service → Payment Service (process payment)
Booking Service → Pricing Service (calculate price)
```

**Event-Based**:
```
Booking Service publishes → booking.created event
Notification Service subscribes → sends confirmation
Analytics Service subscribes → records metric
```

**API Gateway Routing**:
```
Client → API Gateway → Service Discovery → Target Service
```

---

### 4. Data Synchronization

**Search Index Sync**:
```
Resource Service creates resource
  → Publishes resource.created event
  → Search Service consumes event
  → Updates Elasticsearch index
```

**Cache Invalidation**:
```
Resource Service updates price
  → Publishes resource.updated event
  → Pricing Service invalidates cache
  → Search Service updates index
```

## Data Storage Strategy

### Database Selection by Use Case

| Use Case | Technology | Reason |
|----------|-----------|---------|
| User accounts | PostgreSQL | ACID compliance, relational data |
| Bookings | PostgreSQL | Transactions, consistency critical |
| Inventory | PostgreSQL + Redis | Consistency + real-time performance |
| Search index | Elasticsearch | Full-text search, faceting |
| Sessions | Redis | Fast access, TTL support |
| Notifications | MongoDB | Document-oriented, flexible schema |
| Analytics events | MongoDB | High write throughput, flexible |
| Media files | S3 | Scalable object storage |
| Cache | Redis | In-memory, fast access |

### Data Consistency Models

**Strong Consistency**:
- Bookings (prevent double booking)
- Payments (exact balance)
- Inventory (accurate availability)
- **Implementation**: PostgreSQL transactions, distributed locks

**Eventual Consistency**:
- Search index updates
- Analytics data
- Notification delivery
- Cache synchronization
- **Implementation**: Event-driven updates, background jobs

### Backup & Recovery

**PostgreSQL**:
- Daily full backups
- Point-in-time recovery
- Cross-region replication

**Redis**:
- RDB snapshots every 15 minutes
- AOF for durability
- Master-slave replication

**Elasticsearch**:
- Snapshot to S3 daily
- Reindex capability

**MongoDB**:
- Replica set with 3 nodes
- Daily backups to S3

---

## Complete Flight Booking Flow

### End-to-End User Journey

```mermaid
sequenceDiagram
    actor User
    participant WebApp as Web/Mobile App
    participant API as API Gateway
    participant SearchSvc as Search Service
    participant BookingSvc as Booking Service
    participant PaymentSvc as Payment Service
    participant GDS as Amadeus GDS
    participant NotifSvc as Notification Service
    participant Cache as Redis Cache
    
    Note over User,Cache: Phase 1: Search
    User->>WebApp: Enter trip details
    WebApp->>API: POST /search/flights
    API->>SearchSvc: Forward request
    
    SearchSvc->>Cache: Check cache
    alt Cache miss
        SearchSvc->>GDS: Flight Offers Search API
        GDS-->>SearchSvc: 100+ flight options
        SearchSvc->>Cache: Store (5 min TTL)
    end
    
    SearchSvc-->>WebApp: Display results
    
    Note over User,Cache: Phase 2: Selection & Price Verification
    User->>WebApp: Select flight
    WebApp->>API: POST /bookings/verify-price
    API->>BookingSvc: Forward request
    BookingSvc->>GDS: Flight Price Verification API
    GDS-->>BookingSvc: Current price & availability
    
    alt Price changed
        BookingSvc-->>WebApp: Show price update
        User->>WebApp: Accept or cancel
    end
    
    Note over User,Cache: Phase 3: Passenger Details
    User->>WebApp: Enter passenger info
    WebApp->>API: POST /bookings/create
    API->>BookingSvc: Create booking
    
    Note over BookingSvc,GDS: Step 1: Create PNR
    BookingSvc->>GDS: Create Flight Order (unpaid)
    GDS-->>BookingSvc: PNR: ABC123
    BookingSvc->>BookingSvc: Save booking (PENDING)
    
    Note over User,PaymentSvc: Phase 4: Payment
    WebApp->>PaymentSvc: Process payment
    PaymentSvc->>PaymentSvc: Charge card
    PaymentSvc-->>BookingSvc: Payment successful
    
    Note over BookingSvc,GDS: Step 2: Issue Ticket
    BookingSvc->>GDS: Ticket Creation API
    GDS-->>BookingSvc: E-ticket: 0012345678901
    BookingSvc->>BookingSvc: Update status: CONFIRMED
    
    Note over BookingSvc,NotifSvc: Phase 5: Confirmation
    BookingSvc->>NotifSvc: Booking confirmed event
    NotifSvc->>NotifSvc: Generate e-ticket PDF
    NotifSvc-->>User: Email with e-ticket
    NotifSvc-->>User: SMS confirmation
    
    BookingSvc-->>WebApp: Booking complete
    WebApp-->>User: Show confirmation page
    
    Note over User: User can now:<br/>- Manage booking<br/>- Check-in online<br/>- Add ancillaries
```

### Detailed Step Breakdown

#### Step 1: Flight Search (5-10 seconds)

**User Actions**:
- Enter: Origin, Destination, Dates, Passengers, Class
- Click "Search"

**System Actions**:
1. Check Redis cache for existing results
2. If cache miss, query GDS (Amadeus) in parallel
3. Receive 100+ flight combinations
4. Merge, deduplicate, sort results
5. Cache for 5 minutes
6. Return to user

**Performance Targets**:
- Cache hit: < 200ms
- GDS query: 2-5 seconds
- Total: < 5 seconds

---

#### Step 2: Flight Selection & Price Verification (2-3 seconds)

**User Actions**:
- Browse results, apply filters
- Select preferred flight
- Click "Book"

**System Actions**:
1. Retrieve selected offer from cache
2. Call GDS price verification API
3. Confirm price hasn't changed
4. Confirm seats still available
5. Return pricing confirmation

**Why Price Verification?**
- Flight prices change every few minutes
- High demand routes update in real-time
- Prevent booking at stale prices

---

#### Step 3: Enter Passenger Details (1-2 minutes)

**User Actions**:
- Fill passenger information form:
  - Full name (as per passport)
  - Date of birth
  - Gender
  - Nationality
  - Passport details (for international)
  - Contact details
  - Frequent flyer number (optional)

**Validation**:
- Name format matches passport standards
- Date of birth (age restrictions)
- Passport validity (6 months minimum)
- Email and phone format

---

#### Step 4: Create PNR & Payment (10-30 seconds)

**System Actions**:

**4.1 Create PNR in GDS**:
```
Input:
- Flight details (offer ID)
- Passenger details (all travelers)
- Contact information

GDS Action:
- Reserve seats on the flight
- Generate PNR record locator (ABC123)
- Set time limit (24-48 hours)

Output:
- PNR code
- Booking reference
- Time limit
```

**4.2 Process Payment**:
```
Input:
- Total amount
- Payment method
- Cardholder details

Payment Gateway:
- 3D Secure authentication
- Fraud check
- Charge card

Output:
- Transaction ID
- Payment status
```

**4.3 Compensating Transaction**:
```
If payment fails:
  → Cancel PNR in GDS
  → Release seats
  → Notify user
  → Save failed attempt for analytics
```

---

#### Step 5: Ticket Issuance (5-10 seconds)

**System Actions**:
1. Call GDS ticket issuance API
2. GDS generates 13-digit e-ticket number
3. E-ticket is electronically stored in airline system
4. Update booking status to CONFIRMED
5. Generate booking confirmation PDF

**E-Ticket Contains**:
- Ticket number: 001-2345678901-3
- Passenger name
- Flight details
- Fare basis
- Baggage allowance
- Booking reference (PNR)

---

#### Step 6: Confirmation & Notifications (instant)

**Notifications Sent**:

**Email**:
- Subject: "Booking Confirmed - ABC123"
- E-ticket PDF attachment
- Flight details
- Check-in link
- Booking management link

**SMS**:
- "Your flight is confirmed! PNR: ABC123. Check-in opens 24hrs before departure."

**Push Notification** (if app):
- "Booking confirmed! View your e-ticket."

**In-App**:
- Booking appears in "My Trips"
- Calendar reminders set

---

### Post-Booking Operations

#### 1. Booking Management

**Available Actions**:
```
                         ┌──────────────────┐
                         │ Active Booking   │
                         │  (PNR: ABC123)   │
                         └────────┬─────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
          ▼                       ▼                       ▼
   ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
   │  Check-in   │        │   Modify    │        │   Upgrade   │
   │  (24hrs     │        │   Booking   │        │ Seat/Class  │
   │  before)    │        │             │        │             │
   └──────┬──────┘        └──────┬──────┘        └─────────────┘
          │                      │
          ▼                      ▼
   ┌─────────────┐        ┌─────────────┐
   │  Download   │        │ Pay change  │
   │  Boarding   │        │    fee      │
   │    Pass     │        │             │
   └─────────────┘        └─────────────┘
          
          ▼                       ▼                       ▼
   ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
   │     Add     │        │   Select    │        │   Cancel    │
   │ Ancillaries │        │    Seats    │        │   Booking   │
   │ (bags/meals)│        │             │        │             │
   └─────────────┘        └─────────────┘        └──────┬──────┘
                                                         │
                                                         ▼
                                                  ┌─────────────┐
                                                  │   Process   │
                                                  │   Refund    │
                                                  └─────────────┘
```

**APIs Required**:
- `POST /bookings/{id}/checkin` - Online check-in
- `POST /bookings/{id}/modify` - Change booking
- `POST /bookings/{id}/cancel` - Cancel booking
- `POST /bookings/{id}/seats` - Select seats
- `POST /bookings/{id}/baggage` - Add baggage
- `GET /bookings/{id}/retrieve` - Retrieve by PNR

#### 2. Schedule Change Handling

**When Airlines Change Schedules**:
```
1. GDS sends schedule change notification
2. Booking Service receives webhook
3. Update booking in database
4. Send notification to customer
5. Offer rebooking options
```

**Types of Changes**:
- Flight time change (< 2 hours) → Notify only
- Flight time change (> 2 hours) → Offer free rebooking
- Flight cancellation → Offer alternative flights
- Aircraft change → Update seat assignments

#### 3. Cancellation & Refunds

**Cancellation Flow**:
```mermaid
sequenceDiagram
    participant User
    participant BookingSvc as Booking Service
    participant GDS as Amadeus GDS
    participant PaymentSvc as Payment Service
    
    User->>BookingSvc: Request cancellation
    BookingSvc->>BookingSvc: Check fare rules
    
    alt Refundable ticket
        BookingSvc->>GDS: Void/Refund ticket
        GDS-->>BookingSvc: Ticket voided
        BookingSvc->>PaymentSvc: Process refund
        PaymentSvc-->>User: Refund amount - fees
    else Non-refundable
        BookingSvc-->>User: No refund available
        Note over User: May get partial airline credit
    end
```

**Refund Rules**:
- **Within 24 hours**: Full refund (US DOT rule)
- **Refundable ticket**: Refund minus cancellation fee
- **Non-refundable**: No refund, possible airline credit
- **Flexible fare**: Free changes, refund with fee

---

### Real-World Example: Booking Flow Timing

**Expedia/Booking.com Typical Flow**:

| Step | Duration | Notes |
|------|----------|-------|
| Search flights | 3-5s | GDS query time |
| Filter results | < 1s | Client-side |
| Select flight | < 1s | Cache retrieval |
| Price verification | 2s | Real-time GDS call |
| Enter details | 60-120s | User input |
| Create PNR | 3-5s | GDS API |
| Process payment | 5-10s | Payment gateway |
| Issue ticket | 5-8s | GDS ticketing |
| Send confirmation | < 1s | Async job |
| **Total** | **~90-150s** | **User perspective** |

**Optimization Opportunities**:
- Cache popular routes more aggressively
- Pre-fetch adjacent dates for calendar view
- Parallel GDS queries
- Async ticket issuance (issue after confirmation)
- Progressive loading of search results

---

## Summary

This architecture provides:

### ✅ **Scalability**: Horizontal Scaling of Independent Services

**What it means**:
- Each service can scale independently based on its specific load
- Add more instances of a service without affecting others
- No single bottleneck across the entire system

**How it works in flight booking**:

```
User Service (Low Traffic)          Search Service (High Traffic)
┌────────────┐                     ┌────────────┐  ┌────────────┐
│  Instance  │                     │  Instance  │  │  Instance  │
│     #1     │                     │     #1     │  │     #2     │
└────────────┘                     └────────────┘  └────────────┘
                                   ┌────────────┐  ┌────────────┐
   (1 instance)                    │  Instance  │  │  Instance  │
                                   │     #3     │  │     #4     │
                                   └────────────┘  └────────────┘
                                   
                                   (4 instances for high search volume)

Booking Service (Medium Traffic)
┌────────────┐  ┌────────────┐
│  Instance  │  │  Instance  │
│     #1     │  │     #2     │
└────────────┘  └────────────┘

   (2 instances)
```

**Real-world example**:
- **Peak season** (December holidays): Search Service receives 10,000 requests/second
  - Scale Search Service from 4 → 20 instances
  - Keep User Service at 2 instances (login traffic is normal)
  - Scale Booking Service from 2 → 8 instances (more bookings)
  
- **Off-season** (February): Traffic drops 70%
  - Scale down Search Service from 20 → 6 instances
  - Save infrastructure costs automatically

**Technologies used**:
- **Load Balancer**: Distribute traffic across instances (AWS ALB, Nginx)
- **Auto-scaling**: Automatically add/remove instances based on CPU/memory (Kubernetes HPA)
- **Service Discovery**: Services find each other dynamically (Consul, Eureka)

**Benefits**:
- Handle traffic spikes without over-provisioning all services
- Cost-efficient (pay only for what you need)
- Better resource utilization

---

### ✅ **Reliability**: Redundancy and Fault Tolerance

**What it means**:
- System continues working even when components fail
- No single point of failure (SPOF)
- Graceful degradation when issues occur

**How it works in flight booking**:

**1. Service-Level Redundancy**:
```
Client Request
     │
     ▼
┌─────────────────┐
│  Load Balancer  │
└────────┬────────┘
         │
    ┌────┴────┬────────┬────────┐
    ▼         ▼        ▼        ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│Search  │ │Search  │ │Search  │ │Search  │
│Svc #1  │ │Svc #2  │ │Svc #3  │ │Svc #4  │
└────────┘ └────────┘ └────────┘ └────────┘
   ✅         ❌         ✅         ✅
  (OK)    (Crashed)    (OK)      (OK)

If one instance crashes, load balancer routes to healthy instances
```

**2. Database Redundancy**:
```
PostgreSQL Setup:

┌──────────────┐     Replication     ┌──────────────┐
│   Primary    │ ─────────────────> │   Replica 1  │
│   (Master)   │                     │   (Standby)  │
└──────────────┘                     └──────────────┘
      │                                     │
      │         Replication                 │
      └────────────────────────────────────┐│
                                           ▼▼
                                    ┌──────────────┐
                                    │   Replica 2  │
                                    │   (Standby)  │
                                    └──────────────┘

If Primary fails → Automatic failover to Replica 1
```

**3. GDS Provider Redundancy**:
```
Search Request
     │
     ├────────────┬────────────┬────────────┐
     ▼            ▼            ▼            ▼
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│Amadeus  │  │ Sabre   │  │Travelport│ │   NDC   │
│   GDS   │  │  GDS    │  │   GDS    │  │ Direct  │
└─────────┘  └─────────┘  └─────────┘  └─────────┘
    ✅           ❌            ✅           ✅
   (OK)     (Timeout)       (OK)         (OK)

If Amadeus fails, still get results from Sabre + Travelport + NDC
```

**4. Circuit Breaker Pattern**:
```javascript
// Prevent cascading failures
class GDSService {
  async searchFlights(params) {
    if (circuitBreaker.isOpen('amadeus')) {
      // Skip Amadeus, it's down
      console.log('Amadeus circuit OPEN, skipping');
      return fallbackToSabre(params);
    }
    
    try {
      const result = await amadeus.search(params);
      circuitBreaker.recordSuccess('amadeus');
      return result;
    } catch (error) {
      circuitBreaker.recordFailure('amadeus');
      
      // After 5 failures, open circuit for 60 seconds
      if (circuitBreaker.shouldOpen('amadeus')) {
        circuitBreaker.open('amadeus', 60);
      }
      
      // Fallback to alternative GDS
      return fallbackToSabre(params);
    }
  }
}
```

**5. Retry with Exponential Backoff**:
```javascript
async function callGDSWithRetry(request, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await gds.call(request);
    } catch (error) {
      if (attempt === maxRetries) {
        throw error; // Give up after 3 tries
      }
      
      // Wait before retry: 1s, 2s, 4s
      const delay = Math.pow(2, attempt) * 1000;
      console.log(`Retry ${attempt} after ${delay}ms`);
      await sleep(delay);
    }
  }
}
```

**Real-world failure scenarios**:

| Failure | Impact Without Redundancy | Impact With Redundancy |
|---------|--------------------------|----------------------|
| Search Service instance crashes | All searches fail | Traffic routed to healthy instances (0 downtime) |
| PostgreSQL primary fails | All bookings fail | Automatic failover to replica (< 30s downtime) |
| Amadeus GDS timeout | No search results | Results from Sabre + Travelport (slight delay) |
| Payment gateway (Stripe) down | Can't process payments | Fallback to PayPal (user sees option) |
| Redis cache fails | Slow performance | Direct GDS calls (slower but functional) |

**Benefits**:
- **High availability**: 99.9% uptime (< 9 hours downtime/year)
- **Business continuity**: Never lose revenue due to single component failure
- **Customer trust**: Reliable booking experience

---

### ✅ **Performance**: Caching, Async Processing, Optimized Queries

**What it means**:
- Fast response times even under high load
- Efficient use of resources
- Optimized for user experience

**How it works in flight booking**:

#### 1. **Multi-Layer Caching Strategy**

```
┌─────────────────────────────────────────────────────────┐
│                    CACHING LAYERS                        │
└─────────────────────────────────────────────────────────┘

Layer 1: CDN Cache (Cloudflare)
├── Static assets (images, CSS, JS)
├── TTL: 24 hours
└── Response time: 10-50ms

Layer 2: Redis Cache (Application Level)
├── Search results
│   └── TTL: 5 minutes (prices change fast)
├── Popular routes
│   └── TTL: 1 hour
├── Airport data
│   └── TTL: 24 hours
├── User sessions
│   └── TTL: 24 hours
└── Response time: 1-5ms

Layer 3: Database Query Cache
├── PostgreSQL query results
├── TTL: Varies by query
└── Response time: 10-50ms

Layer 4: GDS/Airline APIs (No cache, always fresh)
└── Response time: 2000-5000ms (2-5 seconds)
```

**Cache hit vs Cache miss example**:

```
Search: "New York to Los Angeles, Dec 15"

┌────────────────────────────────────────────────────────┐
│ CACHE HIT (result already cached)                      │
└────────────────────────────────────────────────────────┘

User Request → API Gateway → Search Service → Redis
                                                  │
                    Found! ←─────────────────────┘
                      │
                    150ms total response time ✅
                    
┌────────────────────────────────────────────────────────┐
│ CACHE MISS (result not cached)                         │
└────────────────────────────────────────────────────────┘

User Request → API Gateway → Search Service → Redis (miss)
                                                  │
                                        Not found ┘
                                                  │
                   ┌──────────────────────────────┘
                   │
                   ├──→ Query Amadeus GDS (3.2s)
                   ├──→ Query Sabre GDS (2.8s)
                   └──→ Query NDC APIs (1.5s)
                   │
                   ├─→ Merge results
                   ├─→ Deduplicate
                   ├─→ Sort by price
                   └─→ Store in Redis (for next request)
                   │
                 4.5s total response time ⚠️
```

**Cache key design**:
```javascript
// Smart cache key includes all relevant parameters
const cacheKey = `flight:search:${origin}:${dest}:${date}:${passengers}:${class}`;

// Example: "flight:search:JFK:LAX:2025-12-15:2:economy"

// Retrieve from cache
const cachedResults = await redis.get(cacheKey);

if (cachedResults && !isExpired(cachedResults)) {
  return JSON.parse(cachedResults); // FAST! 150ms
}

// Cache miss, query GDS
const results = await queryAllGDS(params);

// Store for next user (5 min TTL)
await redis.setex(cacheKey, 300, JSON.stringify(results));
```

#### 2. **Asynchronous Processing**

**Blocking vs Non-blocking operations**:

```javascript
// ❌ BAD: Synchronous/Blocking (slow!)
async function createBooking(request) {
  const pnr = await createPNR(request);           // Wait 3s
  const payment = await processPayment(request);  // Wait 5s
  const ticket = await issueTicket(pnr);          // Wait 4s
  await sendEmail(ticket);                        // Wait 2s
  await sendSMS(ticket);                          // Wait 1s
  await logAnalytics(ticket);                     // Wait 0.5s
  
  return { success: true }; // Total: 15.5 seconds! ⚠️
}

// ✅ GOOD: Asynchronous/Non-blocking (fast!)
async function createBooking(request) {
  const pnr = await createPNR(request);           // Wait 3s
  const payment = await processPayment(request);  // Wait 5s
  const ticket = await issueTicket(pnr);          // Wait 4s
  
  // Fire-and-forget (async jobs)
  eventBus.publish('booking.confirmed', { ticket });
  
  // These happen in background workers:
  // - NotificationService sends email (2s in background)
  // - NotificationService sends SMS (1s in background)
  // - AnalyticsService logs event (0.5s in background)
  
  return { success: true }; // Total: 12 seconds! ✅
}
```

**Message Queue for async jobs**:
```
┌──────────────────────────────────────────────────────┐
│              Booking Service                          │
│                                                       │
│  1. Create PNR      ✅ (3s - synchronous, critical)  │
│  2. Process Payment ✅ (5s - synchronous, critical)  │
│  3. Issue Ticket    ✅ (4s - synchronous, critical)  │
│                                                       │
│  4. Publish event to queue                           │
│     └─→ "booking.confirmed"                          │
└──────────────┬───────────────────────────────────────┘
               │
               ▼
        ┌─────────────┐
        │  RabbitMQ   │
        │   Queue     │
        └──────┬──────┘
               │
       ┌───────┴───────┬────────────┬──────────────┐
       ▼               ▼            ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│Notification │ │Notification │ │ Analytics   │ │   Review    │
│Service      │ │Service      │ │  Service    │ │   Service   │
│(Email)      │ │(SMS)        │ │             │ │             │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
  2s async       1s async        0.5s async      (triggers later)

User gets response in 12s instead of 15.5s!
```

#### 3. **Database Query Optimization**

**Indexes on frequently queried columns**:
```sql
-- Bookings table (millions of rows)
CREATE TABLE bookings (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  pnr VARCHAR(6) NOT NULL,
  status VARCHAR(20) NOT NULL,
  departure_date DATE NOT NULL,
  created_at TIMESTAMP NOT NULL,
  -- ... other columns
);

-- ✅ Add indexes for fast lookups
CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_pnr ON bookings(pnr);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_departure_date ON bookings(departure_date);
CREATE INDEX idx_bookings_created_at ON bookings(created_at);

-- Query: Get user's upcoming bookings
-- Without index: 5000ms (full table scan)
-- With index: 15ms ✅
SELECT * FROM bookings 
WHERE user_id = '123' 
  AND status = 'CONFIRMED'
  AND departure_date > CURRENT_DATE
ORDER BY departure_date ASC;
```

**Connection Pooling**:
```javascript
// ❌ BAD: New connection per request (slow!)
async function getBooking(id) {
  const client = await postgres.connect(); // 100ms to connect!
  const result = await client.query('SELECT * FROM bookings WHERE id = $1', [id]);
  await client.end();
  return result.rows[0];
  // Total: 100ms + 10ms query = 110ms
}

// ✅ GOOD: Connection pool (fast!)
const pool = new Pool({ max: 20 }); // 20 pre-established connections

async function getBooking(id) {
  const client = await pool.connect(); // < 1ms (reuse existing)
  const result = await client.query('SELECT * FROM bookings WHERE id = $1', [id]);
  client.release(); // Return to pool
  return result.rows[0];
  // Total: 1ms + 10ms query = 11ms ✅
}
```

**Partitioning large tables**:
```sql
-- Partition bookings table by month (for faster queries)
CREATE TABLE bookings (
  id UUID,
  created_at TIMESTAMP,
  -- ... columns
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE bookings_2025_11 PARTITION OF bookings
  FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

CREATE TABLE bookings_2025_12 PARTITION OF bookings
  FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

-- Query only scans relevant partition (10x faster!)
SELECT * FROM bookings 
WHERE created_at >= '2025-11-01' 
  AND created_at < '2025-12-01';
```

#### 4. **Performance Metrics**

**Real-world performance targets**:

| Operation | Target | Actual (Optimized) | Without Optimization |
|-----------|--------|-------------------|---------------------|
| Search flights (cache hit) | < 300ms | 150ms ✅ | N/A |
| Search flights (cache miss) | < 5s | 4.2s ✅ | 8s (sequential GDS calls) |
| Price verification | < 3s | 2.1s ✅ | 2.1s (external API) |
| Create booking | < 15s | 12s ✅ | 15.5s (without async) |
| Get booking details | < 100ms | 45ms ✅ | 200ms (no index) |
| User login | < 500ms | 120ms ✅ | 300ms (no session cache) |

**Benefits**:
- **Better UX**: Users don't wait, higher conversion rate
- **Cost savings**: Fewer GDS API calls (each costs $0.50-2.00)
- **Higher throughput**: Handle more requests with same hardware

---

### ✅ **Maintainability**: Clear Service Boundaries and Responsibilities

**What it means**:
- Each service has a single, well-defined purpose
- Easy to understand, modify, and debug
- New developers can onboard quickly
- Changes in one service don't break others

**How it works in flight booking**:

#### 1. **Single Responsibility Principle**

Each service owns one domain:

```
┌─────────────────────────────────────────────────────────┐
│             SERVICE RESPONSIBILITIES                     │
└─────────────────────────────────────────────────────────┘

User Service
├── Authentication & Authorization ONLY
├── OWNS: users table, sessions
├── NEVER touches: bookings, payments, flights
└── Team: Identity Team (2 developers)

Search Service
├── Flight search & aggregation ONLY
├── OWNS: search cache, search history
├── NEVER touches: user data, bookings
└── Team: Search Team (3 developers)

Booking Service
├── PNR & booking management ONLY
├── OWNS: bookings table, PNR records
├── NEVER touches: user passwords, payment processing
└── Team: Booking Team (4 developers)

Payment Service
├── Payment processing ONLY
├── OWNS: transactions table, payment records
├── NEVER touches: flight data, user profiles
└── Team: Payments Team (2 developers)

Notification Service
├── Email/SMS delivery ONLY
├── OWNS: notification_logs table
├── NEVER touches: booking logic, payments
└── Team: Communications Team (2 developers)
```

**Example: Adding a new feature**

```
Feature Request: "Add loyalty points to bookings"

┌────────────────────────────────────────────────────────┐
│ CHANGES REQUIRED (Clear boundaries)                    │
└────────────────────────────────────────────────────────┘

1. User Service
   └── Add "loyalty_points" field to users table
   └── Add endpoint: GET /users/{id}/points

2. Booking Service
   └── Call User Service to deduct points
   └── Add "points_used" field to bookings table

3. Payment Service
   └── Calculate discount from points
   └── No database changes needed

4. Notification Service
   └── Update email template (show points used)
   └── No code changes needed

Other services: ZERO changes needed! ✅
```

**Anti-pattern (without clear boundaries)**:
```javascript
// ❌ BAD: God service that does everything
class BookingService {
  async createBooking(request) {
    // User management (should be User Service)
    const user = await db.users.findOne(request.userId);
    if (user.password !== hashPassword(request.password)) {
      throw new Error('Invalid password');
    }
    
    // Search logic (should be Search Service)
    const flights = await amadeus.search(request.flights);
    const cheapest = flights.sort((a, b) => a.price - b.price)[0];
    
    // Payment processing (should be Payment Service)
    const charge = await stripe.charge({
      amount: cheapest.price,
      source: request.card
    });
    
    // Notification (should be Notification Service)
    await sendEmail(user.email, 'Booking confirmed');
    
    // Booking creation (this is correct!)
    return await db.bookings.create({ ... });
  }
}

// Problem: One team owns everything, can't scale development
```

#### 2. **Well-Defined APIs (Contracts)**

Each service exposes clear API contracts:

```yaml
# Booking Service API Contract (OpenAPI/Swagger)

POST /bookings/create:
  summary: Create a new flight booking
  request:
    body:
      type: object
      required: [offerId, passengers, paymentToken]
      properties:
        offerId:
          type: string
          description: Flight offer ID from Search Service
        passengers:
          type: array
          items:
            type: object
            required: [firstName, lastName, dateOfBirth]
  response:
    200:
      body:
        type: object
        properties:
          bookingId: string
          pnr: string
          status: string (CONFIRMED | FAILED)
    400:
      description: Invalid request
    500:
      description: Server error

GET /bookings/{id}:
  summary: Get booking details
  parameters:
    - id: string (UUID)
  response:
    200:
      body:
        type: object
        properties:
          bookingId: string
          pnr: string
          flights: object
          passengers: array
    404:
      description: Booking not found
```

**Benefits**:
- **Clear expectations**: Developers know exactly what to send/receive
- **Versioning**: Can evolve API without breaking clients (v1, v2)
- **Documentation**: Auto-generated docs from contract
- **Testing**: Can mock APIs for unit tests

#### 3. **Database Per Service**

Each service owns its database:

```
User Service        Search Service      Booking Service
     │                   │                    │
     ▼                   ▼                    ▼
┌─────────────┐    ┌─────────────┐     ┌─────────────┐
│PostgreSQL   │    │   Redis     │     │PostgreSQL   │
│             │    │   Cache     │     │             │
│• users      │    │• searches   │     │• bookings   │
│• sessions   │    │• results    │     │• pnr_data   │
└─────────────┘    └─────────────┘     └─────────────┘

❌ NEVER query another service's database directly!
✅ ALWAYS use the service's API
```

**Why separate databases?**
```javascript
// ❌ BAD: Booking Service directly accessing User DB
async function createBooking(userId, flightData) {
  // This creates tight coupling!
  const user = await userDatabase.query(
    'SELECT * FROM users WHERE id = $1', 
    [userId]
  );
  
  // Problem: If User Service changes schema, Booking Service breaks!
}

// ✅ GOOD: Booking Service calls User Service API
async function createBooking(userId, flightData) {
  // Loose coupling via API
  const user = await userServiceClient.get(`/users/${userId}`);
  
  // User Service can change internals freely, API stays stable
}
```

#### 4. **Code Organization**

```
booking-service/
├── src/
│   ├── controllers/       # API endpoints
│   │   ├── booking.controller.ts
│   │   └── health.controller.ts
│   ├── services/          # Business logic
│   │   ├── booking.service.ts
│   │   ├── gds.service.ts
│   │   └── saga.orchestrator.ts
│   ├── repositories/      # Database access
│   │   └── booking.repository.ts
│   ├── models/            # Data models
│   │   ├── booking.model.ts
│   │   └── pnr.model.ts
│   ├── clients/           # External API clients
│   │   ├── payment-service.client.ts
│   │   ├── user-service.client.ts
│   │   └── amadeus.client.ts
│   ├── events/            # Event handlers
│   │   ├── payment-completed.handler.ts
│   │   └── booking-created.publisher.ts
│   └── utils/             # Shared utilities
│       ├── logger.ts
│       └── errors.ts
├── tests/
│   ├── unit/
│   └── integration/
├── docs/
│   ├── API.md
│   └── ARCHITECTURE.md
├── package.json
└── README.md
```

**Benefits**:
- **Easy onboarding**: New developers know where to find things
- **Consistent structure**: All services follow same pattern
- **Testing**: Clear separation makes unit testing easier

#### 5. **Logging & Debugging**

Structured logging with correlation IDs:

```javascript
// Every request gets a unique correlation ID
app.use((req, res, next) => {
  req.correlationId = generateUUID();
  next();
});

// All logs include correlation ID
logger.info({
  correlationId: req.correlationId,
  service: 'booking-service',
  action: 'create_booking',
  userId: req.user.id,
  pnr: 'ABC123'
});

// Payment Service logs
logger.info({
  correlationId: req.correlationId, // SAME ID!
  service: 'payment-service',
  action: 'process_payment',
  amount: 456.80
});

// Easy to trace entire request across services:
// grep "correlation-id-xyz" logs/*.log
```

**Benefits**:
- **Faster debugging**: Trace request across all services
- **Root cause analysis**: See exactly where failure occurred
- **Performance profiling**: Measure time spent in each service

---

### ✅ **Security**: Defense in Depth, Encryption, Compliance

**What it means**:
- Multiple layers of security (not just one)
- Protect sensitive data (PII, payment info)
- Meet compliance standards (PCI DSS, GDPR, PSD2)

**How it works in flight booking**:

#### 1. **Defense in Depth (Multiple Security Layers)**

```
┌─────────────────────────────────────────────────────────┐
│               SECURITY LAYERS                            │
└─────────────────────────────────────────────────────────┘

Layer 1: Network Security
├── DDoS Protection (Cloudflare)
├── Web Application Firewall (WAF)
├── Rate Limiting (1000 req/min per IP)
└── Geographic Blocking (block suspicious countries)

Layer 2: API Gateway Security
├── TLS/SSL Encryption (HTTPS only)
├── API Key Authentication
├── JWT Token Validation
└── Request Size Limits (prevent payload attacks)

Layer 3: Service-Level Security
├── Authentication (OAuth 2.0, JWT)
├── Authorization (RBAC - Role-Based Access Control)
├── Input Validation (prevent SQL injection, XSS)
└── Output Sanitization

Layer 4: Database Security
├── Encrypted at Rest (AES-256)
├── Encrypted in Transit (TLS)
├── Principle of Least Privilege (minimal permissions)
└── Query Parameterization (prevent SQL injection)

Layer 5: Application Security
├── Secrets Management (AWS Secrets Manager, Vault)
├── Audit Logging (all sensitive operations logged)
├── Session Management (secure, HTTP-only cookies)
└── CSRF Protection

Layer 6: Compliance & Monitoring
├── PCI DSS Compliance (payment data)
├── GDPR Compliance (user data protection)
├── Security Scanning (SAST, DAST)
└── Intrusion Detection (abnormal behavior alerts)
```

**Real-world attack scenarios**:

| Attack Type | Layer That Blocks It | How |
|------------|---------------------|-----|
| DDoS (1M req/sec) | Layer 1: Cloudflare | Rate limiting, IP blocking |
| SQL Injection | Layer 3 & 4 | Input validation, parameterized queries |
| Stolen credit card | Layer 3 | PCI DSS tokenization (never store full card) |
| Brute force login | Layer 2 & 3 | Rate limiting (5 attempts), account lockout |
| XSS attack | Layer 3 | Output sanitization, Content Security Policy |
| Man-in-the-middle | Layer 2 | TLS encryption (HTTPS) |

#### 2. **Encryption Everywhere**

**Data in Transit** (moving between services):
```javascript
// ✅ All API calls use HTTPS/TLS
const response = await axios.post(
  'https://payment-service.internal/payments', // HTTPS!
  { amount: 456.80 },
  {
    headers: {
      'Authorization': `Bearer ${jwtToken}`,
      'X-API-Key': process.env.API_KEY
    }
  }
);

// ❌ HTTP is blocked by API gateway
// http://payment-service.internal/payments → 403 Forbidden
```

**Data at Rest** (stored in database):
```sql
-- Sensitive fields encrypted in database
CREATE TABLE bookings (
  id UUID PRIMARY KEY,
  pnr VARCHAR(6) NOT NULL,
  user_id UUID NOT NULL,
  
  -- PII encrypted with AES-256
  passenger_name VARCHAR(255) ENCRYPTED,
  passport_number VARCHAR(20) ENCRYPTED,
  email VARCHAR(255) ENCRYPTED,
  phone VARCHAR(20) ENCRYPTED,
  
  -- Payment info NEVER stored (use tokens)
  payment_token VARCHAR(50), -- Stripe token, not actual card
  
  created_at TIMESTAMP
);

-- Application-level encryption
const encryptedPassport = encrypt(passportNumber, process.env.ENCRYPTION_KEY);
await db.query(
  'INSERT INTO bookings (passport_number) VALUES ($1)',
  [encryptedPassport]
);

-- Decryption when reading
const row = await db.query('SELECT passport_number FROM bookings WHERE id = $1', [id]);
const passportNumber = decrypt(row.passport_number, process.env.ENCRYPTION_KEY);
```

**Payment Card Security (PCI DSS)**:
```javascript
// ❌ NEVER store raw credit card data!
const booking = {
  cardNumber: '4111111111111111',     // ❌ ILLEGAL!
  cvv: '123',                          // ❌ ILLEGAL!
  expiryDate: '12/25'                  // ❌ ILLEGAL!
};

// ✅ Use payment gateway tokenization
// 1. Client sends card to Stripe directly (never touches your server)
<form action="https://api.stripe.com/v1/tokens" method="POST">
  <input type="text" name="card[number]" />
  <input type="text" name="card[cvc]" />
  <input type="text" name="card[exp_month]" />
  <input type="text" name="card[exp_year]" />
</form>

// 2. Stripe returns token
{ token: "tok_1A2B3C4D5E6F" }

// 3. Your server uses token (never sees actual card)
const booking = {
  paymentToken: 'tok_1A2B3C4D5E6F',  // ✅ Safe!
  amount: 456.80
};

await stripe.charges.create({
  amount: 45680, // cents
  currency: 'usd',
  source: booking.paymentToken // Token, not card!
});
```

#### 3. **Authentication & Authorization**

**JWT Token-Based Auth**:
```javascript
// User logs in
POST /auth/login
{
  "email": "john@example.com",
  "password": "hashed_password"
}

// Response: JWT token
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600 // 1 hour
}

// JWT payload (decoded):
{
  "userId": "123",
  "email": "john@example.com",
  "role": "customer", // customer | admin | agent
  "iat": 1699200000,  // issued at
  "exp": 1699203600   // expires at
}

// All subsequent requests include token
GET /bookings/my-bookings
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Role-Based Access Control (RBAC)**:
```javascript
// Middleware to check permissions
function requireRole(allowedRoles) {
  return (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    const decoded = jwt.verify(token, SECRET_KEY);
    
    if (!allowedRoles.includes(decoded.role)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    
    req.user = decoded;
    next();
  };
}

// Apply to routes
app.get('/bookings/:id', 
  requireRole(['customer', 'admin']), 
  getBooking
); // Customers can view their own bookings

app.delete('/bookings/:id', 
  requireRole(['admin']), 
  cancelBooking
); // Only admins can cancel bookings

app.get('/admin/revenue', 
  requireRole(['admin']), 
  getRevenue
); // Only admins see revenue data
```

#### 4. **Compliance Standards**

**PCI DSS** (Payment Card Industry Data Security Standard):
```
Required for handling credit cards:

✅ Never store full card numbers
✅ Never store CVV/CVC
✅ Use tokenization (Stripe, PayPal)
✅ Encrypt cardholder data in transit
✅ Maintain secure network (firewall, VPN)
✅ Regular security audits
✅ Access control (least privilege)
✅ Monitor all access to card data
✅ Regular penetration testing
✅ Incident response plan

Penalty for non-compliance: $5,000-$100,000/month + liability
```

**GDPR** (General Data Protection Regulation):
```
Required for EU user data:

✅ User consent for data collection
✅ Right to access data (export user data)
✅ Right to deletion ("forget me")
✅ Data portability
✅ Breach notification (within 72 hours)
✅ Data minimization (collect only what's needed)
✅ Purpose limitation (use data only for stated purpose)

Implementation:
- "Export my data" endpoint
- "Delete my account" endpoint (anonymize bookings)
- Cookie consent banner
- Privacy policy

Penalty: €20 million or 4% of annual revenue (whichever is higher)
```

**Data Anonymization Example**:
```javascript
// User requests account deletion (GDPR "Right to be Forgotten")
async function deleteUserAccount(userId) {
  // Can't delete bookings (needed for accounting/legal)
  // Solution: Anonymize personal data
  
  await db.bookings.update(
    { user_id: userId },
    {
      passenger_name: 'DELETED USER',
      email: `deleted-${userId}@anonymized.com`,
      phone: '000-000-0000',
      passport_number: null,
      // Keep: PNR, flight details, amount (for records)
    }
  );
  
  await db.users.delete({ id: userId });
  
  logger.info({ 
    action: 'gdpr_deletion', 
    userId,
    timestamp: new Date()
  });
}
```

#### 5. **Security Monitoring & Alerts**

```javascript
// Detect suspicious activity
async function detectFraudulentBooking(booking) {
  const alerts = [];
  
  // 1. Multiple bookings from same IP (> 5/hour)
  const recentBookings = await db.bookings.count({
    ip_address: booking.ipAddress,
    created_at: { $gte: new Date(Date.now() - 3600000) }
  });
  
  if (recentBookings > 5) {
    alerts.push('HIGH_FREQUENCY_BOOKING');
  }
  
  // 2. Booking from high-risk country
  if (HIGH_RISK_COUNTRIES.includes(booking.country)) {
    alerts.push('HIGH_RISK_LOCATION');
  }
  
  // 3. Email mismatch (email domain != payment card country)
  if (booking.emailDomain !== booking.cardCountry) {
    alerts.push('EMAIL_CARD_MISMATCH');
  }
  
  // 4. Booking amount too high (> $10,000)
  if (booking.amount > 10000) {
    alerts.push('HIGH_VALUE_TRANSACTION');
  }
  
  if (alerts.length >= 2) {
    // Flag for manual review
    await db.bookings.update(booking.id, { 
      status: 'UNDER_REVIEW',
      fraud_score: alerts.length 
    });
    
    // Alert fraud team
    await notificationService.alertFraudTeam({
      bookingId: booking.id,
      alerts,
      severity: 'HIGH'
    });
  }
}
```

**Benefits**:
- **Customer trust**: Secure platform, no data breaches
- **Legal compliance**: Avoid fines and lawsuits
- **Business continuity**: Prevent fraud, chargebacks
- **Reputation**: Security incidents = lost customers

---

### ✅ **Flexibility**: Easy to Add/Modify Services

**What it means**:
- Can add new features without rewriting everything
- Swap out components (e.g., switch from Amadeus to Sabre)
- Adapt to changing business requirements
- Support multiple platforms (web, mobile, API partners)

**How it works in flight booking**:

#### 1. **Plugin Architecture (Add Services Easily)**

```
Current Architecture:
┌────────┬────────┬────────┬────────┬────────┐
│  User  │ Search │Booking │Payment │ Notif  │
└────────┴────────┴────────┴────────┴────────┘

Want to add hotel booking? Just add a new service!

New Architecture:
┌────────┬────────┬────────┬────────┬────────┬────────┐
│  User  │ Search │Booking │Payment │ Notif  │ Hotel  │ ← New!
└────────┴────────┴────────┴────────┴────────┴────────┘

Hotel Service:
- Uses SAME Payment Service ✅
- Uses SAME Notification Service ✅
- Uses SAME User Service ✅
- No changes to existing services! ✅
```

**Example: Adding Car Rental Service**:
```javascript
// 1. Create new service (no changes to existing services!)
class CarRentalService {
  async searchCars(params) {
    // Integrate with car rental APIs (Hertz, Avis, etc.)
  }
  
  async createBooking(params) {
    // Create car rental booking
    
    // Reuse existing services!
    const payment = await paymentService.charge(params.amount);
    await notificationService.sendConfirmation(params.email);
    await analyticsService.trackEvent('car_rental_booked');
  }
}

// 2. Register in API Gateway
apiGateway.registerService({
  name: 'car-rental-service',
  routes: [
    { path: '/cars/search', method: 'POST' },
    { path: '/cars/book', method: 'POST' }
  ]
});

// 3. Publish events
eventBus.subscribe('car_rental.booked', (event) => {
  // Other services can listen if needed
});

// That's it! No changes to User, Payment, or Notification services!
```

#### 2. **Adapter Pattern (Swap Providers Easily)**

**Swap GDS providers without changing business logic**:

```javascript
// Define interface
interface GDSProvider {
  searchFlights(params): Promise<FlightResults>;
  createPNR(params): Promise<PNR>;
  issueTicket(pnr): Promise<Ticket>;
}

// Amadeus implementation
class AmadeusAdapter implements GDSProvider {
  async searchFlights(params) {
    // Amadeus-specific API call
    const response = await amadeus.shopping.flightOffersSearch.get(params);
    return this.normalizeResponse(response); // Convert to standard format
  }
  
  async createPNR(params) {
    // Amadeus-specific PNR creation
  }
}

// Sabre implementation
class SabreAdapter implements GDSProvider {
  async searchFlights(params) {
    // Sabre-specific API call
    const response = await sabre.bargainFinderMax(params);
    return this.normalizeResponse(response); // Convert to standard format
  }
  
  async createPNR(params) {
    // Sabre-specific PNR creation
  }
}

// Business logic doesn't care which GDS!
class SearchService {
  constructor(private gdsProvider: GDSProvider) {}
  
  async search(params) {
    // Works with ANY GDS implementation!
    return await this.gdsProvider.searchFlights(params);
  }
}

// Configuration (easy to switch!)
const gdsProvider = process.env.PRIMARY_GDS === 'sabre' 
  ? new SabreAdapter()
  : new AmadeusAdapter(); // Default to Amadeus

const searchService = new SearchService(gdsProvider);
```

**Swap payment providers**:
```javascript
// Same pattern for payment gateways
interface PaymentGateway {
  charge(amount, token): Promise<Payment>;
  refund(paymentId): Promise<Refund>;
}

class StripeAdapter implements PaymentGateway { /* ... */ }
class PayPalAdapter implements PaymentGateway { /* ... */ }
class BraintreeAdapter implements PaymentGateway { /* ... */ }

// Easy to switch in config
const paymentGateway = config.paymentProvider === 'paypal'
  ? new PayPalAdapter()
  : new StripeAdapter();
```

#### 3. **API Versioning (Evolve Without Breaking)**

```javascript
// v1 API (legacy, still supported)
app.post('/v1/bookings/create', (req, res) => {
  // Old format
  const booking = {
    flightId: req.body.flightId,
    userId: req.body.userId
  };
  
  // ... old logic
});

// v2 API (new, enhanced)
app.post('/v2/bookings/create', (req, res) => {
  // New format (more details)
  const booking = {
    offerId: req.body.offerId,  // Changed from flightId
    passengers: req.body.passengers, // New field
    ancillaries: req.body.ancillaries, // New field
    userId: req.body.userId
  };
  
  // ... new logic with PNR, ancillaries, etc.
});

// Both versions work simultaneously!
// Old mobile apps use v1
// New mobile apps use v2
// Migrate gradually over 6 months, then deprecate v1
```

#### 4. **Feature Flags (Toggle Features On/Off)**

```javascript
// Enable/disable features without deploying code
const featureFlags = {
  enableLoyaltyPoints: true,
  enableSeatSelection: true,
  enableCarRental: false, // Not ready yet
  enableChatSupport: true
};

// In code
async function createBooking(params) {
  // ... normal booking logic
  
  if (featureFlags.enableLoyaltyPoints) {
    await applyLoyaltyPoints(params.userId, params.amount);
  }
  
  if (featureFlags.enableSeatSelection && params.seats) {
    await reserveSeats(params.seats);
  }
  
  if (featureFlags.enableCarRental && params.carRental) {
    await bookCarRental(params.carRental);
  }
}

// Can toggle features remotely (no deployment!)
// Launch to 10% of users first (A/B testing)
// Roll back instantly if issues found
```

#### 5. **Multi-Platform Support**

```
┌─────────────────────────────────────────────────────┐
│               API GATEWAY                            │
│  (Single backend serves all platforms)              │
└──────────┬──────────────────────────────────────────┘
           │
    ┌──────┴───────┬──────────┬──────────┬──────────┐
    │              │          │          │          │
    ▼              ▼          ▼          ▼          ▼
┌────────┐   ┌────────┐  ┌────────┐ ┌────────┐ ┌────────┐
│  Web   │   │  iOS   │  │Android │ │Partner │ │ Widget │
│  App   │   │  App   │  │  App   │ │  API   │ │(Embed) │
└────────┘   └────────┘  └────────┘ └────────┘ └────────┘

Same API, different clients!
- Web: Full booking flow
- Mobile: Simplified UI, push notifications
- Partner API: White-label booking for travel agents
- Widget: Embeddable search box for blogs
```

**API response formatting (same data, different format)**:
```javascript
app.get('/bookings/:id', async (req, res) => {
  const booking = await getBooking(req.params.id);
  
  // Detect client type from headers
  const clientType = req.headers['x-client-type'];
  
  switch (clientType) {
    case 'web':
      return res.json(booking); // Full details
      
    case 'mobile':
      return res.json({
        // Simplified for mobile
        id: booking.id,
        pnr: booking.pnr,
        flights: booking.flights.map(f => ({
          from: f.origin,
          to: f.destination,
          date: f.date
        }))
      });
      
    case 'widget':
      return res.json({
        // Minimal for widget
        status: booking.status,
        pnr: booking.pnr
      });
      
    default:
      return res.json(booking);
  }
});
```

**Benefits**:
- **Future-proof**: Easy to add new features
- **Vendor flexibility**: Not locked into single provider
- **A/B testing**: Test features before full rollout
- **Multi-platform**: One backend, many frontends
- **Gradual migration**: Can deprecate old features slowly

---

### Summary: Architecture Benefits in Action

**Scenario: Black Friday Sale (10x traffic spike)**

```
Without this architecture:
❌ Monolithic app crashes under load
❌ Database overwhelmed
❌ All users affected
❌ Lost revenue: $500,000

With this architecture:
✅ Auto-scale Search Service (4 → 40 instances)
✅ Redis cache handles 90% of searches
✅ Other services unaffected
✅ No downtime, all sales completed
```

**Scenario: Payment gateway (Stripe) outage**

```
Without this architecture:
❌ All payments fail
❌ Customer support overwhelmed
❌ Lost bookings

With this architecture:
✅ Circuit breaker detects Stripe failure
✅ Automatic fallback to PayPal
✅ Users see "Pay with PayPal" option
✅ Minimal impact
```

**Scenario: New feature request (add hotel booking)**

```
Without this architecture:
❌ Rewrite entire application
❌ 6 months development
❌ High risk of breaking existing features

With this architecture:
✅ Add new Hotel Service
✅ Reuse existing Payment, Notification, User services
✅ 2 weeks development
✅ Zero impact on flight booking
```

---

## Overall Architecture Philosophy

The system uses a **microservices architecture** with **event-driven communication** for loose coupling, combined with:

- **Strong consistency** where critical (bookings, payments)
- **Eventual consistency** where acceptable (search, analytics)
- **Defensive programming** (assume failures will happen)
- **Observability** (monitor everything)
- **Security by default** (encrypt everything, trust nothing)
