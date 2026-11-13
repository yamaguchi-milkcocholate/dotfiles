#!/usr/bin/env bash
# dotfiles のセットアップ
#   - 設定ファイルをホームディレクトリへシンボリックリンクで配置する
#   - 既存のファイルは ~/.dotfiles-backup/<日時>/ に退避する
#   - mise と sheldon のインストール、ツールとプラグインの取得を行う
# 何度実行しても同じ結果になる（リンク済みのものはスキップする）
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

link() {
  local src="$DOTFILES/$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok      $dst"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP"
    mv "$dst" "$BACKUP/"
    echo "backup  $dst -> $BACKUP/"
  fi
  ln -s "$src" "$dst"
  echo "link    $dst -> $src"
}

echo "== シンボリックリンク =="
link zsh/.zshrc          "$HOME/.zshrc"
link zsh/.zprofile       "$HOME/.zprofile"
link sheldon/plugins.toml "$HOME/.config/sheldon/plugins.toml"
link mise/config.toml    "$HOME/.config/mise/config.toml"

echo "== mise / sheldon =="
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew がありません。先に https://brew.sh の手順でインストールしてください。" >&2
  exit 1
fi
for f in mise sheldon; do
  command -v "$f" >/dev/null 2>&1 || brew install "$f"
done

mise install
sheldon lock

echo
echo "完了しました。新しいターミナルを開くと反映されます。"
echo "このPC専用の設定は次のファイルに書いてください（Git管理外）:"
echo "  ~/.zshrc.local / ~/.zprofile.local / ~/.config/mise/conf.d/local.toml"
