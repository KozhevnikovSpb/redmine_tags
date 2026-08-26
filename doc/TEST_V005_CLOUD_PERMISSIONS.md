# Manual QA: Tag cloud permissions (V.0.0.5 iteration 2)

Target: Redmine 7.0 / Ruby 3.4 / Rails 8.1
Plugin ID: :redmineup_tags

Assign permissions in Administration → Roles and permissions → Issue tracking.

`create_tags` / `edit_tags` are unchanged and only affect issue tag fields.

## No cloud permissions

- Issues sidebar shows only the default Tags cloud
- No «Select visible tag clouds» link
- Project → Settings has no Tag Clouds tab
- Direct `/projects/:id/tag_clouds` returns 403

## View tag clouds

- Custom clouds with visibility All / matching Roles appear in the sidebar
- No sort/hide controls and no select modal
- Project → Settings → Tag Clouds is a read-only list (no New / Edit / Delete / drag)
- Author-only clouds of other users are absent from sidebar and from the settings list
- Own author-only cloud is visible in the sidebar, not in the settings list
- Direct edit/delete URL of any cloud returns 403

## Manage tag cloud display

- Select visible tag clouds link is shown
- User can show/hide and reorder allowed custom clouds (and the system cloud)
- Another author's author-only cloud is not in the modal and cannot be revealed by a stored preference
- Own author-only cloud can be shown/hidden in the modal
- Settings tab appears only if View or Manage tag clouds is also granted

## Manage tag clouds

- Create / edit / delete / reorder in project settings
- Author-only clouds of other users (and own author-only clouds) are not listed
- Direct edit/delete/reorder of author-only clouds is denied
- Does not by itself show the personal select modal

## Full Redmine administrator

- Global plugin settings → Tag Clouds lists author-only clouds
- Admin can edit them and change visibility away from Author only
- Admin can manage those clouds from a project as well
- Admin bypasses project membership
