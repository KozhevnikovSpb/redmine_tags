# frozen_string_literal: true

class AddTagOperatorToTagClouds < ActiveRecord::Migration[7.0]
  def up
    unless column_exists?(:tag_clouds, :tag_operator)
      add_column :tag_clouds, :tag_operator, :string, default: '*', null: false
    end
    backfill_tag_operator
  end

  def down
    remove_column :tag_clouds, :tag_operator if column_exists?(:tag_clouds, :tag_operator)
  end

  private

  def backfill_tag_operator
    return unless table_exists?(:tag_clouds)
    return unless column_exists?(:tag_clouds, :tag_filter)

    say_with_time 'Backfill tag_operator from tag_filter (true → is)' do
      execute(<<~SQL.squish)
        UPDATE tag_clouds
        SET tag_operator = '='
        WHERE tag_operator = '*'
          AND (tag_filter = TRUE OR tag_filter = 1 OR tag_filter = 't')
      SQL
    end
  end
end
