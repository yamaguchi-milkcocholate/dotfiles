# install.sh と claude/sync.sh から読み込む共通の関数
# DOTFILES（リポジトリの絶対パス）を定義してから source すること

BACKUP="${BACKUP:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"

# link <リポジトリ内のパス> <配置先>
#   配置先にシンボリックリンクを作る。既存のファイルは $BACKUP に退避する。
#   リンク済みなら何もしない。
link() {
  local src="$DOTFILES/$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    [ -n "${QUIET:-}" ] || echo "ok      $dst"
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
