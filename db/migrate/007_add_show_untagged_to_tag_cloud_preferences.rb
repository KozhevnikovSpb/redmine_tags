# frozen_string_literal: true

class AddShowUntaggedToTagCloudPreferences < ActiveRecord::Migration[7.0]
  def up
    return unless table_exists?(:tag_cloud_preferences)
    return if column_exists?(:tag_cloud_preferences, :show_untagged)

    add_column :tag_cloud_preferences, :show_untagged, :boolean, default: false, null: false
  end

  def down
    return unless column_exists?(:tag_cloud_preferences, :show_untagged)

    remove_column :tag_cloud_preferences, :show_untagged
  end
end
