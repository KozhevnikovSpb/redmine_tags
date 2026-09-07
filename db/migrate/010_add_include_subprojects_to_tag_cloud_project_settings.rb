# frozen_string_literal: true

class AddIncludeSubprojectsToTagCloudProjectSettings < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:tag_cloud_project_settings)
    return if column_exists?(:tag_cloud_project_settings, :include_subprojects)

    add_column :tag_cloud_project_settings, :include_subprojects, :boolean, null: false, default: false
  end

  def down
    return unless table_exists?(:tag_cloud_project_settings)
    return unless column_exists?(:tag_cloud_project_settings, :include_subprojects)

    remove_column :tag_cloud_project_settings, :include_subprojects
  end
end
