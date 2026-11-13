# ログインシェルの起動時に1回だけ実行する設定（主にPATHの設定）

typeset -U path PATH  # PATHの重複を自動で取り除く

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# ~/.local/bin（Claude Code、uv tool で入れたコマンドなど）
export PATH="$HOME/.local/bin:$PATH"

# mise: IDEやスクリプトなど、対話シェル以外からもmiseで入れたツールを使えるようにする
eval "$(mise activate zsh --shims)"

# このPC専用の設定（Git管理外）
[[ -f ~/.zprofile.local ]] && source ~/.zprofile.local
