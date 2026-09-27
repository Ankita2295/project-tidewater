-- 0007: baseline schema currently running in prod (v1.7 / v1.8-pre).
-- Kept as-is; this is the "known good" state referenced by 0008a/0008b.

CREATE TABLE IF NOT EXISTS settlements (
    id              BIGSERIAL PRIMARY KEY,
    merchant_id     BIGINT NOT NULL,
    amount_cents    BIGINT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_settlements_merchant ON settlements (merchant_id);
