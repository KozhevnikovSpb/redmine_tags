# frozen_string_literal: true

namespace :redmine_tags do
  desc 'Check Multi Tag Clouds tables and bring DB to target schema (idempotent)'
  task repair_schema: :environment do
    require_dependency Rails.root.join('plugins/redmine_tags/lib/redmineup_tags/schema_repair').to_s rescue nil
    require_dependency File.expand_path('../redmineup_tags/schema_repair', __dir__) rescue nil

    unless defined?(RedmineupTags::SchemaRepair)
      # fallback load from plugin path
      plugin_path = Redmine::Plugin.find(:redmineup_tags).directory rescue nil
      plugin_path ||= File.expand_path('../..', __dir__)
      load File.join(plugin_path, 'lib/redmineup_tags/schema_repair.rb')
    end

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
