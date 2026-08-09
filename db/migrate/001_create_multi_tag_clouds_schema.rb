# frozen_string_literal: true

# V.0.0.2-beta
# On plugin migrate: ensure tags/taggings, force rebuild cloud tables to target schema.
# Does NOT delete tags or taggings.

class CreateMultiTagCloudsSchema < ActiveRecord::Migration[7.0]
  def up
    plugin_root = begin
      Redmine::Plugin.find(:redmineup_tags).directory
    rescue StandardError
      File.expand_path('../..', __dir__)
    end
    repair_path = File.join(plugin_root, 'lib/redmineup_tags/schema_repair.rb')
    load repair_path if File.file?(repair_path) && !defined?(RedmineupTags::SchemaRepair)

    if defined?(RedmineupTags::SchemaRepair)
      # Existing installs: wipe cloud state, recreate; preserve tags
      if table_exists?(:tag_clouds) || table_exists?(:tag_cloud_preferences)
        RedmineupTags::SchemaRepair.force_rebuild!(verbose: true)
      else
        RedmineupTags::SchemaRepair.force_rebuild!(verbose: true)
      end
    else
      # Fallback without SchemaRepair constant
      ActiveRecord::Base.create_taggable_table if ActiveRecord::Base.respond_to?(:create_taggable_table)
      raise 'RedmineupTags::SchemaRepair missing — cannot install cloud schema'
    end
  end

  def down
    drop_table :tag_cloud_preferences if table_exists?(:tag_cloud_preferences)
    drop_table :tag_cloud_roles if table_exists?(:tag_cloud_roles)
    drop_table :tag_cloud_tags if table_exists?(:tag_cloud_tags)
    drop_table :tag_cloud_projects if table_exists?(:tag_cloud_projects)
    drop_table :tag_clouds if table_exists?(:tag_clouds)
    # tags / taggings never dropped
  end
end
