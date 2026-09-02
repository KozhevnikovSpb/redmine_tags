-- Personal master switch for untagged captions (My account).
-- Safe to run multiple times (MySQL 8+).
ALTER TABLE tag_cloud_user_preferences
  ADD COLUMN IF NOT EXISTS show_untagged TINYINT(1) NULL;
