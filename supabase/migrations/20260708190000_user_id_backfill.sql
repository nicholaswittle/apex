-- User ID backfill: link shifts.staff name to profiles.user_id where possible.
-- Run on staging first. Safe to re-run (updates only where user_id IS NULL).

-- Add column if missing (idempotent for fresh installs)
ALTER TABLE shifts ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

CREATE INDEX IF NOT EXISTS idx_shifts_user_id ON shifts(user_id);
CREATE INDEX IF NOT EXISTS idx_shifts_shift_date ON shifts(shift_date);
CREATE INDEX IF NOT EXISTS idx_shifts_organization_id ON shifts(organization_id);

-- Backfill from profile name match within same organization
UPDATE shifts s
SET user_id = p.id
FROM profiles p
WHERE s.user_id IS NULL
  AND s.staff = p.name
  AND s.staff <> 'Open'
  AND s.organization_id = p.organization_id;

COMMENT ON COLUMN shifts.user_id IS 'Resolved staff user; staff column retained for display during migration';
