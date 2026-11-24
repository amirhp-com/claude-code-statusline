#!/bin/bash
# curl -fsSL https://raw.githubusercontent.com/amirhp-com/claude-code-statusline/main/install.sh | bash
# Options go after "bash -s --", for example: ... | bash -s -- --jalali --plan-ends 2026-12-20
main() {
  set -e
  local base="${STATUSLINE_SOURCE:-https://raw.githubusercontent.com/amirhp-com/claude-code-statusline/main}"
  local config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local target="$config/claude-code-statusline.sh"
  [ "$(uname)" = Darwin ] || { echo "This status line is for macOS." >&2; exit 1; }
  command -v jq >/dev/null || { echo "jq is missing, run: brew install jq" >&2; exit 1; }
  mkdir -p "$config"
  curl -fsSL "$base/statusline.sh" -o "$target.new"
  bash -n "$target.new"
  chmod 755 "$target.new"
  mv "$target.new" "$target"
  "$target" install "$@"
}
main "$@"
