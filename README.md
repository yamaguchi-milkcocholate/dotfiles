# dotfiles

zsh・sheldon・mise・Claude Code の設定です。

| パス | 配置先 | 内容 |
|---|---|---|
| `zsh/.zprofile` | `~/.zprofile` | PATH の設定（Homebrew、`~/.local/bin`、mise の shims） |
| `zsh/.zshrc` | `~/.zshrc` | 対話シェルの設定（mise、プラグイン、補完） |
| `sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | zsh プラグインの定義 |
| `mise/config.toml` | `~/.config/mise/config.toml` | どの PC でも使うツールとバージョン |
| `claude/settings.json` | `~/.claude/settings.json` | Claude Code の設定（許可ルール、フック、プラグイン、言語など） |
| `claude/hooks/notify.sh` | `~/.claude/hooks/notify.sh` | 完了・入力待ちを macOS の通知で知らせるフック |
| `claude/skills/<名前>/` | `~/.claude/skills/<名前>/` | 自作のスキル |
| `claude/sounds/*.aiff` | `~/Library/Sounds/` | 通知音 |
| `claude/mcp.json` | （`setup-mcp.sh` で登録） | ユーザースコープの MCP サーバー |
| `claude/sync.sh` | （フックから自動で実行） | `~/.claude` とこのリポジトリの同期 |

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
- mise・sheldon・terminal-notifier・jq を Homebrew で入れる
- `mise install`（node、terraform、uv）と `sheldon lock`（プラグイン）を実行する
- Claude Code が入っていれば `claude/setup-mcp.sh` で MCP サーバーを登録する

何度実行しても問題ありません。

### 3. 新しいターミナルを開いて仕上げる

```sh
uv python install 3.11 --default        # `python` / `python3` コマンドを用意する
curl -fsSL https://claude.ai/install.sh | bash   # Claude Code（公式インストーラー）
~/dotfiles/claude/setup-mcp.sh                   # MCP サーバーを登録する
```

Claude Code を起動してログインすると、`settings.json` のプラグインはマーケットプレイスから自動で入ります。

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

## Claude Code の設定の同期

Claude Code のユーザー設定は、Claude Code のフック（`claude/settings.json`）から `claude/sync.sh` が自動で同期します。普段は何もしなくてよいです。

| いつ | 何をするか |
|---|---|
| セッションの開始時 | pull して反映し、取りこぼした変更があれば push する |
| 設定・スキルの変更時、応答のたび、セッションの終了時 | 変更があればコミットして push する |

push の前に次のものを自動で取り込みます。

- `~/.claude/skills/` に新しく作ったスキル（リポジトリへ移してリンクに置き換える）
- `~/.claude/CLAUDE.md`、`keybindings.json`、`agents/`、`commands/`、`output-styles/`、`hooks/*.sh`
- `claude mcp add -s user` で追加した MCP サーバー（`claude/mcp.json` へ書き足す）
- Claude Code がリンクを普通のファイルで置き換えてしまった場合は、その内容を取り込んでリンクに戻す

取り込まないもの:

- claude.ai から同期されるスキル（`skills/synced`）
- `~/.agents/skills` から入れたスキル
- 名前が `-workspace` で終わるフォルダ（skill-creator の作業用）
- 環境変数やヘッダーを持つ MCP サーバー（API キーが入りうるため）

### 公開してはいけない情報が入ったとき

コミットの前に `claude/check-secrets.sh` が、ホームディレクトリの絶対パス、API キーやトークンの形をした文字列、`autoMode.environment` を探します。見つかったらコミットも push もせず、macOS の通知で知らせます。手でコミットするときも Git の pre-commit フックで同じチェックが動きます。

通知が出たら、`~/dotfiles/claude` の該当箇所を消すか、そのプロジェクトの `.claude/settings.json` に移してください。

### 手で操作するとき

| やりたいこと | コマンド |
|---|---|
| 取り込み待ちと差分を見る | `~/dotfiles/claude/sync.sh status` |
| すぐに同期する | `~/dotfiles/claude/sync.sh auto` |
| 同期の記録を見る | `tail ~/.claude/dotfiles-sync.log` |
| MCP サーバーをやめる | `claude mcp remove -s user <名前>` を各 PC で行い、`claude/mcp.json` からも消す |

### Claude Code で管理しないもの

`~/.claude` のうち上に書いたもの以外（会話履歴、キャッシュ、memory など）と `~/.claude.json`（ログイン情報を含む）は管理しません。

特定のプロジェクトにだけ関係する設定（auto mode の環境情報や、そのプロジェクトのパスを含む許可ルールなど）は、`settings.json` ではなくそのプロジェクトの `.claude/settings.json` に書いてください。このリポジトリは公開しています。
