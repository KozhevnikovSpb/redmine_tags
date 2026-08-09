# Manual QA: Display & Filtering (V.0.0.2-beta)

Target: Redmine 7.0 / Ruby 3.4 / Rails 8.1  
Plugin id: `:redmineup_tags`

## 0. Prerequisites

1. `git pull` in `plugins/redmineup_tags` (or symlink `redmine_tags`).
2. Restart app server.
3. Optional schema check:
   ```bash
   bundle exec rake redmineup_tags:schema_status RAILS_ENV=production
   ```
4. Administration → Plugins → Redmine Multi Tags Clouds:
   - Sidebar view ≠ **None** (default now **Simple cloud**)
   - Prefer **Display amount of issues** = on
   - **Use colors** = on for visual check
5. Project → Modules: enable **Tags** (and Issue tracking).
6. Roles: `Manage tag clouds`, `Select visible tag clouds`, `Edit tags` / `Create tags` as needed.

## 1. Settings page (no 500)

- [ ] Project → Settings → **Tag Clouds** opens without error
- [ ] Virtual row **Default Tags** / system badge is first
- [ ] Link **New Tag Cloud** works

## 2. Create cloud + filters

- [ ] Create cloud `Bugs only`: tracker = Bug (or local equivalent), leave status/version empty
- [ ] Create cloud `Closed`: status = closed statuses only
- [ ] Settings table shows filter summary (not empty / not crash)
- [ ] `Include subprojects` checkbox saves and shows in summary when on
- [ ] `Visible by default` off → cloud hidden for users without preference override

## 3. Sidebar display (Issues)

- [ ] Issues index: section **Tags** always present (system)
- [ ] Custom clouds appear under system with their **names**
- [ ] Tags are real RedmineUP tags (names from issues), not tracker/status labels
- [ ] Counts match filtered issues when «show count» is on
- [ ] Colors applied when use_colors is on
- [ ] Empty filter set = same universe as unfiltered issues (for that project)
- [ ] Click tag → issues list filtered by that tag

## 4. Filtering correctness

- [ ] Same issue can contribute tags to **two** clouds if it matches both filter sets
- [ ] `Closed` cloud does not list tags that exist only on open issues (if no closed issue has them)
- [ ] Tracker filter restricts to that tracker’s issues only

## 5. Preferences modal

- [ ] Link **Select visible tag clouds** under system cloud (only if custom clouds exist)
- [ ] Uncheck a cloud → Save → disappears from sidebar for current user
- [ ] Check again → reappears
- [ ] Drag reorder → Save → order on Issues matches

## 6. Reorder in Settings

- [ ] Drag custom rows (not system) → order persists after reload
- [ ] System row stays on top

## 7. Log hygiene

- [ ] No `column "position" does not exist` on `tag_clouds`
- [ ] No `ensure_system_cloud` / `is_system?` NoMethodError
- [ ] No uncaught exception in `[redmineup_tags] Failed to render sidebar`

## 8. Compatibility smoke

- [ ] Issue form still shows tag field / autocomplete
- [ ] Existing tags on issues unchanged after cloud CRUD
- [ ] Q&A / other RedmineUP tag plugins (if installed) still load
