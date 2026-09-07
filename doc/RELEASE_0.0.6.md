# Release v0.0.6 (Development)

**Date:** 2026-09-07  
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

Q&A compatibility preserved. Field name `tag[color]`, stored format `#rrggbb`. Permission names unchanged.

## System Tags cloud visibility

- Project Settings → Tag Clouds: the system Tags row checkbox in Visible by default can be turned off
- Requires `manage_tag_clouds`; view-only roles see the current value read-only
- Stored per project in `tag_cloud_project_settings` (migration 009)
- Users with Manage display can still show it for themselves in Select visible tag clouds
- Modal Reset returns to the project default
- Deploy: `rake redmine:plugins:migrate NAME=redmineup_tags` or `rake redmineup_tags:ensure_tables`

## Tag colors

- Admin Edit / Merge: pastel 27-color grid + native color input + hex + Auto
- Replaces RedmineUP `$.fn.colorPicker` on those pages
- Manual `tags.color` is painted as-is (no mute)
- Empty color still uses MD5(name) + mute; white mix reduced (`t` 0.34 → 0.20, max L 0.76 → 0.72)
- Save normalizes to `#rrggbb` or clears the column for Auto

## Docs / tests

- `doc/TEST_V006_TAG_COLORS.md`
- `test/unit/tag_color_test.rb`
- `test/unit/tag_cloud_project_setting_test.rb`

## Deploy

```bash
cd /path/to/redmine/plugins/redmineup_tags   # or redmine_tags symlink
git pull origin main
bundle exec rake redmine:plugins:migrate NAME=redmineup_tags RAILS_ENV=production
# or: bundle exec rake redmineup_tags:ensure_tables
# restart app, then Ctrl+F5 for redmine_tags.js
```
