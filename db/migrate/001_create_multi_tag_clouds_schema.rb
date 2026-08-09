# frozen_string_literal: true

# Target schema for Multi Tag Clouds (Redmine 7 / Rails 8.1)
# - tags/taggings via redmineup create_taggable_table
# - no is_system / Default Tags records
# - cloud must be linked via tag_cloud_projects to be shown

class CreateMultiTagCloudsSchema < ActiveRecord::Migration[7.0]
  def up
    # Redmineup tags + taggings (name string, color integer)
    ActiveRecord::Base.create_taggable_table

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

    add_index :tag_clouds, :visibility

    create_table :tag_cloud_projects do |t|
      t.references :tag_cloud, null: false, foreign_key: true, index: false
      t.references :project,   null: false, foreign_key: true, index: false
      t.integer :position, null: false, default: 0
    end

    add_index :tag_cloud_projects, %i[tag_cloud_id project_id],
              unique: true, name: 'index_tag_cloud_projects_unique'
    add_index :tag_cloud_projects, %i[project_id position],
              name: 'index_tag_cloud_projects_on_project_position'

    create_table :tag_cloud_tags do |t|
      t.references :tag_cloud, null: false, foreign_key: true, index: true
      t.integer :tag_id, null: false
    end

    add_index :tag_cloud_tags, %i[tag_cloud_id tag_id],
              unique: true, name: 'index_tag_cloud_tags_unique'
    add_index :tag_cloud_tags, :tag_id

    create_table :tag_cloud_roles do |t|
      t.references :tag_cloud, null: false, foreign_key: true, index: true
      t.references :role, null: false, foreign_key: true, index: true
    end

    add_index :tag_cloud_roles, %i[tag_cloud_id role_id],
              unique: true, name: 'index_tag_cloud_roles_unique'

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

  def down
    drop_table :tag_cloud_preferences if table_exists?(:tag_cloud_preferences)
    drop_table :tag_cloud_roles if table_exists?(:tag_cloud_roles)
    drop_table :tag_cloud_tags if table_exists?(:tag_cloud_tags)
    drop_table :tag_cloud_projects if table_exists?(:tag_cloud_projects)
    drop_table :tag_clouds if table_exists?(:tag_clouds)
    # tags/taggings не удаляем — могут использоваться другими плагинами redmineup
  end
end
