#!/usr/bin/env bash
# Idempotent schema extension: create missing plugin tables, never drop data.
# Called from deploy or by hand:
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

bundle exec rake redmineup_tags:ensure_tables
bundle exec rake redmine:plugins:migrate NAME=redmineup_tags
