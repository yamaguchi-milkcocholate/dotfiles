#!/usr/bin/env bash
# claude/mcp.json にある MCP サーバーを、Claude Code のユーザースコープに登録する
#   - mcp.json は sync.sh が ~/.claude.json から自動で書き出す（手で編集しなくてよい）
#   - 登録済みのものはスキップするので、何度実行しても問題ない
#   - 他の PC で削除したサーバーは消さない（不要なら claude mcp remove -s user <名前>）
set -euo pipefail

MCP_JSON="$(cd "$(dirname "$0")" && pwd)/mcp.json"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude コマンドがありません。Claude Code を入れてから再実行してください。" >&2
  exit 1
fi
[ -f "$MCP_JSON" ] || { echo "$MCP_JSON がありません"; exit 0; }

jq -r 'keys[]' "$MCP_JSON" | while IFS= read -r name; do
  if claude mcp get "$name" >/dev/null 2>&1; then
    echo "ok      mcp $name"
  else
    claude mcp add-json -s user "$name" "$(jq -c --arg n "$name" '.[$n]' "$MCP_JSON")" >/dev/null
    echo "add     mcp $name"
  fi
done
