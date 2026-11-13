#!/usr/bin/env bash
# Claude Code のユーザー設定（~/.claude）を dotfiles リポジトリと同期する
#
#   sync.sh link     管理しているファイルを ~/.claude などへリンクする（install.sh からも呼ぶ）
#   sync.sh collect  ローカルで増えたもの（スキル、MCP、CLAUDE.md など）をリポジトリへ取り込む
#   sync.sh pull     リモートの変更を取り込んで反映する
#   sync.sh push     ローカルの変更を取り込み、秘密情報を調べてからコミットして push する
#   sync.sh auto     pull と push を続けて行う
#   sync.sh status   取り込み待ちのものと差分を表示する
#
# Claude Code のフック（claude/settings.json）から自動で呼ばれる。
# 失敗したときは macOS の通知で知らせ、ログを ~/.claude/dotfiles-sync.log に残す。
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
REPO_CLAUDE="$DOTFILES/claude"
CLAUDE_HOME="$HOME/.claude"
LOG="$CLAUDE_HOME/dotfiles-sync.log"
# shellcheck source=../lib.sh
source "$DOTFILES/lib.sh"

# ~/.claude 直下で、存在すれば管理するファイルとディレクトリ
TOP_ITEMS=(settings.json CLAUDE.md keybindings.json agents commands output-styles)
# ~/.claude/skills のうち取り込まないもの
#   synced: claude.ai から同期されるスキル
#   *-workspace: skill-creator の評価用の作業フォルダ
#   ~/.agents/skills にあるもの: npx skills などで入れた他人のスキル
is_excluded_skill() {
  local name="$1"
  case "$name" in synced | *-workspace) return 0 ;; esac
  [ -e "$HOME/.agents/skills/$name" ] && return 0
  return 1
}

git_() { git -C "$DOTFILES" "$@"; }

notify_error() {
  echo "エラー: $1" >&2
  command -v terminal-notifier >/dev/null 2>&1 &&
    terminal-notifier -title "⚠️ dotfiles 同期" -message "$1" -group dotfiles-sync >/dev/null 2>&1 || true
}

# 同時に複数のセッションから動かないようにする（10 分以上前のロックは放置されたものとみなす）
LOCK="${TMPDIR:-/tmp}/dotfiles-claude-sync.lock"
lock() {
  if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10)" ]; then rmdir "$LOCK"; fi
  mkdir "$LOCK" 2>/dev/null || { echo "別の同期が実行中のためスキップします"; exit 0; }
  trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
}

cmd_link() {
  for item in "${TOP_ITEMS[@]}"; do
    [ -e "$REPO_CLAUDE/$item" ] && link "claude/$item" "$CLAUDE_HOME/$item"
  done
  for f in "$REPO_CLAUDE"/hooks/*; do
    [ -e "$f" ] && link "claude/hooks/$(basename "$f")" "$CLAUDE_HOME/hooks/$(basename "$f")"
  done
  for d in "$REPO_CLAUDE"/skills/*/; do
    [ -d "$d" ] && link "claude/skills/$(basename "$d")" "$CLAUDE_HOME/skills/$(basename "$d")"
  done
  for f in "$REPO_CLAUDE"/sounds/*.aiff; do
    [ -e "$f" ] && link "claude/sounds/$(basename "$f")" "$HOME/Library/Sounds/$(basename "$f")"
  done
  return 0
}

# adopt <~/.claude 内のパス> <リポジトリ内のパス>
#   ローカルのファイルをリポジトリへ移してリンクに置き換える
adopt() {
  local local_path="$1" repo_rel="$2"
  local repo_path="$DOTFILES/$repo_rel"
  if [ -e "$repo_path" ]; then
    # リポジトリ側に同じものがある場合: 中身が同じならリンクに置き換えるだけ。違えば上書き
    # （Claude Code がリンクをファイルで置き換えた場合も、ローカルの内容を正とする）
    if ! diff -rq "$local_path" "$repo_path" >/dev/null 2>&1; then
      rm -rf "$repo_path"
      cp -R "$local_path" "$repo_path"
    fi
  else
    mkdir -p "$(dirname "$repo_path")"
    cp -R "$local_path" "$repo_path"
  fi
  rm -rf "$local_path"
  ln -s "$repo_path" "$local_path"
  echo "adopt   $local_path -> $repo_path"
}

# ~/.claude.json のユーザースコープの MCP サーバーを claude/mcp.json に書き足す
#   - 追加と更新だけを行い、削除はしない（まだ登録していない PC で消えてしまわないように）
#     不要になったサーバーは mcp.json から手で消す
#   - 環境変数やヘッダーを持つもの（API キーが入りうる）は書き出さない
export_mcp() {
  [ -f "$HOME/.claude.json" ] || return 0
  local skipped tmp
  skipped=$(jq -r '.mcpServers // {} | to_entries[]
    | select(((.value.env // {}) | length) > 0 or ((.value.headers // {}) | length) > 0) | .key' "$HOME/.claude.json")
  [ -n "$skipped" ] && echo "skip    mcp（環境変数かヘッダーを含むため手動で管理）: $(echo $skipped)"
  tmp=$(mktemp)
  [ -f "$REPO_CLAUDE/mcp.json" ] || echo '{}' > "$REPO_CLAUDE/mcp.json"
  jq -S --slurpfile repo "$REPO_CLAUDE/mcp.json" '$repo[0] + (.mcpServers // {}
    | with_entries(select(((.value.env // {}) | length) == 0 and ((.value.headers // {}) | length) == 0))
    | map_values(del(.env, .headers)))' "$HOME/.claude.json" > "$tmp"
  if ! cmp -s "$tmp" "$REPO_CLAUDE/mcp.json"; then
    mv "$tmp" "$REPO_CLAUDE/mcp.json"
    echo "export  mcp -> claude/mcp.json"
  else
    rm -f "$tmp"
  fi
}

cmd_collect() {
  local item name path
  for item in "${TOP_ITEMS[@]}"; do
    path="$CLAUDE_HOME/$item"
    if [ -e "$path" ] && [ ! -L "$path" ]; then adopt "$path" "claude/$item"; fi
  done
  for path in "$CLAUDE_HOME"/hooks/*.sh; do
    if [ -f "$path" ] && [ ! -L "$path" ]; then adopt "$path" "claude/hooks/$(basename "$path")"; fi
  done
  for path in "$CLAUDE_HOME"/skills/*/; do
    path="${path%/}"
    name="$(basename "$path")"
    [ -L "$path" ] && continue
    is_excluded_skill "$name" && continue
    [ -f "$path/SKILL.md" ] || continue
    adopt "$path" "claude/skills/$name"
  done
  export_mcp
}

changed_files() { git_ status --porcelain -- claude/; }

cmd_pull() {
  local before after
  before=$(git_ rev-parse HEAD)
  if ! git_ pull --rebase --autostash --quiet; then
    git_ rebase --abort >/dev/null 2>&1 || true
    notify_error "git pull に失敗しました。~/dotfiles で手動で解決してください"
    return 1
  fi
  after=$(git_ rev-parse HEAD)
  [ "$before" = "$after" ] && return 0
  echo "pull    $before..$after"
  QUIET=1 cmd_link
  if git_ diff --name-only "$before" "$after" | grep -qx 'claude/mcp.json' && command -v claude >/dev/null 2>&1; then
    "$REPO_CLAUDE/setup-mcp.sh"
  fi
}

cmd_push() {
  cmd_collect
  if [ -z "$(changed_files)" ]; then
    # コミット済みで未 push のものがあれば送る
    if [ -n "$(git_ log --oneline '@{u}..' 2>/dev/null)" ]; then git_ push --quiet; fi
    return 0
  fi

  git_ add -- claude/
  local files=()
  while IFS= read -r -d '' f; do files+=("$DOTFILES/$f"); done \
    < <(git_ diff --cached --name-only --diff-filter=ACMR -z -- claude/)
  if [ ${#files[@]} -gt 0 ] && ! "$REPO_CLAUDE/check-secrets.sh" "${files[@]}"; then
    git_ reset --quiet -- claude/
    notify_error "秘密情報の可能性があるため push を止めました。~/dotfiles/claude を確認してください"
    return 1
  fi

  local summary
  summary=$(git_ diff --cached --name-status -- claude/ | sed 's/^/  /')
  git_ commit --quiet -m "claude: ユーザー設定を同期" -m "$summary" -- claude/
  echo "commit"
  echo "$summary"
  cmd_pull
  if ! git_ push --quiet; then
    notify_error "git push に失敗しました。~/dotfiles で git push してください"
    return 1
  fi
  echo "push"
}

cmd_status() {
  echo "== 取り込み待ち（push 時に自動で取り込まれます） =="
  local item path name
  for item in "${TOP_ITEMS[@]}"; do
    path="$CLAUDE_HOME/$item"
    [ -e "$path" ] && [ ! -L "$path" ] && echo "  $path"
  done
  for path in "$CLAUDE_HOME"/hooks/*.sh "$CLAUDE_HOME"/skills/*/; do
    path="${path%/}"
    name="$(basename "$path")"
    [ -e "$path" ] && [ ! -L "$path" ] || continue
    case "$path" in */skills/*) is_excluded_skill "$name" && continue; [ -f "$path/SKILL.md" ] || continue ;; esac
    echo "  $path"
  done
  echo "== リポジトリの差分 =="
  changed_files
}

main() {
  local cmd="${1:-status}"
  case "$cmd" in
    link) cmd_link ;;
    status) cmd_status ;;
    collect | pull | push | auto)
      lock
      {
        echo "--- $(date '+%F %T') $cmd"
        case "$cmd" in
          collect) cmd_collect ;;
          pull) cmd_pull ;;
          push) cmd_push ;;
          auto) cmd_pull && cmd_push ;;
        esac
      } 2>&1 | tee -a "$LOG"
      return "${PIPESTATUS[0]}"
      ;;
    *) echo "使い方: $0 {link|collect|pull|push|auto|status}" >&2; return 2 ;;
  esac
}

main "$@"
