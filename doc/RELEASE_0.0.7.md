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
- Roles labels distinguish issues from Q&A: Create issue tags / Edit issue tags
- Create issue tags requires Edit issue tags (checkbox disabled, stripped on save, ignored at runtime)
- Roles that already had `create_tags` / `edit_tags` get the new issue permissions on boot
- New tag names in the issue form require `create_issue_tags`
- Full `ru.yml` restored (a label commit had truncated it)
- Functional tests use the new permission symbols
- Project settings: Edit Default Tags and Reset are enabled only for a full Redmine administrator; manage users see disabled icons
- `reset_preferences` is admin-only (manage_tag_clouds is not enough)

## Deploy

```bash
cd /path/to/redmine/plugins/redmine_tags   # or redmineup_tags symlink
git pull origin main
# restart app so role permission copy runs, then Ctrl+F5
```

No DB migration. After restart open Administration → Roles:

1. Block **Tags and tag clouds** shows **Create issue tags** / **Edit issue tags**
2. Block **Q&A** keeps **Create tags** / **Edit tags**
3. Unchecking the Tags checkboxes must stay unchecked after Save
4. Create issue tags stays disabled until Edit issue tags is checked
5. With both issue permissions on, type a new tag on an issue and save — it must persist
6. Project → Settings → Tag Clouds: manager with Manage tag clouds sees disabled Edit on Default Tags and disabled Reset; only a full administrator can use them
