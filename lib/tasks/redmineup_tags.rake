# frozen_string_literal: true

# Plugin id is :redmineup_tags — tasks under redmineup_tags:*
# Aliases under redmine_tags:* kept for convenience.

def redmineup_tags_load_schema_repair!
  return if defined?(RedmineupTags::SchemaRepair)

  paths = []
  begin
    paths << File.join(Redmine::Plugin.find(:redmineup_tags).directory, 'lib/redmineup_tags/schema_repair.rb')
  rescue StandardError
    nil
  end
  paths << File.expand_path('../redmineup_tags/schema_repair.rb', __dir__)
  paths << Rails.root.join('plugins/redmineup_tags/lib/redmineup_tags/schema_repair.rb').to_s
  paths << Rails.root.join('plugins/redmine_tags/lib/redmineup_tags/schema_repair.rb').to_s

  paths.each do |path|
    next unless path && File.file?(path)

    load path
    break if defined?(RedmineupTags::SchemaRepair)
  end

  raise 'RedmineupTags::SchemaRepair not found — pull latest plugin code' unless defined?(RedmineupTags::SchemaRepair)
end

namespace :redmineup_tags do
  desc 'Check Multi Tag Clouds tables and bring DB to target schema (idempotent)'
  task repair_schema: :environment do
    redmineup_tags_load_schema_repair!
    RedmineupTags::SchemaRepair.run!(verbose: true)
  end

  desc 'Print Multi Tag Clouds schema status only (no changes)'
  task schema_status: :environment do
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
end

# Aliases
namespace :redmine_tags do
  task repair_schema: 'redmineup_tags:repair_schema'
  task schema_status: 'redmineup_tags:schema_status'
end
