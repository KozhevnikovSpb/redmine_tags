# TEST v0.0.6 - Tag colors

Target: Redmine 7.0.0 / Ruby 3.4 / Rails 8.1  
Plugin ID: `:redmineup_tags`

## What changed

- Admin Edit / Merge tag: pastel swatch grid + native `input type=color` + hex field + Auto
- Stored `tags.color` is shown as-is on chips (no mute)
- Empty color still uses MD5(name) + mute (slightly less white than 0.0.5)
- Field name stays `tag[color]`, format `#rrggbb` (Q&A compatible)

## Automated

```bash
bundle exec rake redmine:plugins:test NAME=redmineup_tags RAILS_ENV=test
```

Covered in `test/unit/tag_color_test.rb` and `test/functional/tags_controller_test.rb`.

## Manual

1. Administration → Plugins → Tags → Manage tags → Edit a tag.
2. Confirm RedmineUP colorPicker grid is gone.
3. Pick a pastel swatch, save, open an issue with that tag: chip matches the swatch, not a washed version.
4. Open native color control, pick any RGB, save: chip uses that hex.
5. Click Auto, save: `tags.color` empty; chip is muted MD5 color.
6. Merge two tags and set a palette color; surviving tag keeps `#rrggbb`.
7. Q&A tag chips still read `tags.color` if that plugin is installed.
8. Ctrl+F5 after deploy so `tag_color_picker.js` loads.
