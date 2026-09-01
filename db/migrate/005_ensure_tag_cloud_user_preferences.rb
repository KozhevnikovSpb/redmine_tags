# frozen_string_literal: true

# Idempotent. Creates tag_cloud_user_preferences if 004 was skipped or swallowed.
class EnsureTagCloudUserPreferences < ActiveRecord::Migration[7.0]
  def up
    return if table_exists?(:tag_cloud_user_preferences)

    adapter = connection.adapter_name.to_s.downcase
    if adapter.include?('postgres')
      execute(<<~SQL.squish)
        CREATE TABLE tag_cloud_user_preferences (
          id BIGSERIAL PRIMARY KEY,
          user_id BIGINT NOT NULL,
          show_count BOOLEAN NULL,
          show_weight BOOLEAN NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      SQL
      execute(<<~SQL.squish)
        CREATE UNIQUE INDEX index_tag_cloud_user_preferences_on_user_id
          ON tag_cloud_user_preferences (user_id)
      SQL
    else
      execute(<<~SQL.squish)
        CREATE TABLE tag_cloud_user_preferences (
          id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          user_id BIGINT NOT NULL,
          show_count TINYINT(1) NULL,
          show_weight TINYINT(1) NULL,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          UNIQUE KEY index_tag_cloud_user_preferences_on_user_id (user_id)
        )
      SQL
    end
  end

  def down
    drop_table :tag_cloud_user_preferences if table_exists?(:tag_cloud_user_preferences)
  end
end
