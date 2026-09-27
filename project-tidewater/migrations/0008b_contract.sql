-- 0008b (CONTRACT) — only run this once v1.8 has been the sole running
-- version for a full deploy cycle (no v1.7 pods left, no rollback to
-- v1.7 planned). This is what makes the old column safe to drop.
--
-- Release sequence (see docs/DECISIONS.md ADR-002 for the full table):
--   1. Run 0008a_expand.sql              (additive, zero downtime)
--   2. Deploy v1.8 (dual-write, reads old column)   <- rollback-safe to v1.7
--   3. Once v1.8 confirmed stable, deploy v1.8.1 (reads NEW column)
--   4. Run 0008b_contract.sql            (drops old column)
--
-- A rollback at any point before step 4 needs ZERO down-migration,
-- because the old column never went away until this file runs.

ALTER TABLE settlements ALTER COLUMN amount SET NOT NULL;
ALTER TABLE settlements DROP COLUMN amount_cents;
