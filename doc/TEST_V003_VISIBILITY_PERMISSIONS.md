# Manual QA: Visibility, Roles, Tag filter, Permissions (V.0.0.3)

Target: Redmine 7.0 / Ruby 3.4 / Rails 8.1  
Plugin id: `:redmineup_tags`  
Version: **0.0.3**

## 0. Prerequisites

1. `git pull` in `plugins/redmineup_tags` (or symlink `redmine_tags`).
2. Restart app server (no new migration required if 0.0.2 schema already applied).
3. Project → Modules: enable **Tags**.
4. Administration → Roles and permissions → module **Tags**:
   - **Manage tag clouds** — Manager / Developer as needed
   - **Select visible tag clouds** — broader set of roles for personal sidebar control

## 1. Permissions gate

- [ ] User **without** Manage tag clouds: Project Settings → no Tag Clouds tab (or no New/Edit)
- [ ] User **with** Manage tag clouds (member): can open Settings → Tag Clouds, create/edit/delete/reorder
- [ ] User **without** Select visible tag clouds: no «Select visible tag clouds» link under system Tags in sidebar
- [ ] User **with** Select visible tag clouds: modal opens, save works

## 2. Visibility = All

- [ ] Create cloud `Public`, visibility = All users, Visible by default = on
- [ ] Regular member sees it in Issues sidebar
- [ ] Visible by default = off → hidden until user enables in preferences modal
- [ ] Preference override still works (hide/show)

## 3. Visibility = Owner only

- [ ] Create cloud as User A, visibility = Owner only
- [ ] Settings table shows Owner only (+ name)
- [ ] User A sees cloud in sidebar
- [ ] User B (other member) does **not** see it (unless preference was set — should not, if never visible)
- [ ] Owner field auto-set on create

## 4. Visibility = Selected roles

- [ ] Create cloud, visibility = Roles, **no roles selected** → validation error, not saved
- [ ] Select role Manager only → save OK
- [ ] User with Manager role in project sees cloud
- [ ] User with only Developer role does **not** see cloud
- [ ] Anonymous does not see cloud
- [ ] Settings table shows role names

## 5. Tag whitelist (tag_filter)

- [ ] Create cloud without tag filter → same tags as filtered issues (status/tracker)
- [ ] Enable «Restrict cloud to selected tags», select 1–2 tags → only those appear
- [ ] Enable whitelist with **zero** tags selected → cloud body empty (or section skipped)
- [ ] Disable tag filter → full set again; join rows cleared

## 6. Combined filters + whitelist

- [ ] Tracker = Bug + tag whitelist = one tag that exists only on Feature → empty or reduced set consistent with Aggregator rules

## 7. Compatibility smoke

- [ ] Issue form tags field / autocomplete still works
- [ ] Existing tags on issues unchanged
- [ ] Q&A / other RedmineUP tag plugins still load if installed
- [ ] System «Tags» cloud always present regardless of custom visibility rules

## 8. Log hygiene

- [ ] No 500 on new/edit form
- [ ] No exception in `[redmineup_tags] Failed to render sidebar`
