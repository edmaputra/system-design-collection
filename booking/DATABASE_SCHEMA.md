# Flight Booking System - Database Schema Design

## Table of Contents
1. [Overview](#overview)
2. [Database Selection Strategy](#database-selection-strategy)
3. [Schema Design by Service](#schema-design-by-service)
4. [Relationships & Foreign Keys](#relationships--foreign-keys)
5. [Indexes & Performance](#indexes--performance)
6. [Data Retention & Archival](#data-retention--archival)
7. [Scaling Strategies](#scaling-strategies)

---

## Overview

### Design Principles

1. **Database Per Service**: Each microservice owns its database
2. **No Cross-Database Joins**: Services communicate via APIs
3. **Denormalization Where Needed**: Trade storage for performance
4. **Audit Trail**: Track all changes to critical data
5. **Soft Deletes**: Never truly delete booking/payment data
6. **Partitioning**: Large tables partitioned by date
7. **GDPR Compliance**: Support data anonymization

### Database Technologies

| Service | Database | Reason |
|---------|----------|--------|
| User Service | PostgreSQL | ACID compliance, relational data |
| Search Service | Redis + PostgreSQL | Cache + search history |
| Booking Service | PostgreSQL | Transactions critical, PNR management |
| Payment Service | PostgreSQL | Financial data, ACID required |
| Notification Service | MongoDB | Document-oriented, high write volume |
| Analytics Service | PostgreSQL + MongoDB | Aggregated metrics + raw events |
| Review Service | PostgreSQL | Relational ratings and reviews |

---

## Database Selection Strategy

### PostgreSQL (Primary Transactional Database)

**When to use**:
- ✅ ACID compliance required (bookings, payments)
- ✅ Complex queries with joins
- ✅ Strong consistency needed
- ✅ Financial data

**Used by**: User, Booking, Payment, Review Services

---

### Redis (Cache & Session Store)

**When to use**:
- ✅ High-speed data access (< 5ms)
- ✅ TTL-based expiration
- ✅ Session management
- ✅ Distributed locks
- ✅ Rate limiting

**Used by**: Search Service (primary), User Service (sessions), Booking Service (locks)

---

### MongoDB (Document Store)

**When to use**:
- ✅ Flexible schema (logs, events)
- ✅ High write throughput
- ✅ Nested documents
- ✅ Time-series data

**Used by**: Notification Service, Analytics Service (events)

---

## Schema Design by Service

### 1. User Service Database

**Database**: `user_service_db` (PostgreSQL)

#### Table: `users`

```sql
CREATE TABLE users (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Authentication
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- bcrypt hash
    email_verified BOOLEAN DEFAULT FALSE,
    
    -- Profile
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    phone_verified BOOLEAN DEFAULT FALSE,
    date_of_birth DATE,
    gender VARCHAR(10), -- MALE, FEMALE, OTHER, PREFER_NOT_TO_SAY
    
    -- Address
    country_code VARCHAR(2), -- ISO 3166-1 alpha-2 (US, GB, etc.)
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state_province VARCHAR(100),
    postal_code VARCHAR(20),
    
    -- Preferences
    preferred_currency VARCHAR(3) DEFAULT 'USD', -- ISO 4217 (USD, EUR, GBP)
    preferred_language VARCHAR(5) DEFAULT 'en', -- ISO 639-1 (en, es, fr)
    newsletter_subscribed BOOLEAN DEFAULT FALSE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, SUSPENDED, DELETED
    role VARCHAR(20) DEFAULT 'CUSTOMER', -- CUSTOMER, ADMIN, AGENT
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE, -- Soft delete (GDPR)
    
    -- Constraints
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT phone_format CHECK (phone IS NULL OR phone ~* '^\+?[1-9]\d{1,14}$')
);

-- Indexes
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_phone ON users(phone) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Table: `user_sessions`

```sql
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Session Info
    token_hash VARCHAR(255) UNIQUE NOT NULL, -- JWT token hash
    refresh_token_hash VARCHAR(255),
    
    -- Device Info
    device_type VARCHAR(50), -- WEB, IOS, ANDROID
    device_id VARCHAR(255),
    user_agent TEXT,
    ip_address INET,
    
    -- Location
    country_code VARCHAR(2),
    city VARCHAR(100),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP WITH TIME ZONE, -- Manual logout
    
    -- Constraints
    CONSTRAINT valid_expiration CHECK (expires_at > created_at)
);

-- Indexes
CREATE INDEX idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_sessions_token_hash ON user_sessions(token_hash) WHERE revoked_at IS NULL;
CREATE INDEX idx_sessions_expires_at ON user_sessions(expires_at);

-- Cleanup expired sessions (run daily)
CREATE INDEX idx_sessions_cleanup ON user_sessions(expires_at) WHERE revoked_at IS NULL;
```

#### Table: `user_travelers` (Frequent Travelers)

```sql
CREATE TABLE user_travelers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Traveler Info
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    date_of_birth DATE NOT NULL,
    gender VARCHAR(10),
    nationality VARCHAR(2), -- ISO 3166-1 alpha-2
    
    -- Passport
    passport_number VARCHAR(20),
    passport_country VARCHAR(2),
    passport_expiry_date DATE,
    
    -- Frequent Flyer
    frequent_flyer_programs JSONB, -- [{airline: 'UA', number: '123456'}]
    
    -- Preferences
    seat_preference VARCHAR(20), -- WINDOW, AISLE, MIDDLE
    meal_preference VARCHAR(50), -- VEGETARIAN, VEGAN, HALAL, KOSHER
    special_assistance TEXT,
    
    -- Metadata
    is_primary BOOLEAN DEFAULT FALSE, -- Main traveler (user themselves)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_passport_expiry CHECK (
        passport_expiry_date IS NULL OR 
        passport_expiry_date > CURRENT_DATE
    )
);

-- Indexes
CREATE INDEX idx_travelers_user_id ON user_travelers(user_id);
CREATE UNIQUE INDEX idx_travelers_primary ON user_travelers(user_id) 
    WHERE is_primary = TRUE;

CREATE TRIGGER update_user_travelers_updated_at BEFORE UPDATE ON user_travelers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Table: `user_payment_methods`

```sql
CREATE TABLE user_payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Payment Info (NEVER store raw card data!)
    payment_gateway VARCHAR(50) NOT NULL, -- STRIPE, PAYPAL, BRAINTREE
    payment_token VARCHAR(255) NOT NULL, -- Gateway token (e.g., tok_xyz)
    
    -- Card Info (safe to store)
    card_brand VARCHAR(20), -- VISA, MASTERCARD, AMEX
    card_last4 VARCHAR(4), -- Last 4 digits only
    card_exp_month INTEGER,
    card_exp_year INTEGER,
    
    -- Billing Address
    billing_name VARCHAR(200),
    billing_country VARCHAR(2),
    billing_postal_code VARCHAR(20),
    
    -- Metadata
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE, -- Soft delete
    
    -- Constraints
    CONSTRAINT valid_expiry CHECK (
        card_exp_year > EXTRACT(YEAR FROM CURRENT_DATE) OR
        (card_exp_year = EXTRACT(YEAR FROM CURRENT_DATE) AND 
         card_exp_month >= EXTRACT(MONTH FROM CURRENT_DATE))
    )
);

-- Indexes
CREATE INDEX idx_payment_methods_user_id ON user_payment_methods(user_id) 
    WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_payment_methods_default ON user_payment_methods(user_id) 
    WHERE is_default = TRUE AND deleted_at IS NULL;

CREATE TRIGGER update_payment_methods_updated_at BEFORE UPDATE ON user_payment_methods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

### 2. Search Service Database

**Primary**: Redis (cache)  
**Secondary**: PostgreSQL (analytics)

#### Redis Data Structures

```redis
# Flight Search Results (5-minute TTL)
# Key pattern: flight:search:{origin}:{dest}:{date}:{passengers}:{class}
# Type: String (JSON)
# Example:
SET flight:search:JFK:LAX:2025-12-15:2:economy '{
  "searchId": "search_123abc",
  "results": [...],
  "timestamp": 1699200000
}' EX 300

# Popular Routes Cache (1-hour TTL)
# Key: flight:popular:routes
# Type: Sorted Set (score = search count)
ZADD flight:popular:routes 1523 "JFK-LAX"
ZADD flight:popular:routes 1245 "LAX-NYC"
ZADD flight:popular:routes 892 "SFO-SEA"

# Airport Autocomplete (24-hour TTL)
# Key: flight:airports:{prefix}
# Type: String (JSON array)
SET flight:airports:LA '["LAX - Los Angeles", "LAS - Las Vegas", "LAM - Los Mochis"]' EX 86400

# Rate Limiting (per user)
# Key: ratelimit:search:{user_id}
# Type: String (counter)
INCR ratelimit:search:user_123
EXPIRE ratelimit:search:user_123 3600 # 1 hour window
```

#### PostgreSQL Tables (Analytics)

```sql
-- Database: search_service_db

CREATE TABLE search_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID, -- Can be NULL for anonymous searches
    
    -- Search Parameters
    origin_airport VARCHAR(3) NOT NULL,
    destination_airport VARCHAR(3) NOT NULL,
    departure_date DATE NOT NULL,
    return_date DATE,
    passengers_adult INTEGER DEFAULT 1,
    passengers_child INTEGER DEFAULT 0,
    passengers_infant INTEGER DEFAULT 0,
    cabin_class VARCHAR(20), -- ECONOMY, PREMIUM_ECONOMY, BUSINESS, FIRST
    
    -- Results
    results_count INTEGER DEFAULT 0,
    cheapest_price DECIMAL(10, 2),
    most_expensive_price DECIMAL(10, 2),
    average_price DECIMAL(10, 2),
    
    -- Performance
    response_time_ms INTEGER, -- How long the search took
    cache_hit BOOLEAN DEFAULT FALSE,
    gds_providers VARCHAR[] DEFAULT '{}', -- ['AMADEUS', 'SABRE']
    
    -- Metadata
    session_id UUID,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for analytics queries
CREATE INDEX idx_search_history_user_id ON search_history(user_id);
CREATE INDEX idx_search_history_route ON search_history(origin_airport, destination_airport);
CREATE INDEX idx_search_history_created_at ON search_history(created_at);
CREATE INDEX idx_search_history_departure_date ON search_history(departure_date);

-- Partition by month for better query performance
CREATE TABLE search_history_2025_11 PARTITION OF search_history
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

CREATE TABLE search_history_2025_12 PARTITION OF search_history
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
```

---

### 3. Booking Service Database

**Database**: `booking_service_db` (PostgreSQL)

#### Table: `bookings`

```sql
CREATE TABLE bookings (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference
    booking_reference VARCHAR(10) UNIQUE NOT NULL, -- User-friendly (e.g., BK123ABC)
    pnr VARCHAR(6) NOT NULL, -- GDS PNR (e.g., ABC123)
    user_id UUID NOT NULL, -- Foreign key to User Service (via API, not FK constraint)
    
    -- GDS Info
    gds_provider VARCHAR(50) NOT NULL, -- AMADEUS, SABRE, TRAVELPORT
    gds_booking_id VARCHAR(100), -- GDS internal ID
    
    -- Flight Details (Denormalized for performance)
    origin_airport VARCHAR(3) NOT NULL,
    destination_airport VARCHAR(3) NOT NULL,
    departure_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    arrival_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    flight_type VARCHAR(20) NOT NULL, -- ONE_WAY, ROUND_TRIP, MULTI_CITY
    
    -- Pricing
    base_fare DECIMAL(10, 2) NOT NULL,
    taxes DECIMAL(10, 2) NOT NULL,
    fees DECIMAL(10, 2) DEFAULT 0.00,
    total_amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    
    -- Booking Status
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING_PAYMENT',
    -- Status flow: PENDING_PAYMENT → CONFIRMED → CHECKED_IN → COMPLETED
    --              PENDING_PAYMENT → FAILED
    --              CONFIRMED → CANCELLED
    
    -- Payment Status
    payment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    -- PENDING, AUTHORIZED, CAPTURED, FAILED, REFUNDED, PARTIALLY_REFUNDED
    
    payment_id UUID, -- Reference to Payment Service
    
    -- Ticketing
    ticketed BOOLEAN DEFAULT FALSE,
    ticket_issued_at TIMESTAMP WITH TIME ZONE,
    ticket_time_limit TIMESTAMP WITH TIME ZONE, -- Deadline to issue ticket
    
    -- Contact Info (denormalized)
    contact_email VARCHAR(255) NOT NULL,
    contact_phone VARCHAR(20) NOT NULL,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT,
    
    -- GDPR
    user_deleted BOOLEAN DEFAULT FALSE, -- User deleted account, anonymize
    
    -- Constraints
    CONSTRAINT valid_amount CHECK (total_amount >= 0),
    CONSTRAINT valid_status CHECK (status IN (
        'PENDING_PAYMENT', 'CONFIRMED', 'FAILED', 
        'CANCELLED', 'CHECKED_IN', 'COMPLETED', 'REFUNDED'
    )),
    CONSTRAINT valid_payment_status CHECK (payment_status IN (
        'PENDING', 'AUTHORIZED', 'CAPTURED', 
        'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED'
    ))
);

-- Indexes
CREATE UNIQUE INDEX idx_bookings_booking_ref ON bookings(booking_reference);
CREATE INDEX idx_bookings_pnr ON bookings(pnr);
CREATE INDEX idx_bookings_user_id ON bookings(user_id) WHERE user_deleted = FALSE;
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_departure ON bookings(departure_datetime);
CREATE INDEX idx_bookings_created_at ON bookings(created_at);

-- Performance: Partition large table by departure month
CREATE TABLE bookings_2025_11 PARTITION OF bookings
    FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');

CREATE TABLE bookings_2025_12 PARTITION OF bookings
    FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Table: `booking_passengers`

```sql
CREATE TABLE booking_passengers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    
    -- Passenger Type
    passenger_type VARCHAR(10) NOT NULL, -- ADULT, CHILD, INFANT
    
    -- Personal Info
    title VARCHAR(10), -- MR, MRS, MS, MISS, DR
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender VARCHAR(10),
    nationality VARCHAR(2), -- ISO 3166-1
    
    -- Passport (for international flights)
    passport_number VARCHAR(20),
    passport_country VARCHAR(2),
    passport_expiry_date DATE,
    
    -- Frequent Flyer
    frequent_flyer_airline VARCHAR(2), -- IATA airline code (UA, AA, DL)
    frequent_flyer_number VARCHAR(50),
    
    -- E-Ticket
    ticket_number VARCHAR(20), -- 13-digit e-ticket number
    ticket_status VARCHAR(20), -- ISSUED, VOIDED, REFUNDED, EXCHANGED
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_passenger_type CHECK (passenger_type IN ('ADULT', 'CHILD', 'INFANT')),
    CONSTRAINT valid_passport_expiry CHECK (
        passport_expiry_date IS NULL OR 
        passport_expiry_date > CURRENT_DATE
    )
);

-- Indexes
CREATE INDEX idx_passengers_booking_id ON booking_passengers(booking_id);
CREATE INDEX idx_passengers_ticket_number ON booking_passengers(ticket_number);

CREATE TRIGGER update_passengers_updated_at BEFORE UPDATE ON booking_passengers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Table: `booking_flights`

```sql
CREATE TABLE booking_flights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    
    -- Flight Segment
    segment_number INTEGER NOT NULL, -- 1, 2, 3 for multi-leg flights
    
    -- Flight Info
    airline_code VARCHAR(2) NOT NULL, -- IATA code (UA, AA, DL)
    airline_name VARCHAR(100) NOT NULL,
    flight_number VARCHAR(10) NOT NULL, -- UA1234
    
    -- Aircraft
    aircraft_type VARCHAR(50), -- Boeing 777-200
    aircraft_code VARCHAR(10), -- 777
    
    -- Departure
    departure_airport VARCHAR(3) NOT NULL,
    departure_terminal VARCHAR(10),
    departure_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Arrival
    arrival_airport VARCHAR(3) NOT NULL,
    arrival_terminal VARCHAR(10),
    arrival_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Cabin & Class
    cabin_class VARCHAR(20) NOT NULL, -- ECONOMY, BUSINESS, FIRST
    booking_class VARCHAR(2) NOT NULL, -- Y, W, J, F (fare class)
    
    -- Duration
    flight_duration_minutes INTEGER,
    
    -- Baggage
    baggage_allowance JSONB, -- {checked: '2x23kg', cabin: '1x7kg'}
    
    -- Status
    status VARCHAR(20) DEFAULT 'CONFIRMED',
    -- CONFIRMED, CHECKED_IN, BOARDED, DEPARTED, ARRIVED, CANCELLED
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_segment CHECK (segment_number > 0),
    CONSTRAINT valid_duration CHECK (flight_duration_minutes > 0)
);

-- Indexes
CREATE INDEX idx_flights_booking_id ON booking_flights(booking_id);
CREATE INDEX idx_flights_departure ON booking_flights(departure_datetime);
CREATE INDEX idx_flights_airline ON booking_flights(airline_code);

CREATE TRIGGER update_flights_updated_at BEFORE UPDATE ON booking_flights
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Table: `booking_ancillaries` (Add-ons)

```sql
CREATE TABLE booking_ancillaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    passenger_id UUID REFERENCES booking_passengers(id) ON DELETE CASCADE,
    flight_id UUID REFERENCES booking_flights(id) ON DELETE CASCADE,
    
    -- Ancillary Type
    ancillary_type VARCHAR(50) NOT NULL,
    -- SEAT_SELECTION, EXTRA_BAGGAGE, MEAL, LOUNGE_ACCESS, 
    -- PRIORITY_BOARDING, WIFI, INSURANCE
    
    -- Details
    description TEXT NOT NULL, -- "Seat 12A - Window", "Extra 23kg bag"
    quantity INTEGER DEFAULT 1,
    
    -- Pricing
    price DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Status
    status VARCHAR(20) DEFAULT 'CONFIRMED', -- CONFIRMED, CANCELLED, REFUNDED
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_price CHECK (price >= 0),
    CONSTRAINT valid_quantity CHECK (quantity > 0)
);

-- Indexes
CREATE INDEX idx_ancillaries_booking_id ON booking_ancillaries(booking_id);
CREATE INDEX idx_ancillaries_type ON booking_ancillaries(ancillary_type);

CREATE TRIGGER update_ancillaries_updated_at BEFORE UPDATE ON booking_ancillaries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Table: `booking_audit_log`

```sql
CREATE TABLE booking_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    
    -- Change Info
    changed_by UUID, -- User ID who made the change
    changed_by_type VARCHAR(20), -- CUSTOMER, ADMIN, SYSTEM, GDS
    
    -- What Changed
    action VARCHAR(50) NOT NULL,
    -- CREATED, STATUS_CHANGED, PAYMENT_UPDATED, CANCELLED, 
    -- MODIFIED, TICKET_ISSUED, CHECKED_IN
    
    old_value JSONB, -- Previous state
    new_value JSONB, -- New state
    
    -- Context
    ip_address INET,
    user_agent TEXT,
    notes TEXT,
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_action CHECK (action IN (
        'CREATED', 'STATUS_CHANGED', 'PAYMENT_UPDATED', 
        'CANCELLED', 'MODIFIED', 'TICKET_ISSUED', 
        'CHECKED_IN', 'REFUNDED'
    ))
);

-- Indexes
CREATE INDEX idx_audit_booking_id ON booking_audit_log(booking_id);
CREATE INDEX idx_audit_created_at ON booking_audit_log(created_at);
CREATE INDEX idx_audit_action ON booking_audit_log(action);
```

---

### 4. Payment Service Database

**Database**: `payment_service_db` (PostgreSQL)

#### Table: `payments`

```sql
CREATE TABLE payments (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference
    payment_reference VARCHAR(20) UNIQUE NOT NULL, -- PAY123ABC
    booking_id UUID NOT NULL, -- Foreign key to Booking Service (via API)
    user_id UUID NOT NULL, -- Foreign key to User Service (via API)
    
    -- Payment Gateway
    payment_gateway VARCHAR(50) NOT NULL, -- STRIPE, PAYPAL, BRAINTREE
    gateway_transaction_id VARCHAR(255), -- Stripe charge ID, PayPal transaction ID
    gateway_payment_intent_id VARCHAR(255), -- For payment intents
    
    -- Amount
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    
    -- Payment Method (NEVER store raw card!)
    payment_method_type VARCHAR(50) NOT NULL, -- CARD, PAYPAL, BANK_TRANSFER
    payment_token VARCHAR(255), -- Gateway token
    
    -- Card Info (safe to store)
    card_brand VARCHAR(20), -- VISA, MASTERCARD, AMEX
    card_last4 VARCHAR(4),
    card_exp_month INTEGER,
    card_exp_year INTEGER,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    -- PENDING → AUTHORIZED → CAPTURED → COMPLETED
    -- PENDING → FAILED
    -- CAPTURED → REFUNDED / PARTIALLY_REFUNDED
    
    -- Fraud Detection
    fraud_score DECIMAL(5, 2), -- 0.00 to 100.00
    fraud_status VARCHAR(20), -- SAFE, REVIEW, BLOCKED
    risk_factors JSONB, -- ['high_value', 'new_customer', 'foreign_ip']
    
    -- 3D Secure
    three_d_secure_status VARCHAR(20), -- AUTHENTICATED, NOT_AUTHENTICATED, ATTEMPTED
    three_d_secure_version VARCHAR(10), -- 1.0, 2.0
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    authorized_at TIMESTAMP WITH TIME ZONE,
    captured_at TIMESTAMP WITH TIME ZONE,
    failed_at TIMESTAMP WITH TIME ZONE,
    
    -- Failure Info
    failure_code VARCHAR(50),
    failure_message TEXT,
    
    -- Metadata
    ip_address INET,
    user_agent TEXT,
    
    -- Idempotency (prevent duplicate charges)
    idempotency_key VARCHAR(255) UNIQUE,
    
    -- Constraints
    CONSTRAINT valid_amount CHECK (amount > 0),
    CONSTRAINT valid_status CHECK (status IN (
        'PENDING', 'AUTHORIZED', 'CAPTURED', 'COMPLETED',
        'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED', 'CANCELLED'
    ))
);

-- Indexes
CREATE UNIQUE INDEX idx_payments_reference ON payments(payment_reference);
CREATE INDEX idx_payments_booking_id ON payments(booking_id);
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created_at ON payments(created_at);
CREATE INDEX idx_payments_gateway_txn ON payments(gateway_transaction_id);
CREATE UNIQUE INDEX idx_payments_idempotency ON payments(idempotency_key) 
    WHERE idempotency_key IS NOT NULL;

-- Partition by month
CREATE TABLE payments_2025_11 PARTITION OF payments
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Table: `refunds`

```sql
CREATE TABLE refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    
    -- Refund Info
    refund_reference VARCHAR(20) UNIQUE NOT NULL, -- REF123ABC
    gateway_refund_id VARCHAR(255), -- Stripe refund ID
    
    -- Amount
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    
    -- Reason
    reason VARCHAR(50) NOT NULL,
    -- CUSTOMER_REQUEST, CANCELLATION, FRAUD, 
    -- DUPLICATE, SCHEDULE_CHANGE, OTHER
    
    reason_details TEXT,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    -- PENDING, PROCESSING, COMPLETED, FAILED, CANCELLED
    
    -- Timestamps
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    failed_at TIMESTAMP WITH TIME ZONE,
    
    -- Failure
    failure_reason TEXT,
    
    -- Metadata
    requested_by UUID, -- User ID or admin ID
    requested_by_type VARCHAR(20), -- CUSTOMER, ADMIN, SYSTEM
    
    -- Constraints
    CONSTRAINT valid_refund_amount CHECK (amount > 0),
    CONSTRAINT valid_refund_status CHECK (status IN (
        'PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED'
    ))
);

-- Indexes
CREATE INDEX idx_refunds_payment_id ON refunds(payment_id);
CREATE INDEX idx_refunds_status ON refunds(status);
CREATE INDEX idx_refunds_requested_at ON refunds(requested_at);
```

#### Table: `payment_attempts` (Retry History)

```sql
CREATE TABLE payment_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    
    -- Attempt Info
    attempt_number INTEGER NOT NULL, -- 1, 2, 3
    
    -- Gateway Response
    gateway_response_code VARCHAR(50),
    gateway_response_message TEXT,
    
    -- Result
    success BOOLEAN NOT NULL,
    
    -- Timestamp
    attempted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_attempt_number CHECK (attempt_number > 0)
);

-- Indexes
CREATE INDEX idx_attempts_payment_id ON payment_attempts(payment_id);
CREATE INDEX idx_attempts_attempted_at ON payment_attempts(attempted_at);
```

---

### 5. Notification Service Database

**Database**: `notification_service_db` (MongoDB)

#### Collection: `notifications`

```javascript
{
  "_id": ObjectId("507f1f77bcf86cd799439011"),
  
  // Target
  "user_id": "uuid-123",
  "recipient_email": "john@example.com",
  "recipient_phone": "+1234567890",
  
  // Notification Type
  "type": "BOOKING_CONFIRMATION", 
  // BOOKING_CONFIRMATION, PAYMENT_RECEIPT, CANCELLATION,
  // FLIGHT_REMINDER, CHECK_IN_REMINDER, SCHEDULE_CHANGE,
  // PASSWORD_RESET, EMAIL_VERIFICATION
  
  // Channel
  "channel": "EMAIL", // EMAIL, SMS, PUSH, IN_APP
  
  // Content
  "subject": "Booking Confirmed - ABC123",
  "body": "Your flight booking is confirmed...",
  "html_body": "<html>...</html>",
  
  // Template
  "template_id": "booking_confirmation_v2",
  "template_variables": {
    "pnr": "ABC123",
    "passenger_name": "John Doe",
    "flight_number": "UA1234",
    "departure_date": "2025-12-15"
  },
  
  // Status
  "status": "SENT", // PENDING, SENDING, SENT, FAILED, BOUNCED
  
  // Delivery Info
  "provider": "SENDGRID", // SENDGRID, TWILIO, FIREBASE
  "provider_message_id": "msg_xyz789",
  "delivery_attempts": 1,
  "max_attempts": 3,
  
  // Tracking
  "opened_at": ISODate("2025-11-05T10:35:00Z"),
  "clicked_at": ISODate("2025-11-05T10:40:00Z"),
  
  // Timestamps
  "created_at": ISODate("2025-11-05T10:30:00Z"),
  "sent_at": ISODate("2025-11-05T10:30:15Z"),
  "failed_at": null,
  
  // Failure Info
  "error_code": null,
  "error_message": null,
  
  // Related Entities
  "booking_id": "uuid-456",
  "payment_id": "uuid-789",
  
  // Metadata
  "priority": "HIGH", // LOW, NORMAL, HIGH, URGENT
  "scheduled_at": null, // For scheduled notifications
  "expires_at": ISODate("2025-11-06T10:30:00Z") // Don't send after this
}

// Indexes
db.notifications.createIndex({ "user_id": 1, "created_at": -1 });
db.notifications.createIndex({ "status": 1 });
db.notifications.createIndex({ "channel": 1, "status": 1 });
db.notifications.createIndex({ "created_at": 1 }, { expireAfterSeconds: 7776000 }); // TTL: 90 days
```

#### Collection: `notification_templates`

```javascript
{
  "_id": "booking_confirmation_v2",
  
  // Template Info
  "name": "Booking Confirmation",
  "description": "Sent when flight booking is confirmed",
  "version": 2,
  
  // Channels
  "channels": ["EMAIL", "SMS"],
  
  // Email Template
  "email": {
    "subject": "Booking Confirmed - {{pnr}}",
    "body_text": "Hello {{passenger_name}}, your flight {{flight_number}} is confirmed...",
    "body_html": "<html>...</html>",
    "from_email": "bookings@flightbooking.com",
    "from_name": "Flight Booking"
  },
  
  // SMS Template
  "sms": {
    "body": "Flight {{flight_number}} confirmed! PNR: {{pnr}}. Check-in opens 24hrs before departure."
  },
  
  // Variables
  "required_variables": [
    "pnr",
    "passenger_name",
    "flight_number",
    "departure_date",
    "origin",
    "destination"
  ],
  
  // Status
  "active": true,
  
  // Metadata
  "created_at": ISODate("2025-01-01T00:00:00Z"),
  "updated_at": ISODate("2025-06-15T00:00:00Z")
}

// Indexes
db.notification_templates.createIndex({ "active": 1 });
```

---

### 6. Analytics Service Database

**Primary**: MongoDB (raw events)  
**Secondary**: PostgreSQL (aggregated metrics)

#### MongoDB Collection: `events`

```javascript
{
  "_id": ObjectId("507f1f77bcf86cd799439011"),
  
  // Event Type
  "event_type": "booking_created",
  // search_performed, booking_created, payment_completed,
  // booking_cancelled, user_registered, flight_searched
  
  // Event Data
  "event_data": {
    "booking_id": "uuid-123",
    "user_id": "uuid-456",
    "amount": 456.80,
    "currency": "USD",
    "origin": "JFK",
    "destination": "LAX",
    "departure_date": "2025-12-15",
    "passengers": 2
  },
  
  // Context
  "user_id": "uuid-456",
  "session_id": "uuid-789",
  "ip_address": "192.168.1.1",
  "user_agent": "Mozilla/5.0...",
  "device_type": "DESKTOP", // DESKTOP, MOBILE, TABLET
  
  // Location
  "country_code": "US",
  "city": "New York",
  
  // Timestamp
  "timestamp": ISODate("2025-11-05T10:30:00Z"),
  "date": "2025-11-05",
  "hour": 10,
  
  // Metadata
  "service": "booking-service",
  "version": "1.2.3"
}

// Indexes
db.events.createIndex({ "event_type": 1, "timestamp": -1 });
db.events.createIndex({ "user_id": 1, "timestamp": -1 });
db.events.createIndex({ "timestamp": -1 });
db.events.createIndex({ "date": 1 });

// TTL index (auto-delete events after 1 year)
db.events.createIndex({ "timestamp": 1 }, { expireAfterSeconds: 31536000 });
```

#### PostgreSQL Tables (Aggregated Metrics)

```sql
-- Database: analytics_service_db

CREATE TABLE daily_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Date
    metric_date DATE NOT NULL,
    
    -- Metrics
    total_searches INTEGER DEFAULT 0,
    total_bookings INTEGER DEFAULT 0,
    total_revenue DECIMAL(12, 2) DEFAULT 0.00,
    
    -- Conversion
    search_to_booking_rate DECIMAL(5, 2), -- Percentage
    average_booking_value DECIMAL(10, 2),
    
    -- Users
    new_users INTEGER DEFAULT 0,
    active_users INTEGER DEFAULT 0,
    
    -- Top Routes (JSON for flexibility)
    top_routes JSONB,
    -- Example: [{"route": "JFK-LAX", "count": 156}, ...]
    
    -- Timestamps
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraint
    CONSTRAINT unique_daily_metric UNIQUE (metric_date)
);

CREATE INDEX idx_daily_metrics_date ON daily_metrics(metric_date DESC);
```

---

### 7. Review Service Database

**Database**: `review_service_db` (PostgreSQL)

#### Table: `reviews`

```sql
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference
    booking_id UUID NOT NULL, -- Must have booking to review
    user_id UUID NOT NULL,
    
    -- Review Target
    review_type VARCHAR(20) NOT NULL, -- FLIGHT, AIRLINE, AIRPORT
    airline_code VARCHAR(2), -- UA, AA, DL (if review_type = AIRLINE or FLIGHT)
    flight_number VARCHAR(10), -- UA1234 (if review_type = FLIGHT)
    airport_code VARCHAR(3), -- JFK (if review_type = AIRPORT)
    
    -- Rating (1-5 stars)
    overall_rating INTEGER NOT NULL,
    cabin_rating INTEGER,
    service_rating INTEGER,
    food_rating INTEGER,
    entertainment_rating INTEGER,
    value_rating INTEGER,
    
    -- Review Content
    title VARCHAR(200),
    review_text TEXT,
    
    -- Travel Info
    cabin_class VARCHAR(20), -- ECONOMY, BUSINESS, FIRST
    travel_date DATE,
    
    -- Verification
    verified_booking BOOLEAN DEFAULT FALSE, -- Actually flew this route
    
    -- Status
    status VARCHAR(20) DEFAULT 'PENDING',
    -- PENDING, APPROVED, REJECTED, FLAGGED
    
    moderation_notes TEXT,
    moderated_by UUID, -- Admin user ID
    moderated_at TIMESTAMP WITH TIME ZONE,
    
    -- Helpfulness
    helpful_count INTEGER DEFAULT 0,
    not_helpful_count INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_overall_rating CHECK (overall_rating BETWEEN 1 AND 5),
    CONSTRAINT valid_cabin_rating CHECK (cabin_rating IS NULL OR cabin_rating BETWEEN 1 AND 5),
    CONSTRAINT valid_service_rating CHECK (service_rating IS NULL OR service_rating BETWEEN 1 AND 5),
    CONSTRAINT one_review_per_booking UNIQUE (booking_id, user_id)
);

-- Indexes
CREATE INDEX idx_reviews_airline ON reviews(airline_code, status);
CREATE INDEX idx_reviews_flight ON reviews(flight_number, status);
CREATE INDEX idx_reviews_airport ON reviews(airport_code, status);
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_created_at ON reviews(created_at DESC);

CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON reviews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Table: `review_votes` (Helpfulness Voting)

```sql
CREATE TABLE review_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    
    -- Vote
    vote VARCHAR(10) NOT NULL, -- HELPFUL, NOT_HELPFUL
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_vote CHECK (vote IN ('HELPFUL', 'NOT_HELPFUL')),
    CONSTRAINT one_vote_per_user UNIQUE (review_id, user_id)
);

-- Indexes
CREATE INDEX idx_votes_review_id ON review_votes(review_id);
```

---

## Relationships & Foreign Keys

### Cross-Service References

**Important**: Services should NOT have foreign key constraints to other services' databases. Instead, reference by ID and validate via API calls.

```sql
-- ❌ BAD: Foreign key to another service's database
CREATE TABLE bookings (
    user_id UUID REFERENCES user_service_db.users(id) -- WRONG!
);

-- ✅ GOOD: Reference by ID, validate via API
CREATE TABLE bookings (
    user_id UUID NOT NULL -- Just store the ID
);

-- Validate in application code:
async function createBooking(bookingData) {
    // Call User Service API to verify user exists
    const user = await userServiceClient.getUser(bookingData.user_id);
    if (!user) {
        throw new Error('User not found');
    }
    
    // Proceed with booking
    await db.bookings.create(bookingData);
}
```

### Within-Service Foreign Keys

```sql
-- ✅ GOOD: Foreign keys within same service
CREATE TABLE booking_passengers (
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE
);

CREATE TABLE booking_flights (
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE
);
```

---

## Indexes & Performance

### Index Strategy

```sql
-- 1. Primary Keys (automatic B-tree index)
CREATE TABLE bookings (
    id UUID PRIMARY KEY -- Automatic index
);

-- 2. Foreign Keys (for JOINs)
CREATE INDEX idx_passengers_booking_id ON booking_passengers(booking_id);

-- 3. Lookup Fields (WHERE clauses)
CREATE INDEX idx_bookings_pnr ON bookings(pnr);
CREATE INDEX idx_bookings_user_id ON bookings(user_id);

-- 4. Sorting Fields (ORDER BY)
CREATE INDEX idx_bookings_created_at ON bookings(created_at DESC);

-- 5. Partial Indexes (for specific queries)
CREATE INDEX idx_active_bookings ON bookings(status) 
    WHERE status IN ('CONFIRMED', 'PENDING_PAYMENT');

-- 6. Composite Indexes (multiple columns)
CREATE INDEX idx_bookings_user_date ON bookings(user_id, departure_datetime);

-- 7. Unique Indexes (enforce uniqueness)
CREATE UNIQUE INDEX idx_bookings_reference ON bookings(booking_reference);
```

### Query Performance Examples

```sql
-- Fast query (uses index)
SELECT * FROM bookings 
WHERE user_id = '123' 
  AND status = 'CONFIRMED'
ORDER BY created_at DESC
LIMIT 10;
-- Uses: idx_bookings_user_id, idx_active_bookings, idx_bookings_created_at

-- Slow query (full table scan)
SELECT * FROM bookings 
WHERE LOWER(contact_email) = 'john@example.com';
-- No index on LOWER(contact_email)!

-- Fix: Create functional index
CREATE INDEX idx_bookings_email_lower ON bookings(LOWER(contact_email));
```

---

## Data Retention & Archival

### Retention Policy

| Data Type | Retention | Archival Strategy |
|-----------|-----------|-------------------|
| Active bookings | Forever | Keep in main database |
| Completed bookings (< 2 years) | 2 years | Main database |
| Completed bookings (> 2 years) | 7 years | Move to archive DB (cold storage) |
| Payment records | 7 years | Legal requirement (tax/audit) |
| Search history | 90 days | Delete after 90 days |
| User sessions | 30 days | Auto-expire (Redis TTL) |
| Notification logs | 90 days | MongoDB TTL index |
| Analytics events | 1 year | Archive to data warehouse |
| Audit logs | Forever | Compliance requirement |

### Implementation

```sql
-- Automatic cleanup (PostgreSQL)
CREATE OR REPLACE FUNCTION archive_old_bookings()
RETURNS void AS $$
BEGIN
    -- Move bookings older than 2 years to archive table
    INSERT INTO bookings_archive
    SELECT * FROM bookings
    WHERE status IN ('COMPLETED', 'CANCELLED')
      AND created_at < CURRENT_DATE - INTERVAL '2 years';
    
    -- Delete from main table
    DELETE FROM bookings
    WHERE status IN ('COMPLETED', 'CANCELLED')
      AND created_at < CURRENT_DATE - INTERVAL '2 years';
END;
$$ LANGUAGE plpgsql;

-- Run monthly via cron job
SELECT archive_old_bookings();
```

```javascript
// Automatic cleanup (MongoDB TTL)
db.events.createIndex(
    { "timestamp": 1 }, 
    { expireAfterSeconds: 7776000 } // 90 days
);
```

---

## Scaling Strategies

### 1. Vertical Scaling (Scale Up)

```
Increase database instance size:
- Small: 2 CPU, 4GB RAM → $50/month
- Medium: 4 CPU, 16GB RAM → $200/month
- Large: 8 CPU, 32GB RAM → $500/month
- XLarge: 16 CPU, 64GB RAM → $1,000/month
```

**When to use**: Initial growth, simple to implement

---

### 2. Read Replicas (Horizontal Read Scaling)

```
                    ┌──────────────┐
                    │   Primary    │
                    │  (Read/Write)│
                    └──────┬───────┘
                           │
            Replication    │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
     ┌──────────┐   ┌──────────┐   ┌──────────┐
     │ Replica 1│   │ Replica 2│   │ Replica 3│
     │(Read Only│   │(Read Only│   │(Read Only│
     └──────────┘   └──────────┘   └──────────┘
     
Writes → Primary
Reads  → Round-robin across replicas
```

**Use case**: 
- Search queries (high read volume)
- Analytics queries (don't slow down production)

---

### 3. Sharding (Horizontal Write Scaling)

```
Shard by user_id:

User ID Hash → Shard Number
user_123 → Shard 1
user_456 → Shard 2
user_789 → Shard 3

┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│   Shard 1   │   │   Shard 2   │   │   Shard 3   │
│ Users 0-333k│   │Users 334-667k│  │Users 668k-1M│
└─────────────┘   └─────────────┘   └─────────────┘
```

**Use case**: 
- Millions of users
- High write volume
- Distributed load

---

### 4. Partitioning (Table Partitioning)

```sql
-- Already implemented in bookings table
CREATE TABLE bookings_2025_11 PARTITION OF bookings
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

-- Benefits:
-- 1. Query only relevant partition (10x faster)
-- 2. Archive old partitions easily
-- 3. Better index performance
```

---

### 5. Caching Strategy

```
L1: Application Cache (in-memory)
    └─ Response time: < 1ms
    └─ Size: Limited by RAM
    └─ Use case: Hot data (current user session)

L2: Redis Cache (distributed)
    └─ Response time: 1-5ms
    └─ Size: Configurable (GB to TB)
    └─ Use case: Search results, session data

L3: PostgreSQL (database)
    └─ Response time: 10-50ms
    └─ Size: Large (TB)
    └─ Use case: Persistent data

L4: Archive Storage (S3)
    └─ Response time: 100-500ms
    └─ Size: Unlimited
    └─ Use case: Old bookings, backups
```

---

## Summary

### Database Distribution

```
PostgreSQL (4 databases):
├── user_service_db (users, sessions, travelers)
├── booking_service_db (bookings, passengers, flights)
├── payment_service_db (payments, refunds)
└── review_service_db (reviews, votes)

Redis (3 instances):
├── search_cache (flight results)
├── user_sessions (JWT tokens)
└── booking_locks (distributed locks)

MongoDB (2 databases):
├── notification_service_db (notifications, templates)
└── analytics_service_db (events)
```

### Total Tables: 25

**User Service**: 4 tables (users, sessions, travelers, payment_methods)  
**Search Service**: 1 table (search_history) + Redis  
**Booking Service**: 6 tables (bookings, passengers, flights, ancillaries, audit_log)  
**Payment Service**: 3 tables (payments, refunds, attempts)  
**Notification Service**: 2 collections (notifications, templates)  
**Analytics Service**: 2 collections + 1 table (events, daily_metrics)  
**Review Service**: 2 tables (reviews, votes)

### Key Design Decisions

✅ **Database per service** (microservices isolation)  
✅ **No cross-database foreign keys** (loose coupling)  
✅ **Partitioning by date** (performance at scale)  
✅ **Soft deletes** (GDPR compliance, audit trail)  
✅ **Comprehensive indexes** (query performance)  
✅ **Audit logging** (compliance, debugging)  
✅ **JSONB for flexibility** (ancillaries, metadata)  
✅ **TTL for auto-cleanup** (storage efficiency)

This schema supports millions of users and bookings while maintaining performance, compliance, and scalability! 🚀
