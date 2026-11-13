#!/usr/bin/env bash
# dotfiles のセットアップ
#   - 設定ファイルをホームディレクトリへシンボリックリンクで配置する
#   - 既存のファイルは ~/.dotfiles-backup/<日時>/ に退避する
#   - mise と sheldon のインストール、ツールとプラグインの取得を行う
# 何度実行しても同じ結果になる（リンク済みのものはスキップする）
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

source "$DOTFILES/lib.sh"

echo "== シンボリックリンク =="
link zsh/.zshrc          "$HOME/.zshrc"
link zsh/.zprofile       "$HOME/.zprofile"
link sheldon/plugins.toml "$HOME/.config/sheldon/plugins.toml"
link mise/config.toml    "$HOME/.config/mise/config.toml"

echo "== Claude Code =="
# ~/.claude にはキャッシュや会話履歴も入るため、管理するものだけを個別にリンクする
"$DOTFILES/claude/sync.sh" link

echo "== Git フック =="
# コミット前に秘密情報が含まれていないかを調べる（githooks/pre-commit）
git -C "$DOTFILES" config core.hooksPath githooks
echo "ok      core.hooksPath = githooks"

echo "== Homebrew =="
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew がありません。先に https://brew.sh の手順でインストールしてください。" >&2
  exit 1
fi
# terminal-notifier と jq は Claude Code の通知フック（claude/hooks/notify.sh）で使う
for f in mise sheldon terminal-notifier jq; do
  command -v "$f" >/dev/null 2>&1 || brew install "$f"
done

mise install
sheldon lock

if command -v claude >/dev/null 2>&1; then
  echo "== Claude Code の MCP =="
  "$DOTFILES/claude/setup-mcp.sh"
fi

echo
echo "完了しました。新しいターミナルを開くと反映されます。"
echo "このPC専用の設定は次のファイルに書いてください（Git管理外）:"
echo "  ~/.zshrc.local / ~/.zprofile.local / ~/.config/mise/conf.d/local.toml"
