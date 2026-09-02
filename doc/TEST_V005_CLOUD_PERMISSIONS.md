# Manual QA: Tag cloud permissions (V.0.0.5)

Target: Redmine 7.0 / Ruby 3.4 / Rails 8.1
Plugin ID: :redmineup_tags

Assign permissions in Administration → Roles and permissions → **Tags and tag clouds**
(not under Issue tracking).

`create_tags` / `edit_tags` names are unchanged for RedmineUP Q&A compatibility.
They now live in the same Roles block as the three cloud permissions.

The project module `:redmineup_tags` is auto-enabled on projects that already have
Issue tracking (existing projects on boot, new projects on save).

`manage_tag_clouds` includes personal display management (`select_tag_clouds`).
On the Roles form, checking Manage tag clouds also checks and disables Manage tag cloud display.

The My account checkbox «Show untagged issues» is only for Manage tag clouds (or admin).

## Matrix

| Permission | Sidebar default Tags | Sidebar shared clouds | Sidebar own author-only | Sidebar others author-only | Project settings tab | Settings: own author-only | Settings: others author-only | Select modal | Untagged profile / captions | Create / edit / delete |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| none | yes | no | no | no | no | — | — | no | no | no |
| view_tag_clouds | yes | yes if visible by default / matching roles | yes | no | read-only | no | no | no | no | no |
| select_tag_clouds | yes, can hide | yes, can hide/reorder | yes, can hide | no | no | — | — | yes | no | no |
| manage_tag_clouds | yes, can hide | yes, can hide/reorder | yes, can hide | no | yes | yes, with Edit / Delete | no | yes | yes | yes, including own author-only |
| admin (not author) | yes | yes | no | no | yes | no | no | shared only | yes | shared only; author-only only via plugin list |
| admin (is author) | yes | yes | yes | no | yes | yes, with Edit / Delete | no | yes | yes | yes |

## Roles block

- Administration → Roles → a separate fieldset **Tags and tag clouds** / **Теги и облака тегов**
- Contains: Create tags, Edit tags, View tag clouds, Manage tag cloud display, Manage tag clouds
- Checking Manage tag clouds auto-checks Manage tag cloud display and disables that checkbox
- Issue tracking no longer lists these five permissions

## Project module

- Project → Settings → Modules shows **Tags and tag clouds**
- Enabled automatically when Issue tracking is enabled
- If the module is turned off, `allowed_to?(:create_tags / :edit_tags / cloud perms)` is false even if the role has them

## No cloud permissions

- Issues sidebar shows only the default Tags cloud
- No custom clouds, including the current user's author-only clouds
- No «Select visible tag clouds» link
- Project → Settings has no Tag Clouds tab
- Direct `/projects/:id/tag_clouds` returns 403

## View tag clouds

- Custom clouds with visibility All / matching Roles appear in the sidebar
- Own author-only cloud appears in the sidebar
- No sort/hide controls and no select modal
- Project → Settings → Tag Clouds is a read-only list (no New / Edit / Delete / drag)
- Author-only clouds are absent from the settings list, including own ones
- Another user's author-only cloud is absent from sidebar and settings
- Direct edit/delete URL of any cloud returns 403
- My account has no «Show untagged issues» checkbox

## Manage tag cloud display

- Select visible tag clouds link is shown
- User can show/hide and reorder allowed custom clouds (and the system cloud)
- Another author's author-only cloud is not in the modal and cannot be revealed by a stored preference
- Own author-only cloud is in the sidebar by default and can be hidden in the modal
- Settings tab appears only if View or Manage tag clouds is also granted
- No «Show untagged issues» in My account and no Untagged column in the modal

## Manage tag clouds

- Includes display management: select modal, personal hide/reorder, system cloud hide
- Create / delete / reorder public and roles clouds in project settings
- Own author-only cloud is listed in project settings with Edit / Delete / drag
- Another user's author-only cloud is not listed and cannot be opened by URL
- My account → Tags shows «Show untagged issues»
- Modal Untagged column and sidebar captions only if that master switch is on
- Losing this permission clears the stored master switch and per-cloud untagged flags

## Author only visibility

- Visible by default checkbox is disabled and forced on
- Saving the form stores both `created_by_id` and `owner_id` as the current user
- Author sees the cloud in the sidebar if they have view, select or manage
- Author with manage keeps Edit / Delete on the project
- Other users never see it, even with all three cloud permissions
- Full Redmine admin who is not the author does not see it on the project (sidebar or settings)

## Full Redmine administrator

- Global plugin settings → Tag Clouds is a flat table sorted by project name, then cloud name
- That list includes author-only clouds
- Admin edits/deletes other authors' owner clouds only from that list (`from=plugin`)
- Direct project edit/delete URL of another author's owner cloud is denied
- Admin who created the cloud is treated as the author on the project
- Admin bypasses project membership for shared clouds
