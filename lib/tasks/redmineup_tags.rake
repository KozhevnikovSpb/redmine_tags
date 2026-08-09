# frozen_string_literal: true

# Plugin directory: plugins/redmineup_tags (id :redmineup_tags)

def redmineup_tags_plugin_root
  begin
    return Redmine::Plugin.find(:redmineup_tags).directory
  rescue StandardError
    nil
  end
  [
    File.expand_path('../..', __dir__),
    Rails.root.join('plugins/redmineup_tags').to_s,
    Rails.root.join('plugins/redmine_tags').to_s
  ].find { |p| File.directory?(p) }
end

def redmineup_tags_load_schema_repair!
  return if defined?(RedmineupTags::SchemaRepair)

  root = redmineup_tags_plugin_root
  path = root && File.join(root, 'lib/redmineup_tags/schema_repair.rb')
  unless path && File.file?(path)
    raise "SchemaRepair not found at #{path.inspect}. git pull in plugin dir."
  end

  load path
  raise 'SchemaRepair constant missing after load' unless defined?(RedmineupTags::SchemaRepair)
end

namespace :redmineup_tags do
  desc 'V.0.0.2-beta: DROP cloud tables and recreate target schema. PRESERVES tags/taggings.'
  task force_rebuild: :environment do
    redmineup_tags_load_schema_repair!
    puts 'WARNING: tag_clouds / preferences / projects / roles / tags-links will be wiped.'
    puts 'PRESERVED: tags, taggings (real issue tags).'
    RedmineupTags::SchemaRepair.force_rebuild!(verbose: true)
  end

  desc 'Ensure schema (soft). If legacy detected → force rebuild.'
  task repair_schema: :environment do
    redmineup_tags_load_schema_repair!
    RedmineupTags::SchemaRepair.run!(verbose: true)
  end

  desc 'Print schema status (no changes)'
  task schema_status: :environment do
    redmineup_tags_load_schema_repair!
    RedmineupTags::SchemaRepair.status!(verbose: true)
  end
end

namespace :redmine_tags do
  task force_rebuild: :environment do
    redmineup_tags_load_schema_repair!
    RedmineupTags::SchemaRepair.force_rebuild!(verbose: true)
  end
  task repair_schema: :environment do
    redmineup_tags_load_schema_repair!
    RedmineupTags::SchemaRepair.run!(verbose: true)
  end
  task schema_status: :environment do
    redmineup_tags_load_schema_repair!
    RedmineupTags::SchemaRepair.status!(verbose: true)
  end
end
