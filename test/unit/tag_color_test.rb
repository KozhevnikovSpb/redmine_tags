# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class TagColorTest < ActiveSupport::TestCase
  FakeTag = Struct.new(:name, :color)

  def test_normalize_stored_color
    assert_equal '#ffffff', RedmineupTags.normalize_stored_color('#ffffff')
    assert_equal '#ff0000', RedmineupTags.normalize_stored_color('FF0000')
    assert_equal '#3366ff', RedmineupTags.normalize_stored_color('#3366FF')
    assert_nil RedmineupTags.normalize_stored_color('')
    assert_nil RedmineupTags.normalize_stored_color('auto')
    assert_nil RedmineupTags.normalize_stored_color('red')
    assert_nil RedmineupTags.normalize_stored_color('#fff')
    assert_nil RedmineupTags.normalize_stored_color(nil)
  end

  def test_display_softens_stored_color
    tag = FakeTag.new('Bug', '#f87171')
    shown = RedmineupTags.display_tag_color(tag)
    assert_not_equal '#f87171', shown
    assert_match(/\A#[0-9a-f]{6}\z/, shown)
    assert_equal '#f87171', RedmineupTags.extract_tag_hex(tag)
  end

  def test_display_mutes_auto_md5_color
    tag = FakeTag.new('Bug', nil)
    raw = RedmineupTags.auto_tag_color(tag)
    shown = RedmineupTags.display_tag_color(tag)
    assert_equal raw, RedmineupTags.extract_tag_hex(tag)
    assert_not_equal raw, shown
    assert_match(/\A#[0-9a-f]{6}\z/, shown)
  end

  def test_pastel_palette_size_and_format
    assert_equal 27, RedmineupTags::PASTEL_PALETTE.size
    RedmineupTags::PASTEL_PALETTE.each do |hex|
      assert_equal hex, RedmineupTags.normalize_stored_color(hex)
    end
  end
end
