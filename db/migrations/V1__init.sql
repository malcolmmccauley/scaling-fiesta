CREATE SCHEMA IF NOT EXISTS malco_public;

CREATE USER malco_public WITH CONNECTION LIMIT 10;

GRANT USAGE ON SCHEMA malco_public TO malco_public;
GRANT CREATE ON SCHEMA malco_public TO malco_public;

CREATE TABLE malco_public.purchases (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID          NOT NULL,
    item        TEXT          NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON malco_public.purchases TO malco_public;
