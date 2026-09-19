# Release v0.0.7 (Development)

**Date:** 2026-09-19  
**Plugin version:** `0.0.7` (Development)  
**Plugin ID:** `:redmineup_tags`  
**Repository:** https://github.com/KozhevnikovSpb/redmine_tags

## Requirements

| Component | Version |
|-----------|---------|
| Redmine   | 7.0.0.stable |
| Ruby      | 3.4.x |
| Rails     | 8.1.x |
| redmineup gem | ≥ 1.1.10 |

Q&A compatibility preserved. Plugin ID stays `:redmineup_tags`. Field names `issue_tags` and `tag[color]` unchanged.

## Scope

Bug fixes and copy. No new features.

## Done

- Version bumped from `0.0.6` to `0.0.7`
- Locale fragments (`*_resets.yml`, `*_system_hide.yml`) merged into `config/locales/en.yml` and `ru.yml`
- RU strings for Apply to all / project Reset / hide Default Tags

## Deploy

```bash
cd /path/to/redmine/plugins/redmine_tags   # or redmineup_tags symlink
git pull origin main
# no migration required for this locale-only start
# restart app, then Ctrl+F5
```
