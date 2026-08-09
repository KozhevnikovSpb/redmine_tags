# frozen_string_literal: true

# Plugin directory on server: plugins/redmineup_tags (plugin id :redmineup_tags)

def redmineup_tags_plugin_root
  begin
    return Redmine::Plugin.find(:redmineup_tags).directory
  rescue StandardError
    nil
  end
  candidates = [
    File.expand_path('../..', __dir__), # lib/tasks -> plugin root
    Rails.root.join('plugins/redmineup_tags').to_s,
    Rails.root.join('plugins/redmine_tags').to_s
  ]
  candidates.find { |p| File.directory?(p) }
end

def redmineup_tags_load_schema_repair!
  return if defined?(RedmineupTags::SchemaRepair)

  root = redmineup_tags_plugin_root
  path = root && File.join(root, 'lib/redmineup_tags/schema_repair.rb')

  unless path && File.file?(path)
    raise <<~MSG
      RedmineupTags::SchemaRepair not found.
      Expected file: plugins/redmineup_tags/lib/redmineup_tags/schema_repair.rb
      Plugin root tried: #{root.inspect}
      Run: git pull in the plugin directory, then retry.
    MSG
  end

  load path
  raise 'SchemaRepair loaded but constant missing' unless defined?(RedmineupTags::SchemaRepair)
end

def redmineup_tags_schema_status!
  conn = ActiveRecord::Base.connection
  puts '=== Multi Tag Clouds schema status ==='
  %w[tag_clouds tag_cloud_projects tag_cloud_tags tag_cloud_roles tag_cloud_preferences tags taggings].each do |t|
    puts format('  %-24s %s', t, conn.table_exists?(t) ? 'exists' : 'MISSING')
  end
  if conn.table_exists?(:tag_clouds)
    cols = conn.columns(:tag_clouds).map(&:name)
    puts "  tag_clouds columns: #{cols.join(', ')}"
    legacy = %w[project_id position is_system] & cols
    missing = %w[tag_filter include_subprojects owner_id visibility name visible_by_default] - cols
    puts "  legacy still present: #{legacy.empty? ? 'none' : legacy.join(', ')}"
    puts "  target missing: #{missing.empty? ? 'none' : missing.join(', ')}"
  end
  if conn.table_exists?(:tag_cloud_preferences)
    cols = conn.columns(:tag_cloud_preferences).map(&:name)
    puts "  preferences columns: #{cols.join(', ')}"
  end
end

namespace :redmineup_tags do
  desc 'Bring Multi Tag Clouds DB to target schema (idempotent)'
  task repair_schema: :environment do
    redmineup_tags_load_schema_repair!
    RedmineupTags::SchemaRepair.run!(verbose: true)
  end

  desc 'Print Multi Tag Clouds schema status (no changes)'
  task schema_status: :environment do
    redmineup_tags_schema_status!
  end
end

namespace :redmine_tags do
  desc 'Alias: same as redmineup_tags:repair_schema'
  task repair_schema: :environment do
    redmineup_tags_load_schema_repair!
    RedmineupTags::SchemaRepair.run!(verbose: true)
  end

  desc 'Alias: same as redmineup_tags:schema_status'
  task schema_status: :environment do
    redmineup_tags_schema_status!
  end
end
