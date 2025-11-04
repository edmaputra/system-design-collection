# Database Design & Modeling

## 🗄️ Database Architecture Overview

The Flight Booking System uses a **polyglot persistence** approach, selecting the most appropriate database technology for each service's specific requirements.

## 📊 Database Selection Strategy

| Service | Primary DB | Secondary | Use Case |
|---------|------------|-----------|----------|
| User Service | PostgreSQL | Redis | ACID transactions, caching |
| Flight Service | PostgreSQL | Redis | Complex queries, search cache |
| Booking Service | PostgreSQL | - | Strong consistency required |
| Payment Service | PostgreSQL | - | ACID compliance, encryption |
| Inventory Service | PostgreSQL | Redis | Real-time updates, caching |
| Notification Service | MongoDB | - | Document storage, flexibility |
| Analytics Service | BigQuery/Snowflake | - | Data warehousing, OLAP |
| Audit Service | Elasticsearch | - | Full-text search, log analysis |

## 🏗️ Core Database Schemas

### User Service Schema (PostgreSQL)

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE,
    nationality VARCHAR(3), -- ISO country code
    passport_number VARCHAR(50),
    passport_expiry DATE,
    frequent_flyer_numbers JSONB,
    preferences JSONB,
    status VARCHAR(20) DEFAULT 'active', -- active, inactive, suspended
    email_verified BOOLEAN DEFAULT false,
    phone_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE
);

-- User roles
CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL, -- customer, admin, agent
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    granted_by UUID REFERENCES users(id)
);

-- User sessions
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    device_info JSONB,
    ip_address INET,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_user_sessions_token ON user_sessions(token_hash);
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
```

### Flight Service Schema (PostgreSQL)

```sql
-- Airlines
CREATE TABLE airlines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    iata_code VARCHAR(2) UNIQUE NOT NULL,
    icao_code VARCHAR(3) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    country VARCHAR(3) NOT NULL,
    logo_url VARCHAR(500),
    website VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Airports
CREATE TABLE airports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    iata_code VARCHAR(3) UNIQUE NOT NULL,
    icao_code VARCHAR(4) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    country VARCHAR(3) NOT NULL,
    timezone VARCHAR(50) NOT NULL,
    latitude DECIMAL(10, 6),
    longitude DECIMAL(10, 6),
    elevation INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Aircraft types
CREATE TABLE aircraft_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    iata_code VARCHAR(3) UNIQUE NOT NULL,
    icao_code VARCHAR(4) UNIQUE NOT NULL,
    manufacturer VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    capacity JSONB NOT NULL, -- {"economy": 150, "business": 30, "first": 8}
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Routes
CREATE TABLE routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    origin_airport_id UUID REFERENCES airports(id),
    destination_airport_id UUID REFERENCES airports(id),
    distance_km INTEGER,
    duration_minutes INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(origin_airport_id, destination_airport_id)
);

-- Flights (master schedule)
CREATE TABLE flights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flight_number VARCHAR(10) NOT NULL,
    airline_id UUID REFERENCES airlines(id),
    route_id UUID REFERENCES routes(id),
    aircraft_type_id UUID REFERENCES aircraft_types(id),
    departure_time TIME NOT NULL,
    arrival_time TIME NOT NULL,
    days_of_week INTEGER[], -- [1,2,3,4,5] for Mon-Fri
    effective_from DATE NOT NULL,
    effective_until DATE,
    status VARCHAR(20) DEFAULT 'active', -- active, cancelled, suspended
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Flight instances (actual flight occurrences)
CREATE TABLE flight_instances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flight_id UUID REFERENCES flights(id),
    departure_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    arrival_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_departure TIMESTAMP WITH TIME ZONE,
    actual_arrival TIMESTAMP WITH TIME ZONE,
    gate VARCHAR(10),
    terminal VARCHAR(10),
    status VARCHAR(20) DEFAULT 'scheduled', -- scheduled, delayed, cancelled, boarding, departed, arrived
    delay_minutes INTEGER DEFAULT 0,
    cancellation_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_flights_airline ON flights(airline_id);
CREATE INDEX idx_flights_route ON flights(route_id);
CREATE INDEX idx_flight_instances_flight ON flight_instances(flight_id);
CREATE INDEX idx_flight_instances_departure ON flight_instances(departure_datetime);
CREATE INDEX idx_airports_iata ON airports(iata_code);
CREATE INDEX idx_airlines_iata ON airlines(iata_code);
```

### Inventory Service Schema (PostgreSQL)

```sql
-- Seat configurations
CREATE TABLE seat_configurations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aircraft_type_id UUID REFERENCES aircraft_types(id),
    class VARCHAR(20) NOT NULL, -- economy, premium_economy, business, first
    row_number INTEGER NOT NULL,
    seat_letter VARCHAR(2) NOT NULL,
    seat_type VARCHAR(20), -- window, aisle, middle
    features JSONB, -- {"extra_legroom": true, "power_outlet": true}
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(aircraft_type_id, row_number, seat_letter)
);

-- Pricing rules
CREATE TABLE pricing_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flight_id UUID REFERENCES flights(id),
    class VARCHAR(20) NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    rules JSONB NOT NULL, -- Dynamic pricing rules
    effective_from DATE NOT NULL,
    effective_until DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Inventory (seat availability)
CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flight_instance_id UUID REFERENCES flight_instances(id),
    class VARCHAR(20) NOT NULL,
    total_seats INTEGER NOT NULL,
    available_seats INTEGER NOT NULL,
    reserved_seats INTEGER DEFAULT 0,
    blocked_seats INTEGER DEFAULT 0,
    price DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(flight_instance_id, class)
);

-- Seat reservations
CREATE TABLE seat_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flight_instance_id UUID REFERENCES flight_instances(id),
    seat_configuration_id UUID REFERENCES seat_configurations(id),
    booking_id UUID, -- Will reference booking service
    passenger_name VARCHAR(255),
    status VARCHAR(20) DEFAULT 'reserved', -- reserved, occupied, blocked
    reserved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(flight_instance_id, seat_configuration_id)
);

-- Indexes
CREATE INDEX idx_inventory_flight_instance ON inventory(flight_instance_id);
CREATE INDEX idx_seat_reservations_flight ON seat_reservations(flight_instance_id);
CREATE INDEX idx_seat_reservations_booking ON seat_reservations(booking_id);
```

### Booking Service Schema (PostgreSQL)

```sql
-- Bookings
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- References user service
    booking_reference VARCHAR(6) UNIQUE NOT NULL, -- PNR
    status VARCHAR(20) DEFAULT 'pending', -- pending, confirmed, cancelled, completed
    total_amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'pending', -- pending, paid, failed, refunded
    booking_source VARCHAR(50) DEFAULT 'web', -- web, mobile, api, agent
    contact_email VARCHAR(255) NOT NULL,
    contact_phone VARCHAR(20),
    special_requests TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Booking segments (flight legs)
CREATE TABLE booking_segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    flight_instance_id UUID NOT NULL, -- References flight service
    segment_order INTEGER NOT NULL, -- For multi-leg journeys
    departure_airport VARCHAR(3) NOT NULL,
    arrival_airport VARCHAR(3) NOT NULL,
    departure_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    arrival_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    class VARCHAR(20) NOT NULL,
    fare_basis VARCHAR(20),
    price DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    baggage_allowance JSONB,
    status VARCHAR(20) DEFAULT 'confirmed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Passengers
CREATE TABLE passengers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    passenger_type VARCHAR(20) DEFAULT 'adult', -- adult, child, infant
    title VARCHAR(10),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(10),
    nationality VARCHAR(3),
    passport_number VARCHAR(50),
    passport_expiry DATE,
    passport_country VARCHAR(3),
    known_traveler_number VARCHAR(50),
    seat_preference VARCHAR(20), -- window, aisle, middle
    meal_preference VARCHAR(50),
    special_needs TEXT,
    frequent_flyer_number VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Passenger segments (seat assignments)
CREATE TABLE passenger_segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    passenger_id UUID REFERENCES passengers(id) ON DELETE CASCADE,
    booking_segment_id UUID REFERENCES booking_segments(id) ON DELETE CASCADE,
    seat_number VARCHAR(5), -- e.g., "12A"
    boarding_pass_issued BOOLEAN DEFAULT false,
    check_in_time TIMESTAMP WITH TIME ZONE,
    boarding_group VARCHAR(5),
    gate VARCHAR(10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(passenger_id, booking_segment_id)
);

-- Booking history (audit trail)
CREATE TABLE booking_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id),
    action VARCHAR(50) NOT NULL, -- created, modified, cancelled, confirmed
    changed_by UUID, -- User ID or system
    changes JSONB, -- What changed
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_bookings_user ON bookings(user_id);
CREATE INDEX idx_bookings_reference ON bookings(booking_reference);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_booking_segments_booking ON booking_segments(booking_id);
CREATE INDEX idx_passengers_booking ON passengers(booking_id);
CREATE INDEX idx_booking_history_booking ON booking_history(booking_id);
```

### Payment Service Schema (PostgreSQL)

```sql
-- Payment methods
CREATE TABLE payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- References user service
    type VARCHAR(20) NOT NULL, -- credit_card, debit_card, paypal, bank_transfer
    card_last_four VARCHAR(4),
    card_brand VARCHAR(20), -- visa, mastercard, amex
    card_expiry_month INTEGER,
    card_expiry_year INTEGER,
    billing_address JSONB,
    is_default BOOLEAN DEFAULT false,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Transactions
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL, -- References booking service
    user_id UUID NOT NULL, -- References user service
    payment_method_id UUID REFERENCES payment_methods(id),
    transaction_type VARCHAR(20) NOT NULL, -- payment, refund, cancellation_fee
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    exchange_rate DECIMAL(10, 6), -- If currency conversion applied
    original_amount DECIMAL(10, 2),
    original_currency VARCHAR(3),
    gateway VARCHAR(50) NOT NULL, -- stripe, paypal, square
    gateway_transaction_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending', -- pending, processing, completed, failed, cancelled
    failure_reason TEXT,
    processing_fee DECIMAL(10, 2) DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Refunds
CREATE TABLE refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_transaction_id UUID REFERENCES transactions(id),
    refund_amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    refund_reason VARCHAR(50) NOT NULL, -- cancellation, change_fee, service_failure
    refund_type VARCHAR(20) DEFAULT 'automatic', -- automatic, manual, partial
    gateway_refund_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending', -- pending, processing, completed, failed
    processed_by UUID, -- Admin user ID for manual refunds
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX idx_transactions_booking ON transactions(booking_id);
CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_refunds_transaction ON refunds(original_transaction_id);
```

## 🔍 Database Optimization Strategy

### Indexing Strategy

#### Primary Indexes
```sql
-- High-cardinality columns used in WHERE clauses
CREATE INDEX CONCURRENTLY idx_bookings_user_status ON bookings(user_id, status);
CREATE INDEX CONCURRENTLY idx_flight_instances_route_date ON flight_instances(route_id, departure_datetime);
CREATE INDEX CONCURRENTLY idx_inventory_flight_class ON inventory(flight_instance_id, class);
```

#### Composite Indexes
```sql
-- Multi-column queries
CREATE INDEX CONCURRENTLY idx_flights_search ON flights(origin_airport_id, destination_airport_id, departure_date);
CREATE INDEX CONCURRENTLY idx_bookings_user_date ON bookings(user_id, created_at DESC);
```

#### Partial Indexes
```sql
-- Only index active records
CREATE INDEX CONCURRENTLY idx_active_flights ON flights(id) WHERE status = 'active';
CREATE INDEX CONCURRENTLY idx_pending_bookings ON bookings(id) WHERE status = 'pending';
```

### Partitioning Strategy

#### Time-based Partitioning
```sql
-- Partition large tables by date
CREATE TABLE bookings_2024 PARTITION OF bookings
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
    
CREATE TABLE flight_instances_2024_q1 PARTITION OF flight_instances
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
```

#### Hash Partitioning
```sql
-- Distribute users across partitions
CREATE TABLE users_0 PARTITION OF users
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
```

### Query Optimization

#### Search Optimization
```sql
-- Flight search with proper indexes
EXPLAIN (ANALYZE, BUFFERS) 
SELECT fi.*, f.flight_number, a1.name as origin, a2.name as destination
FROM flight_instances fi
JOIN flights f ON fi.flight_id = f.id
JOIN routes r ON f.route_id = r.id
JOIN airports a1 ON r.origin_airport_id = a1.id
JOIN airports a2 ON r.destination_airport_id = a2.id
WHERE r.origin_airport_id = $1 
  AND r.destination_airport_id = $2
  AND fi.departure_datetime::date = $3
  AND fi.status = 'scheduled';
```

## 📊 Data Modeling Best Practices

### Normalization
- **3NF compliance** for transactional data
- **Denormalization** for read-heavy operations
- **JSONB** for flexible, semi-structured data

### Data Types
```sql
-- Use appropriate data types
id UUID PRIMARY KEY DEFAULT gen_random_uuid() -- Better than SERIAL
amount DECIMAL(10, 2) NOT NULL -- For currency, not FLOAT
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() -- Always with timezone
status VARCHAR(20) CHECK (status IN ('active', 'inactive')) -- Constrained values
```

### Constraints
```sql
-- Business rule enforcement at DB level
ALTER TABLE bookings ADD CONSTRAINT valid_booking_dates 
    CHECK (expires_at > created_at);
    
ALTER TABLE passengers ADD CONSTRAINT valid_passenger_age 
    CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '14 days');
```

## 🚀 Scalability Considerations

### Read Replicas
```sql
-- Configure read replicas for read-heavy services
-- Flight Service: 3 read replicas (search operations)
-- User Service: 2 read replicas (authentication)
-- Booking Service: 2 read replicas (booking history)
```

### Connection Pooling
```javascript
// Connection pool configuration
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20, // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### Caching Strategy
```javascript
// Redis caching for frequently accessed data
const cacheKeys = {
  flightSearch: (origin, destination, date) => 
    `flight_search:${origin}:${destination}:${date}`,
  userProfile: (userId) => `user:${userId}`,
  flightDetails: (flightId) => `flight:${flightId}`,
  inventory: (flightInstanceId) => `inventory:${flightInstanceId}`
};
```

## 🔒 Data Security & Compliance

### Encryption
```sql
-- Encrypt sensitive columns
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Store encrypted payment data
UPDATE payment_methods 
SET card_number = pgp_sym_encrypt(card_number, 'encryption_key')
WHERE id = $1;
```

### Data Retention
```sql
-- Automated data archival
CREATE OR REPLACE FUNCTION archive_old_bookings()
RETURNS void AS $$
BEGIN
    -- Move bookings older than 7 years to archive table
    INSERT INTO bookings_archive 
    SELECT * FROM bookings 
    WHERE created_at < NOW() - INTERVAL '7 years';
    
    DELETE FROM bookings 
    WHERE created_at < NOW() - INTERVAL '7 years';
END;
$$ LANGUAGE plpgsql;
```

### GDPR Compliance
```sql
-- User data deletion for GDPR compliance
CREATE OR REPLACE FUNCTION anonymize_user_data(user_uuid UUID)
RETURNS void AS $$
BEGIN
    UPDATE users SET
        email = 'deleted_' || user_uuid || '@example.com',
        first_name = 'DELETED',
        last_name = 'USER',
        phone = NULL,
        passport_number = NULL
    WHERE id = user_uuid;
END;
$$ LANGUAGE plpgsql;
```

This database design provides a solid foundation for the Flight Booking System with proper normalization, indexing, partitioning, and security measures to ensure scalability and performance.