# frozen_string_literal: true

class CreateTagCloudProjectSettings < ActiveRecord::Migration[7.2]
  def up
    return if table_exists?(:tag_cloud_project_settings)

    create_table :tag_cloud_project_settings do |t|
      t.bigint :project_id, null: false
      t.boolean :system_visible_by_default, null: false, default: true
      t.timestamps
    end
    add_index :tag_cloud_project_settings, :project_id,
              unique: true, name: 'index_tag_cloud_project_settings_on_project_id'
  end

  def down
    drop_table :tag_cloud_project_settings if table_exists?(:tag_cloud_project_settings)
  end
end
