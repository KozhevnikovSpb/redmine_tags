# frozen_string_literal: true

class AddFilterOperatorsToTagClouds < ActiveRecord::Migration[7.0]
  def up
    add_column :tag_clouds, :status_operator, :string, default: '*', null: false unless column_exists?(:tag_clouds, :status_operator)
    add_column :tag_clouds, :version_operator, :string, default: '*', null: false unless column_exists?(:tag_clouds, :version_operator)
    add_column :tag_clouds, :tracker_operator, :string, default: '*', null: false unless column_exists?(:tag_clouds, :tracker_operator)

    reversible_backfill
  end

  def down
    remove_column :tag_clouds, :status_operator if column_exists?(:tag_clouds, :status_operator)
    remove_column :tag_clouds, :version_operator if column_exists?(:tag_clouds, :version_operator)
    remove_column :tag_clouds, :tracker_operator if column_exists?(:tag_clouds, :tracker_operator)
  end

  private

  def reversible_backfill
    return unless table_exists?(:tag_clouds)

    say_with_time 'Backfill operators: ids present → is (=), else any (*)' do
      execute(<<~SQL.squish)
        UPDATE tag_clouds
        SET status_operator = '='
        WHERE status_operator = '*'
          AND status_filter IS NOT NULL
          AND TRIM(status_filter) NOT IN ('', '--- []', '[]')
      SQL
      execute(<<~SQL.squish)
        UPDATE tag_clouds
        SET version_operator = '='
        WHERE version_operator = '*'
          AND version_filter IS NOT NULL
          AND TRIM(version_filter) NOT IN ('', '--- []', '[]')
      SQL
      execute(<<~SQL.squish)
        UPDATE tag_clouds
        SET tracker_operator = '='
        WHERE tracker_operator = '*'
          AND tracker_filter IS NOT NULL
          AND TRIM(tracker_filter) NOT IN ('', '--- []', '[]')
      SQL
    end
  end
end
