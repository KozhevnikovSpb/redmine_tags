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
- Issue tag permissions split from Q&A: `create_issue_tags` / `edit_issue_tags`
- Roles that already had `create_tags` / `edit_tags` get the new issue permissions on boot
- New tag names in the issue form require `create_issue_tags`

## Deploy

```bash
cd /path/to/redmine/plugins/redmine_tags   # or redmineup_tags symlink
git pull origin main
# restart app so role permission copy runs, then Ctrl+F5
```

No DB migration. After restart open Administration → Roles and confirm **Tags and tag clouds** Create tags / Edit tags can be toggled independently of Q&A.
