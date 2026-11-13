# 対話シェル（ターミナル）を開いたときに読み込む設定

# mise: フォルダごとにツールのバージョンを切り替える
eval "$(mise activate zsh)"

# zshプラグイン（定義は ~/.config/sheldon/plugins.toml）
eval "$(sheldon source)"

# history-substring-search: 途中まで入力した文字列で、↑↓キーで履歴を検索する
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down

# terraformのコマンド補完
if command -v terraform >/dev/null 2>&1; then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C "$(command -v terraform)" terraform
fi

# このPC専用の設定（Git管理外）
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
