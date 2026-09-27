-- 0008a (EXPAND) — additive only. Safe to run WHILE v1.7 is still live.
-- v1.7 code ignores the new column entirely; nothing about v1.7's
-- behaviour changes. v1.8 code is written to dual-write: it writes
-- BOTH `amount_cents` (old) and `amount` (new) on every insert/update,
-- and reads from `amount_cents` until 0008b ships.

ALTER TABLE settlements ADD COLUMN IF NOT EXISTS amount BIGINT;
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS settled_at TIMESTAMPTZ;

-- Backfill existing rows so `amount` is never NULL for old data.
UPDATE settlements SET amount = amount_cents WHERE amount IS NULL;

-- NOT VALID + separate VALIDATE avoids a long table-locking scan;
-- validation happens without blocking concurrent writes.
ALTER TABLE settlements
    ADD CONSTRAINT amount_not_null CHECK (amount IS NOT NULL) NOT VALID;
ALTER TABLE settlements VALIDATE CONSTRAINT amount_not_null;
