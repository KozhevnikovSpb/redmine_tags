# frozen_string_literal: true

# Idempotent migration for Multi Tag Clouds (Redmine 7 / Rails 8.1).
# Checks current DB state and brings schema to target:
# - tags/taggings via redmineup
# - tag_clouds without project_id / is_system / position
# - tag_cloud_projects, tag_cloud_tags, tag_cloud_roles, tag_cloud_preferences
# - no Default Tags / system clouds
#
# Safe to run on:
# - empty DB
# - old schema (project_id + is_system on tag_clouds)
# - already migrated target schema (no-op)

class CreateMultiTagCloudsSchema < ActiveRecord::Migration[7.0]
  class MigrationTagCloud < ActiveRecord::Base
    self.table_name = 'tag_clouds'
  end

  class MigrationTagCloudProject < ActiveRecord::Base
    self.table_name = 'tag_cloud_projects'
  end

  class MigrationTagCloudPreference < ActiveRecord::Base
    self.table_name = 'tag_cloud_preferences'
  end

  def up
    ensure_tags_tables
    ensure_tag_clouds_table
    ensure_tag_cloud_projects_table
    ensure_tag_cloud_tags_table
    ensure_tag_cloud_roles_table
    ensure_tag_cloud_preferences_table

    migrate_legacy_tag_clouds_data
    add_missing_tag_clouds_columns
    add_missing_preferences_columns
    remove_legacy_tag_clouds_columns
  end

  def down
    # Only drop our tables; never touch tags/taggings
    drop_table :tag_cloud_preferences if table_exists?(:tag_cloud_preferences)
    drop_table :tag_cloud_roles if table_exists?(:tag_cloud_roles)
    drop_table :tag_cloud_tags if table_exists?(:tag_cloud_tags)
    drop_table :tag_cloud_projects if table_exists?(:tag_cloud_projects)
    drop_table :tag_clouds if table_exists?(:tag_clouds)
  end

  private

  # --- ensure tables ---

  def ensure_tags_tables
    ActiveRecord::Base.create_taggable_table
  end

  def ensure_tag_clouds_table
    return if table_exists?(:tag_clouds)

    create_table :tag_clouds do |t|
      t.string  :name, null: false
      t.text    :status_filter
      t.text    :version_filter
      t.text    :tracker_filter
      t.boolean :tag_filter, null: false, default: false
      t.boolean :include_subprojects, null: false, default: false
      t.boolean :visible_by_default, null: false, default: true
      t.references :owner, null: true, foreign_key: { to_table: :users }, index: true
      t.string  :visibility, null: false, default: 'all'
      t.references :created_by, null: true, foreign_key: { to_table: :users }, index: true
      t.timestamps
    end
    add_index :tag_clouds, :visibility unless index_exists?(:tag_clouds, :visibility)
  end

  def ensure_tag_cloud_projects_table
    return if table_exists?(:tag_cloud_projects)

    create_table :tag_cloud_projects do |t|
      t.references :tag_cloud, null: false, foreign_key: true, index: false
      t.references :project,   null: false, foreign_key: true, index: false
      t.integer :position, null: false, default: 0
    end
    add_index :tag_cloud_projects, %i[tag_cloud_id project_id],
              unique: true, name: 'index_tag_cloud_projects_unique'
    add_index :tag_cloud_projects, %i[project_id position],
              name: 'index_tag_cloud_projects_on_project_position'
  end

  def ensure_tag_cloud_tags_table
    return if table_exists?(:tag_cloud_tags)

    create_table :tag_cloud_tags do |t|
      t.references :tag_cloud, null: false, foreign_key: true, index: true
      t.integer :tag_id, null: false
    end
    add_index :tag_cloud_tags, %i[tag_cloud_id tag_id],
              unique: true, name: 'index_tag_cloud_tags_unique'
    add_index :tag_cloud_tags, :tag_id unless index_exists?(:tag_cloud_tags, :tag_id)
  end

  def ensure_tag_cloud_roles_table
    return if table_exists?(:tag_cloud_roles)

    create_table :tag_cloud_roles do |t|
      t.references :tag_cloud, null: false, foreign_key: true, index: true
      t.references :role, null: false, foreign_key: true, index: true
    end
    add_index :tag_cloud_roles, %i[tag_cloud_id role_id],
              unique: true, name: 'index_tag_cloud_roles_unique'
  end

  def ensure_tag_cloud_preferences_table
    return if table_exists?(:tag_cloud_preferences)

    create_table :tag_cloud_preferences do |t|
      t.references :tag_cloud, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.boolean :visible, null: false, default: true
      t.integer :position
      t.timestamps
    end
    add_index :tag_cloud_preferences, %i[tag_cloud_id user_id],
              unique: true, name: 'index_tag_cloud_preferences_unique'
  end

  # --- data + columns reshape ---

  def migrate_legacy_tag_clouds_data
    return unless table_exists?(:tag_clouds)
    return unless column_exists?(:tag_clouds, :project_id)

    MigrationTagCloud.reset_column_information
    MigrationTagCloudProject.reset_column_information

    say_with_time 'Backfill tag_cloud_projects from legacy tag_clouds.project_id' do
      scope = if column_exists?(:tag_clouds, :is_system)
                MigrationTagCloud.where(is_system: [false, nil])
              else
                MigrationTagCloud.all
              end

      scope.find_each do |cloud|
        next if cloud.project_id.blank?
        next if MigrationTagCloudProject.exists?(tag_cloud_id: cloud.id, project_id: cloud.project_id)

        pos = if column_exists?(:tag_clouds, :position)
                cloud.position.to_i
              else
                0
              end

        MigrationTagCloudProject.create!(
          tag_cloud_id: cloud.id,
          project_id: cloud.project_id,
          position: pos
        )
      end
    end

    if column_exists?(:tag_clouds, :is_system)
      say_with_time 'Remove system / Default Tags clouds' do
        system_ids = MigrationTagCloud.where(is_system: true).pluck(:id)
        next if system_ids.empty?

        if table_exists?(:tag_cloud_preferences)
          MigrationTagCloudPreference.where(tag_cloud_id: system_ids).delete_all
        end
        if table_exists?(:tag_cloud_projects)
          MigrationTagCloudProject.where(tag_cloud_id: system_ids).delete_all
        end
        if table_exists?(:tag_cloud_tags)
          execute "DELETE FROM tag_cloud_tags WHERE tag_cloud_id IN (#{system_ids.join(',')})"
        end
        if table_exists?(:tag_cloud_roles)
          execute "DELETE FROM tag_cloud_roles WHERE tag_cloud_id IN (#{system_ids.join(',')})"
        end
        MigrationTagCloud.where(id: system_ids).delete_all
      end
    end
  end

  def add_missing_tag_clouds_columns
    return unless table_exists?(:tag_clouds)

    unless column_exists?(:tag_clouds, :tag_filter)
      add_column :tag_clouds, :tag_filter, :boolean, null: false, default: false
    end
    unless column_exists?(:tag_clouds, :include_subprojects)
      add_column :tag_clouds, :include_subprojects, :boolean, null: false, default: false
    end
    unless column_exists?(:tag_clouds, :owner_id)
      add_column :tag_clouds, :owner_id, :bigint
      add_index :tag_clouds, :owner_id unless index_exists?(:tag_clouds, :owner_id)
      unless foreign_key_exists?(:tag_clouds, column: :owner_id)
        add_foreign_key :tag_clouds, :users, column: :owner_id, on_delete: :nullify
      end
    end
    unless column_exists?(:tag_clouds, :visibility)
      add_column :tag_clouds, :visibility, :string, null: false, default: 'all'
    end
    add_index :tag_clouds, :visibility unless index_exists?(:tag_clouds, :visibility)

    # visible_by_default / filters / name / created_by already exist on legacy
    unless column_exists?(:tag_clouds, :visible_by_default)
      add_column :tag_clouds, :visible_by_default, :boolean, null: false, default: true
    end
  end

  def add_missing_preferences_columns
    return unless table_exists?(:tag_cloud_preferences)
    return if column_exists?(:tag_cloud_preferences, :position)

    add_column :tag_cloud_preferences, :position, :integer
  end

  def remove_legacy_tag_clouds_columns
    return unless table_exists?(:tag_clouds)

    # Drop indexes that reference legacy columns first
    remove_index_if_exists :tag_clouds, %i[project_id name]
    remove_index_if_exists :tag_clouds, %i[project_id is_system]
    remove_index_if_exists :tag_clouds, %i[project_id position]
    remove_index_if_exists :tag_clouds, :project_id

    # Named indexes from old 003 migration
    remove_index_by_name_if_exists :tag_clouds, 'index_tag_clouds_on_project_id_and_name'
    remove_index_by_name_if_exists :tag_clouds, 'index_tag_clouds_on_project_id_and_is_system'
    remove_index_by_name_if_exists :tag_clouds, 'index_tag_clouds_on_project_id_and_position'
    remove_index_by_name_if_exists :tag_clouds, 'index_tag_clouds_on_project_id'

    if foreign_key_exists?(:tag_clouds, :projects)
      remove_foreign_key :tag_clouds, :projects
    end

    remove_column :tag_clouds, :project_id if column_exists?(:tag_clouds, :project_id)
    remove_column :tag_clouds, :position if column_exists?(:tag_clouds, :position)
    remove_column :tag_clouds, :is_system if column_exists?(:tag_clouds, :is_system)
  end

  def remove_index_if_exists(table, columns)
    remove_index table, columns if index_exists?(table, columns)
  rescue ArgumentError, ActiveRecord::StatementInvalid
    # index name mismatch — ignore
  end

  def remove_index_by_name_if_exists(table, name)
    remove_index table, name: name if index_exists?(table, name: name)
  rescue ArgumentError, ActiveRecord::StatementInvalid
    # ignore
  end
end
