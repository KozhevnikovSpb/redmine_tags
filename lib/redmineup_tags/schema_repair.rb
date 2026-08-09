# frozen_string_literal: true

module RedmineupTags
  # V.0.0.2-beta schema installer / normalizer.
  #
  # - Fresh install: create target tables
  # - Existing install: DROP our cloud tables and recreate (force)
  # - ALWAYS preserve tags + taggings (real RedmineUP tags data)
  #
  # Usage:
  #   RedmineupTags::SchemaRepair.run!(verbose: true)           # soft ensure + reshape
  #   RedmineupTags::SchemaRepair.force_rebuild!(verbose: true) # wipe clouds, keep tags
  class SchemaRepair
    OUR_TABLES = %w[
      tag_cloud_preferences
      tag_cloud_roles
      tag_cloud_tags
      tag_cloud_projects
      tag_clouds
    ].freeze

    PRESERVE_TABLES = %w[tags taggings].freeze

    class << self
      def run!(verbose: true)
        new(verbose: verbose).run!
      end

      def force_rebuild!(verbose: true)
        new(verbose: verbose).force_rebuild!
      end

      def status!(verbose: true)
        new(verbose: verbose).report_status
      end
    end

    def initialize(verbose: true)
      @verbose = verbose
      @connection = ActiveRecord::Base.connection
    end

    # Soft path: ensure missing pieces, migrate legacy if present, drop legacy cols
    def run!
      log '=== SchemaRepair (soft) start ==='
      ensure_tags_tables
      if legacy_cloud_schema?
        log 'Legacy cloud schema detected → force rebuild (tags preserved)'
        force_rebuild!
      else
        ensure_target_schema
        report_status
      end
      log '=== SchemaRepair (soft) finished ==='
      true
    end

    # Hard path for V.0.0.2-beta: wipe our tables, recreate target, keep tags
    def force_rebuild!
      log '=== SchemaRepair FORCE REBUILD (V.0.0.2-beta) ==='
      log 'Preserved: tags, taggings'
      log "Will drop/recreate: #{OUR_TABLES.join(', ')}"

      ensure_tags_tables
      drop_our_tables!
      create_target_schema!
      report_status
      log '=== FORCE REBUILD finished ==='
      true
    end

    def report_status
      log '--- status ---'
      (OUR_TABLES.reverse + PRESERVE_TABLES).each do |t|
        log "  #{t}: #{table?(t) ? 'OK' : 'MISSING'}"
      end
      if table?(:tag_clouds)
        cols = @connection.columns(:tag_clouds).map(&:name)
        legacy = (%w[project_id position is_system] & cols)
        needed = (%w[tag_filter include_subprojects owner_id visibility name visible_by_default] - cols)
        log "  tag_clouds columns: #{cols.join(', ')}"
        log "  tag_clouds legacy left: #{legacy.empty? ? 'none' : legacy.join(', ')}"
        log "  tag_clouds missing: #{needed.empty? ? 'none' : needed.join(', ')}"
      end
      if table?(:tag_cloud_preferences)
        cols = @connection.columns(:tag_cloud_preferences).map(&:name)
        log "  preferences columns: #{cols.join(', ')}"
      end
      if table?(:tags)
        log "  tags count: #{safe_count('tags')}"
      end
      if table?(:taggings)
        log "  taggings count: #{safe_count('taggings')}"
      end
    end

    private

    def log(msg)
      puts msg if @verbose
      Rails.logger.info("[SchemaRepair] #{msg}") if defined?(Rails) && Rails.logger
    end

    def table?(name)
      @connection.table_exists?(name)
    end

    def column?(table, name)
      table?(table) && @connection.column_exists?(table, name)
    end

    def index?(table, columns = nil, **opts)
      return false unless table?(table)

      @connection.index_exists?(table, columns, **opts)
    rescue StandardError
      false
    end

    def fk?(from_table, to_table = nil, column: nil)
      return false unless table?(from_table)

      if column
        @connection.foreign_key_exists?(from_table, column: column)
      else
        @connection.foreign_key_exists?(from_table, to_table)
      end
    rescue StandardError
      false
    end

    def safe_count(table)
      @connection.select_value("SELECT COUNT(*) FROM #{@connection.quote_table_name(table)}").to_i
    rescue StandardError
      -1
    end

    def legacy_cloud_schema?
      return false unless table?(:tag_clouds)

      column?(:tag_clouds, :project_id) ||
        column?(:tag_clouds, :is_system) ||
        (column?(:tag_clouds, :position) && !table?(:tag_cloud_projects))
    end

    def ensure_tags_tables
      log 'ensure tags/taggings (preserved if already present)...'
      if ActiveRecord::Base.respond_to?(:create_taggable_table)
        ActiveRecord::Base.create_taggable_table
      else
        log 'WARNING: create_taggable_table missing — tags may be incomplete'
      end
    end

    def drop_our_tables!
      # Order: children first (FK)
      OUR_TABLES.each do |t|
        next unless table?(t)

        log "DROP TABLE #{t}"
        @connection.drop_table t, force: :cascade
      end
    end

    def ensure_target_schema
      create_target_schema! unless table?(:tag_clouds) && table?(:tag_cloud_projects)
      # If tables exist but columns missing — still force for beta consistency
      if table?(:tag_clouds) && (!column?(:tag_clouds, :tag_filter) || !column?(:tag_clouds, :visibility))
        log 'Target columns incomplete → force rebuild'
        force_rebuild!
      end
    end

    def create_target_schema!
      log 'CREATE target schema'

      unless table?(:tag_clouds)
        @connection.create_table :tag_clouds do |t|
          t.string  :name, null: false
          t.text    :status_filter
          t.text    :version_filter
          t.text    :tracker_filter
          t.boolean :tag_filter, null: false, default: false
          t.boolean :include_subprojects, null: false, default: false
          t.boolean :visible_by_default, null: false, default: true
          t.bigint  :owner_id
          t.string  :visibility, null: false, default: 'all'
          t.bigint  :created_by_id
          t.timestamps
        end
        @connection.add_index :tag_clouds, :owner_id
        @connection.add_index :tag_clouds, :created_by_id
        @connection.add_index :tag_clouds, :visibility
        add_fk_safe :tag_clouds, :users, column: :owner_id, on_delete: :nullify
        add_fk_safe :tag_clouds, :users, column: :created_by_id, on_delete: :nullify
      end

      unless table?(:tag_cloud_projects)
        @connection.create_table :tag_cloud_projects do |t|
          t.bigint  :tag_cloud_id, null: false
          t.bigint  :project_id, null: false
          t.integer :position, null: false, default: 0
        end
        @connection.add_index :tag_cloud_projects, %i[tag_cloud_id project_id],
                              unique: true, name: 'index_tag_cloud_projects_unique'
        @connection.add_index :tag_cloud_projects, %i[project_id position],
                              name: 'index_tag_cloud_projects_on_project_position'
        add_fk_safe :tag_cloud_projects, :tag_clouds, column: :tag_cloud_id, on_delete: :cascade
        add_fk_safe :tag_cloud_projects, :projects, column: :project_id, on_delete: :cascade
      end

      unless table?(:tag_cloud_tags)
        @connection.create_table :tag_cloud_tags do |t|
          t.bigint  :tag_cloud_id, null: false
          t.integer :tag_id, null: false
        end
        @connection.add_index :tag_cloud_tags, %i[tag_cloud_id tag_id],
                              unique: true, name: 'index_tag_cloud_tags_unique'
        @connection.add_index :tag_cloud_tags, :tag_id
        add_fk_safe :tag_cloud_tags, :tag_clouds, column: :tag_cloud_id, on_delete: :cascade
      end

      unless table?(:tag_cloud_roles)
        @connection.create_table :tag_cloud_roles do |t|
          t.bigint :tag_cloud_id, null: false
          t.bigint :role_id, null: false
        end
        @connection.add_index :tag_cloud_roles, %i[tag_cloud_id role_id],
                              unique: true, name: 'index_tag_cloud_roles_unique'
        add_fk_safe :tag_cloud_roles, :tag_clouds, column: :tag_cloud_id, on_delete: :cascade
        add_fk_safe :tag_cloud_roles, :roles, column: :role_id, on_delete: :cascade
      end

      unless table?(:tag_cloud_preferences)
        @connection.create_table :tag_cloud_preferences do |t|
          t.bigint  :tag_cloud_id, null: false
          t.bigint  :user_id, null: false
          t.boolean :visible, null: false, default: true
          t.integer :position
          t.timestamps
        end
        @connection.add_index :tag_cloud_preferences, %i[tag_cloud_id user_id],
                              unique: true, name: 'index_tag_cloud_preferences_unique'
        @connection.add_index :tag_cloud_preferences, :user_id
        add_fk_safe :tag_cloud_preferences, :tag_clouds, column: :tag_cloud_id, on_delete: :cascade
        add_fk_safe :tag_cloud_preferences, :users, column: :user_id, on_delete: :cascade
      end
    end

    def add_fk_safe(from_table, to_table, column:, on_delete: :cascade)
      return if fk?(from_table, column: column)

      @connection.add_foreign_key from_table, to_table, column: column, on_delete: on_delete
    rescue StandardError => e
      log "WARNING: FK #{from_table}.#{column} → #{to_table}: #{e.message}"
    end
  end
end
