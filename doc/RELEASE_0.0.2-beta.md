# Release v0.0.2-beta

**Date:** 2026-08-10  
**Plugin version:** `0.0.2-beta`  
**Git tag:** `v0.0.2-beta`  
**Plugin ID:** `:redmineup_tags`  
**Repository:** https://github.com/KozhevnikovSpb/redmine_tags

## Requirements

| Component | Version |
|-----------|---------|
| Redmine   | 7.0.0+ |
| Ruby      | 3.4.x |
| Rails     | 8.1.x |
| redmineup gem | ≥ 1.1.10 |

## Highlights

- Multi Tag Clouds: several filtered tag clouds per project
- New DB schema (project link via `tag_cloud_projects`, virtual Default Tags)
- Sidebar display of system + custom clouds with real RedmineUP tags and counts
- User preferences: visibility and order
- Tag click applies issue filters immediately (`f`/`op`/`v` + `set_filter`)

## Install / upgrade

```bash
cd /path/to/redmine/plugins
# directory name must match plugin load path used on server (redmineup_tags or symlink)
git clone https://github.com/KozhevnikovSpb/redmine_tags.git redmineup_tags
cd redmineup_tags
git fetch --tags
git checkout v0.0.2-beta

cd /path/to/redmine
bundle install
RAILS_ENV=production bundle exec rake redmine:plugins:migrate
# optional hard rebuild of cloud tables only (preserves tags/taggings):
# RAILS_ENV=production bundle exec rake redmineup_tags:force_rebuild

# restart application server
```

## Verify

```bash
RAILS_ENV=production bundle exec rake redmineup_tags:schema_status
```

Manual QA: `doc/TEST_DISPLAY_FILTERS.md`

## Out of scope (next versions)

- Tag whitelist UI (`tag_filter`)
- Visibility UI for owner/roles
- Extended automated tests

## Create tag & GitHub Release (maintainer)

```bash
git checkout main
git pull
git tag -a v0.0.2-beta -m "v0.0.2-beta: multi tag clouds schema, display, filtering, preferences"
git push origin v0.0.2-beta

gh release create v0.0.2-beta \
  --title "v0.0.2-beta" \
  --notes-file doc/RELEASE_0.0.2-beta.md \
  --prerelease
```
