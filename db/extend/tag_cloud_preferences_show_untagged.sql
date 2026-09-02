-- Safe to run multiple times (MySQL).
ALTER TABLE tag_cloud_preferences
  ADD COLUMN IF NOT EXISTS show_untagged TINYINT(1) NOT NULL DEFAULT 0;
