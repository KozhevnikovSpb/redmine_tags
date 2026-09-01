# frozen_string_literal: true

class CreateTagCloudUserPreferences < ActiveRecord::Migration[7.0]
  def up
    return if table_exists?(:tag_cloud_user_preferences)

    create_table :tag_cloud_user_preferences do |t|
      t.bigint :user_id, null: false
      t.boolean :show_count
      t.boolean :show_weight
      t.timestamps
    end
    add_index :tag_cloud_user_preferences, :user_id,
              unique: true, name: 'index_tag_cloud_user_preferences_on_user_id'
    add_foreign_key :tag_cloud_user_preferences, :users, column: :user_id, on_delete: :cascade
  rescue StandardError => e
    say "WARNING: tag_cloud_user_preferences: #{e.class}: #{e.message}"
  end

  def down
    drop_table :tag_cloud_user_preferences if table_exists?(:tag_cloud_user_preferences)
  end
end
