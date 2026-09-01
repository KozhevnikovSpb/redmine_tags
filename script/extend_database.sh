#!/usr/bin/env bash
# Create/extend plugin tables that are not part of tag_cloud_preferences.
# Usage from Redmine root or from this script:
#   RAILS_ENV=production plugins/redmine_tags/script/extend_database.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REDMINE_ROOT="${REDMINE_ROOT:-$(cd "$PLUGIN_DIR/../.." && pwd)}"
export RAILS_ENV="${RAILS_ENV:-production}"

cd "$REDMINE_ROOT"
echo "Redmine: $REDMINE_ROOT"
echo "Plugin:  $PLUGIN_DIR"
echo "Env:     $RAILS_ENV"

bundle exec rake redmineup_tags:ensure_user_prefs
bundle exec rake redmine:plugins:migrate NAME=redmineup_tags
