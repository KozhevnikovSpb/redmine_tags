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

  def test_display_auto_uses_pastel_not_raw_md5
    tag = FakeTag.new('Bug', nil)
    raw = RedmineupTags.auto_tag_color(tag)
    shown = RedmineupTags.display_tag_color(tag)
    assert_equal raw, RedmineupTags.extract_tag_hex(tag)
    assert_equal shown, RedmineupTags.auto_pastel_hex(tag)
    assert_not_equal raw, shown
    assert_match(/\A#[0-9a-f]{6}\z/, shown)
  end

  def test_auto_pastel_stays_in_pastel_band_and_varies
    names = %w[Bug Feature Hotfix Review Docs Backend Frontend Support Design]
    colors = names.map { |name| RedmineupTags.auto_pastel_hex(name) }
    assert colors.uniq.size >= 6, colors.inspect
    colors.each do |hex|
      r, g, b = hex.delete('#').scan(/../).map { |part| part.to_i(16) / 255.0 }
      _h, s, l = RedmineupTags.rgb_to_hsl(r, g, b)
      assert_operator s, :>=, 0.26
      assert_operator s, :<=, 0.56
      assert_operator l, :>=, 0.58
      assert_operator l, :<=, 0.80
    end
  end

  def test_tag_text_color_dark_background_is_light
    assert_equal '#f8fafc', RedmineupTags.tag_text_color('#000000')
    assert_equal '#f8fafc', RedmineupTags.tag_text_color('#1e3a8a')
  end

  def test_tag_text_color_light_background_is_dark
    assert_equal '#1f2937', RedmineupTags.tag_text_color('#fecaca')
    assert_equal '#1f2937', RedmineupTags.tag_text_color('#ffffff')
  end

  def test_pastel_palette_size_and_format
    assert_equal 45, RedmineupTags::PASTEL_PALETTE.size
    RedmineupTags::PASTEL_PALETTE.each do |hex|
      assert_equal hex, RedmineupTags.normalize_stored_color(hex)
    end
  end
end
