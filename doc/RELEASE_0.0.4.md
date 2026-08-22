# Release v0.0.4

**Date:** 2026-08-22  
**Plugin version:** `0.0.4` (Stable)  
**Git tag:** `v0.0.4`  
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

- Global admin list of all custom tag clouds
- Inherited parent clouds in subprojects (settings, modal, sidebar)
- Issue List operators for status / tracker / version, including history
- Author-only visibility locked to the cloud author
- Roles visibility via checkboxes
- Sidebar / modal / settings UI polish (markers, wrap, responsive table, zebra)

## Sidebar order

1. System cloud (Tags) — marker S / С  
2. Inherited clouds from parents with include_subprojects — marker R / К  
3. Local project clouds  

Sort is independent inside each container.

## Install / upgrade

```bash
cd /path/to/redmine/plugins
git clone https://github.com/KozhevnikovSpb/redmine_tags.git redmineup_tags
# or: existing folder / symlink named redmine_tags or redmineup_tags
cd redmineup_tags
git fetch --tags
git checkout v0.0.4

cd /path/to/redmine
bundle install
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmineup_tags
# if operator columns are missing after upgrade:
# RAILS_ENV=production bundle exec rake redmineup_tags:repair_schema

# restart application server
```

Hard rebuild of cloud tables only (preserves tags/taggings):

```bash
RAILS_ENV=production bundle exec rake redmineup_tags:force_rebuild
```

## Verify

```bash
RAILS_ENV=production bundle exec rake redmineup_tags:schema_status
```

After deploy refresh plugin assets (Ctrl+F5).

## Create tag & GitHub Release (maintainer)

```bash
git checkout main
git pull
git tag -a v0.0.4 -m "v0.0.4: inherited clouds, admin list, operators, visibility, UI"
git push origin v0.0.4

gh release create v0.0.4 \
  --title "v0.0.4" \
  --notes-file doc/RELEASE_0.0.4.md
```
