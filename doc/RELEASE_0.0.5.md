# Release v0.0.5

**Date:** 2026-09-02  
**Plugin version:** `0.0.5` (Stable)  
**Git tag:** `v0.0.5`  
**Plugin ID:** `:redmineup_tags`  
**Repository:** https://github.com/KozhevnikovSpb/redmine_tags

## Requirements

| Component | Version |
|-----------|---------|
| Redmine   | 7.0.0.stable |
| Ruby      | 3.4.x |
| Rails     | 8.1.x |
| redmineup gem | ≥ 1.1.10 |

Compatibility with other RedmineUP tag plugins (Q&A) is preserved. Plugin ID stays `:redmineup_tags`.

## Highlights

- Roles block **Tags and tag clouds**: view / select / manage plus unchanged `create_tags` / `edit_tags`
- `manage_tag_clouds` includes personal display (select modal, order, hide)
- Author-only clouds stay private to the author on the project; admin edits others only from plugin settings
- My account: Show issue counts for everyone; Show untagged issues only for manage / admin
- Per-cloud personal untagged caption in the sidebar (`без тегов - N`)
- Issue list Tags filter `is` / `is not` uses OR across selected tags (same as Status / Tracker / Version)
- Muted tag chip colors at display time; personal count vs weight
- SchemaRepair creates missing cloud / preference columns on boot (migrations 007-008)

## Permissions (short)

| Permission | Sidebar custom clouds | Settings tab | Modal | Untagged |
| --- | --- | --- | --- | --- |
| none | no | no | no | no |
| view | shared + own author-only | read-only, no author-only rows | no | no |
| select | hide / reorder allowed clouds | no (alone) | yes | no |
| manage | hide / reorder + CRUD including own author-only | yes | yes | yes |

Full matrix: `doc/TEST_V005_CLOUD_PERMISSIONS.md`.

## Install / upgrade

```bash
cd /path/to/redmine/plugins
git clone https://github.com/KozhevnikovSpb/redmine_tags.git redmineup_tags
# or: existing folder / symlink named redmine_tags or redmineup_tags
cd redmineup_tags
git fetch --tags
git checkout v0.0.5

cd /path/to/redmine
bundle install
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmineup_tags
# if columns are missing after upgrade:
# RAILS_ENV=production bundle exec rake redmineup_tags:repair_schema
# or: RAILS_ENV=production bundle exec rake redmineup_tags:ensure_tables

# restart application server
```

Hard rebuild of cloud tables only (preserves tags/taggings and user display prefs):

```bash
RAILS_ENV=production bundle exec rake redmineup_tags:force_rebuild
```

## Verify

```bash
RAILS_ENV=production bundle exec rake redmineup_tags:schema_status
bundle exec rake redmine:plugins:test NAME=redmineup_tags RAILS_ENV=test
```

After deploy refresh plugin assets (Ctrl+F5).

## Create tag & GitHub Release (maintainer)

```bash
git checkout main
git pull
git tag -a v0.0.5 -m "v0.0.5: permissions, untagged captions, Tags filter OR"
git push origin v0.0.5

gh release create v0.0.5 \
  --title "v0.0.5" \
  --notes-file doc/RELEASE_0.0.5.md
```
