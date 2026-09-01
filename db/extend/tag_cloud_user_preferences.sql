-- Personal tag display prefs (count / weight).
-- Independent from tag_cloud_preferences (sidebar visibility).
-- Safe to run multiple times.

CREATE TABLE IF NOT EXISTS tag_cloud_user_preferences (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  show_count TINYINT(1) NULL,
  show_weight TINYINT(1) NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  UNIQUE KEY index_tag_cloud_user_preferences_on_user_id (user_id)
);
