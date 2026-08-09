# frozen_string_literal: true

module RedmineupTags
  # Brings Multi Tag Clouds tables to target schema regardless of migration history.
  # Usage: RedmineupTags::SchemaRepair.run!(verbose: true)
  class SchemaRepair
    class << self
      def run!(verbose: true)
        new(verbose: verbose).run!
      end
    end

    def initialize(verbose: true)
      @verbose = verbose
      @connection = ActiveRecord::Base.connection
    end

    def run!
      log '=== RedmineupTags::SchemaRepair start ==='
      ensure_tags_tables
      ensure_tag_clouds_table
      ensure_junction_tables
      ensure_preferences_table
      migrate_legacy_data
      ensure_target_columns
      remove_legacy_columns
      log '=== SchemaRepair finished ==='
      report_status
      true
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

    # --- ensure ---

    def ensure_tags_tables
      log 'ensure tags/taggings...'
      if defined?(ActiveRecord::Base) && ActiveRecord::Base.respond_to?(:create_taggable_table)
        ActiveRecord::Base.create_taggable_table
      else
        log 'WARNING: create_taggable_table not available (redmineup gem?)'
      end
    end

    def ensure_tag_clouds_table
      return if table?(:tag_clouds)

      log 'create tag_clouds (target shape)'
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
      @connection.add_index :tag_clouds, :owner_id unless index?(:tag_clouds, :owner_id)
      @connection.add_index :tag_clouds, :created_by_id unless index?(:tag_clouds, :created_by_id)
      @connection.add_index :tag_clouds, :visibility unless index?(:tag_clouds, :visibility)
      add_fk_safe :tag_clouds, :users, column: :owner_id, on_delete: :nullify
      add_fk_safe :tag_clouds, :users, column: :created_by_id, on_delete: :nullify
    end

    def ensure_junction_tables
      unless table?(:tag_cloud_projects)
        log 'create tag_cloud_projects'
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
        log 'create tag_cloud_tags'
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
        log 'create tag_cloud_roles'
        @connection.create_table :tag_cloud_roles do |t|
          t.bigint :tag_cloud_id, null: false
          t.bigint :role_id, null: false
        end
        @connection.add_index :tag_cloud_roles, %i[tag_cloud_id role_id],
                              unique: true, name: 'index_tag_cloud_roles_unique'
        add_fk_safe :tag_cloud_roles, :tag_clouds, column: :tag_cloud_id, on_delete: :cascade
        add_fk_safe :tag_cloud_roles, :roles, column: :role_id, on_delete: :cascade
      end
    end

    def ensure_preferences_table
      unless table?(:tag_cloud_preferences)
        log 'create tag_cloud_preferences'
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

    def migrate_legacy_data
      return unless table?(:tag_clouds)
      return unless column?(:tag_clouds, :project_id)

      log 'migrate legacy project_id → tag_cloud_projects'
      legacy_has_system = column?(:tag_clouds, :is_system)
      legacy_has_position = column?(:tag_clouds, :position)

      sql = if legacy_has_system
              'SELECT id, project_id, position FROM tag_clouds WHERE (is_system IS NULL OR is_system = FALSE) AND project_id IS NOT NULL'
            else
              'SELECT id, project_id' + (legacy_has_position ? ', position' : '') + ' FROM tag_clouds WHERE project_id IS NOT NULL'
            end

      # rebuild select if no position column in non-system branch without position in SQL above
      unless legacy_has_system
        cols = 'id, project_id'
        cols += ', position' if legacy_has_position
        sql = "SELECT #{cols} FROM tag_clouds WHERE project_id IS NOT NULL"
      end

      rows = @connection.select_all(sql)
      rows.each do |row|
        cloud_id = row['id']
        project_id = row['project_id']
        pos = legacy_has_position ? row['position'].to_i : 0
        exists = @connection.select_value(
          "SELECT 1 FROM tag_cloud_projects WHERE tag_cloud_id = #{cloud_id.to_i} AND project_id = #{project_id.to_i} LIMIT 1"
        )
        next if exists

        @connection.execute(<<~SQL.squish)
          INSERT INTO tag_cloud_projects (tag_cloud_id, project_id, position)
          VALUES (#{cloud_id.to_i}, #{project_id.to_i}, #{pos})
        SQL
      end
      log "  linked #{rows.length} cloud(s)"

      if legacy_has_system
        log 'remove system / Default Tags clouds'
        system_ids = @connection.select_values('SELECT id FROM tag_clouds WHERE is_system = TRUE').map(&:to_i)
        if system_ids.any?
          ids = system_ids.join(',')
          @connection.execute("DELETE FROM tag_cloud_preferences WHERE tag_cloud_id IN (#{ids})") if table?(:tag_cloud_preferences)
          @connection.execute("DELETE FROM tag_cloud_projects WHERE tag_cloud_id IN (#{ids})") if table?(:tag_cloud_projects)
          @connection.execute("DELETE FROM tag_cloud_tags WHERE tag_cloud_id IN (#{ids})") if table?(:tag_cloud_tags)
          @connection.execute("DELETE FROM tag_cloud_roles WHERE tag_cloud_id IN (#{ids})") if table?(:tag_cloud_roles)
          @connection.execute("DELETE FROM tag_clouds WHERE id IN (#{ids})")
          log "  deleted #{system_ids.length} system cloud(s)"
        end
      end
    end

    def ensure_target_columns
      return unless table?(:tag_clouds)

      unless column?(:tag_clouds, :tag_filter)
        log 'add tag_clouds.tag_filter'
        @connection.add_column :tag_clouds, :tag_filter, :boolean, null: false, default: false
      end
      unless column?(:tag_clouds, :include_subprojects)
        log 'add tag_clouds.include_subprojects'
        @connection.add_column :tag_clouds, :include_subprojects, :boolean, null: false, default: false
      end
      unless column?(:tag_clouds, :owner_id)
        log 'add tag_clouds.owner_id'
        @connection.add_column :tag_clouds, :owner_id, :bigint
        @connection.add_index :tag_clouds, :owner_id unless index?(:tag_clouds, :owner_id)
        add_fk_safe :tag_clouds, :users, column: :owner_id, on_delete: :nullify
      end
      unless column?(:tag_clouds, :visibility)
        log 'add tag_clouds.visibility'
        @connection.add_column :tag_clouds, :visibility, :string, null: false, default: 'all'
      end
      @connection.add_index :tag_clouds, :visibility unless index?(:tag_clouds, :visibility)

      unless column?(:tag_clouds, :visible_by_default)
        log 'add tag_clouds.visible_by_default'
        @connection.add_column :tag_clouds, :visible_by_default, :boolean, null: false, default: true
      end

      if table?(:tag_cloud_preferences) && !column?(:tag_cloud_preferences, :position)
        log 'add tag_cloud_preferences.position'
        @connection.add_column :tag_cloud_preferences, :position, :integer
      end
    end

    def remove_legacy_columns
      return unless table?(:tag_clouds)

      # indexes on legacy columns
      drop_index_safe :tag_clouds, %i[project_id name]
      drop_index_safe :tag_clouds, %i[project_id is_system]
      drop_index_safe :tag_clouds, %i[project_id position]
      drop_index_safe :tag_clouds, :project_id
      drop_index_by_name_safe :tag_clouds, 'index_tag_clouds_on_project_id_and_name'
      drop_index_by_name_safe :tag_clouds, 'index_tag_clouds_on_project_id_and_is_system'
      drop_index_by_name_safe :tag_clouds, 'index_tag_clouds_on_project_id_and_position'
      drop_index_by_name_safe :tag_clouds, 'index_tag_clouds_on_project_id'

      if fk?(:tag_clouds, :projects)
        log 'remove FK tag_clouds → projects'
        @connection.remove_foreign_key :tag_clouds, :projects
      end

      if column?(:tag_clouds, :project_id)
        log 'remove tag_clouds.project_id'
        @connection.remove_column :tag_clouds, :project_id
      end
      if column?(:tag_clouds, :position)
        log 'remove tag_clouds.position'
        @connection.remove_column :tag_clouds, :position
      end
      if column?(:tag_clouds, :is_system)
        log 'remove tag_clouds.is_system'
        @connection.remove_column :tag_clouds, :is_system
      end
    end

    def report_status
      log '--- status ---'
      %w[tag_clouds tag_cloud_projects tag_cloud_tags tag_cloud_roles tag_cloud_preferences tags taggings].each do |t|
        log "  #{t}: #{table?(t) ? 'OK' : 'MISSING'}"
      end
      if table?(:tag_clouds)
        cols = @connection.columns(:tag_clouds).map(&:name)
        legacy = (%w[project_id position is_system] & cols)
        needed = (%w[tag_filter include_subprojects owner_id visibility] - cols)
        log "  tag_clouds legacy left: #{legacy.empty? ? 'none' : legacy.join(', ')}"
        log "  tag_clouds missing: #{needed.empty? ? 'none' : needed.join(', ')}"
      end
    end

    def add_fk_safe(from_table, to_table, column:, on_delete: :cascade)
      return if fk?(from_table, column: column)

      @connection.add_foreign_key from_table, to_table, column: column, on_delete: on_delete
    rescue StandardError => e
      log "WARNING: FK #{from_table}.#{column} → #{to_table}: #{e.message}"
    end

    def drop_index_safe(table, columns)
      return unless index?(table, columns)

      @connection.remove_index table, columns
    rescue StandardError => e
      log "WARNING: drop index #{table} #{columns}: #{e.message}"
    end

    def drop_index_by_name_safe(table, name)
      return unless index?(table, name: name)

      @connection.remove_index table, name: name
    rescue StandardError => e
      log "WARNING: drop index #{name}: #{e.message}"
    end
  end
end
