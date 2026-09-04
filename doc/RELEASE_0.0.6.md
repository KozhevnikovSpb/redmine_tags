# Release v0.0.6 (Development)

**Date:** 2026-09-04  
**Plugin version:** `0.0.6` (Development)  
**Plugin ID:** `:redmineup_tags`  
**Repository:** https://github.com/KozhevnikovSpb/redmine_tags

## Requirements

| Component | Version |
|-----------|---------|
| Redmine   | 7.0.0.stable |
| Ruby      | 3.4.x |
| Rails     | 8.1.x |
| redmineup gem | ≥ 1.1.10 |

Q&A compatibility preserved. Field name `tag[color]`, stored format `#rrggbb`.

## Tag colors

- Admin Edit / Merge: pastel 27-color grid + native color input + hex + Auto
- Replaces RedmineUP `$.fn.colorPicker` on those pages
- Manual `tags.color` is painted as-is (no mute)
- Empty color still uses MD5(name) + mute; white mix reduced (`t` 0.34 → 0.20, max L 0.76 → 0.72)
- Save normalizes to `#rrggbb` or clears the column for Auto

## Docs / tests

- `doc/TEST_V006_TAG_COLORS.md`
- `test/unit/tag_color_test.rb`

## Deploy

```bash
cd /path/to/redmine/plugins/redmineup_tags   # or redmine_tags symlink
git pull origin main
# restart app, then Ctrl+F5 for tag_color_picker.js / tag_colors.css
```

No new migrations.
