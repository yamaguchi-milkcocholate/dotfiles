# dotfiles

zsh・sheldon・mise の設定です。

| パス | 配置先 | 内容 |
|---|---|---|
| `zsh/.zprofile` | `~/.zprofile` | PATH の設定（Homebrew、`~/.local/bin`、mise の shims） |
| `zsh/.zshrc` | `~/.zshrc` | 対話シェルの設定（mise、プラグイン、補完） |
| `sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | zsh プラグインの定義 |
| `mise/config.toml` | `~/.config/mise/config.toml` | どの PC でも使うツールとバージョン |

## 新しい Mac でのセットアップ

### 1. 前提ツールを入れる

```sh
xcode-select --install   # git などの開発ツール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. dotfiles を取得して配置する

```sh
eval "$(/opt/homebrew/bin/brew shellenv)"
git clone https://github.com/yamaguchi-milkcocholate/dotfiles.git ~/dotfiles   # GitHub へのログインは不要
~/dotfiles/install.sh
```

`install.sh` が行うこと:
- 上の表のとおりシンボリックリンクを作る（既存のファイルは `~/.dotfiles-backup/<日時>/` に退避する）
- mise と sheldon を Homebrew で入れる
- `mise install`（node、terraform、uv）と `sheldon lock`（プラグイン）を実行する

何度実行しても問題ありません。

### 3. 新しいターミナルを開いて仕上げる

```sh
uv python install 3.11 --default        # `python` / `python3` コマンドを用意する
curl -fsSL https://claude.ai/install.sh | bash   # Claude Code（公式インストーラー）
```

## PC ごとの設定（Git 管理外）

PC ごとに違う設定は、次のファイルに書きます。ファイルがあれば自動で読み込まれます。

| ファイル | 用途の例 |
|---|---|
| `~/.zshrc.local` | その PC だけで使うコマンドの設定、エイリアス |
| `~/.zprofile.local` | その PC だけの PATH や環境変数 |
| `~/.config/mise/conf.d/local.toml` | その PC だけで使うツール（`"npm:パッケージ名" = "latest"` など） |

**このリポジトリは公開しています。API キーやトークン、社内の情報はコミットせず、これらのファイルに書いてください。**

## 日々の操作

| やりたいこと | コマンド |
|---|---|
| どの PC でも使うツールを追加する | `mise use -g <ツール>@<バージョン>`（`mise/config.toml` が更新される） |
| プロジェクトでツールのバージョンを固定する | プロジェクトのフォルダで `mise use <ツール>@<バージョン>` |
| プラグインを追加する | `sheldon/plugins.toml` を編集して `sheldon lock` |
| プラグインを更新する | `sheldon lock --update` |
| ツールを更新する | `mise upgrade` |

Python のバージョンとパッケージは uv で管理します（`uv sync`、`uv run` など）。mise では Python を管理しません。
