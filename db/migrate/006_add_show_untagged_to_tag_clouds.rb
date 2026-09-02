# frozen_string_literal: true

class AddShowUntaggedToTagClouds < ActiveRecord::Migration[7.0]
  def up
    return unless table_exists?(:tag_clouds)
    return if column_exists?(:tag_clouds, :show_untagged)

    add_column :tag_clouds, :show_untagged, :boolean, default: false, null: false
  end

  def down
    remove_column :tag_clouds, :show_untagged if column_exists?(:tag_clouds, :show_untagged)
  end
end
