# frozen_string_literal: true

class AddShowUntaggedToTagCloudUserPreferences < ActiveRecord::Migration[7.0]
  def up
    return unless table_exists?(:tag_cloud_user_preferences)
    return if column_exists?(:tag_cloud_user_preferences, :show_untagged)

    add_column :tag_cloud_user_preferences, :show_untagged, :boolean
  end

  def down
    return unless column_exists?(:tag_cloud_user_preferences, :show_untagged)

    remove_column :tag_cloud_user_preferences, :show_untagged
  end
end
