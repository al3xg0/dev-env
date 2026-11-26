#!/usr/bin/env zsh
# Re-vendors the skills listed in mattpocock/skills' plugin.json into claude/skills/.
set -euo pipefail
root="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone -q --depth 1 https://github.com/mattpocock/skills "$tmp/skills"
cd "$tmp/skills"
for p in $(python3 -c "import json;print('\n'.join(json.load(open('.claude-plugin/plugin.json'))['skills']))"); do
  n="$(basename "$p")"
  rm -rf "$root/claude/skills/$n"
  cp -r "$p" "$root/claude/skills/$n"
  echo "updated $n"
done
cp LICENSE "$root/claude/third-party/mattpocock-skills/LICENSE"
sed -i '' "s/^Commit: .*/Commit: $(git rev-parse HEAD)/" "$root/claude/third-party/mattpocock-skills/README.md"
echo "Done. Review with: git -C \"$root\" diff --stat"
