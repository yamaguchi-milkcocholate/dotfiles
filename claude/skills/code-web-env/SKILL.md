---
name: code-web-env
description: リポジトリを「ローカル(Mac / VS Code + Claude Code)」と「リモート(Claude Code on the web / スマホの Claude アプリから)」の両方から扱える状態に整える。Git(GitHub)を唯一の同期手段とし、作業開始時の pull・終了時の commit/push、Web 側はブランチ + PR で合流、競合時の扱い、コミット履歴による引き継ぎの運用ルールを CLAUDE.md に書き込み、GitHub リモートの用意と Web 側の設定手順の案内まで行う。「スマホからも作業を続けられるようにして」「Claude Code on the web でも使えるようにして」「ローカルとスマホの両方から触れるようにしたい」等の依頼で使う。
---

# ローカル + Web(スマホ)の両対応セットアップ

ローカルとクラウドのどちらでも同じリポジトリを触り、**Git を介して常に同じ状態に追いつく**ための整備を行う。
ルールはリポジトリ内の `CLAUDE.md` に書くので、Web 側のセッションでもリポジトリを開くだけで同じ運用が効く(このスキル自体は Web 側に無くてよい。クラウドセッションはローカルの `~/.claude` を読まない)。

## 手順

```
1. 現状確認
2. 方針の確認(ユーザーへの質問はここだけ)
3. Git / リモートの用意
4. CLAUDE.md に運用ルールを書き込む
5. .gitignore を整える
6. commit / push して結果を報告
```

---

## 1. 現状確認

対象ディレクトリ(指定がなければカレント)で以下をまとめて確認する。

- `git rev-parse --is-inside-work-tree` — Git 管理下か
- `git remote -v` — リモートがあるか。**GitHub 以外なら Web 側は使えない**ので、2 でその旨を伝える
- `git status` / `git log --oneline -10` — 未コミットの変更・履歴の有無。既存の未コミット変更はこのスキルでは commit しない
- `git branch --show-current` — 現在のブランチ名(既存リポジトリのブランチ名は変えない)
- `CLAUDE.md` の有無と内容。`## マルチ環境運用` 見出しが既にあれば、このスキルは適用済み
- `.gitignore` の有無
- `gh auth status` — リモート作成や `/web-setup` に使えるか
- README や主要ファイル — プロジェクトの一言説明を推測する材料

## 2. 方針の確認

確認結果を踏まえ、AskUserQuestion で **決まっていないことだけ** を一度にまとめて聞く。以降の手順では質問しない。聞く候補:

- **リモート**: 無い場合、`gh repo create` で作るか(既定は private)、既存 URL を使うか。`gh` が未ログインなら、ユーザーに `! gh auth login` を実行してもらうか、既存 URL を使うかの二択にする
- **プロジェクト説明**: 1 で推測できなかった場合のみ。推測できたなら確認不要
- **適用済みの場合**: `## マルチ環境運用` が既にあるなら、最新テンプレートで差し替えるか、何もしないか

既に答えが分かるものは聞かない。

## 3. Git / リモートの用意

- Git 管理外なら `git init -b main`(Git 2.28 未満なら `git init` 後に `git checkout -b main`)
- リモートを新規作成する場合: `gh repo create <名前> --private --source=. --remote=origin`
  - 名前の既定はディレクトリ名。既に同名がある場合は作らずユーザーに報告する
  - **公開(public)にするのは明示された場合だけ**
- 既存 URL を使う場合: `git remote add origin <URL>` の後 `git fetch origin` し、リモートに既に履歴があれば統合方法をユーザーに確認する(force push で上書きしない)

## 4. CLAUDE.md に運用ルールを書き込む

`templates/CLAUDE.md.template`(このスキルと同じディレクトリ)を読み、プレースホルダを置換する。

- `{{PROJECT_DESCRIPTION}}`: プロジェクトの一言説明
- `{{REMOTE_URL}}`: `git remote get-url origin` の値

書き込み方:

- **CLAUDE.md が無い**: テンプレート全体で新規作成する
- **CLAUDE.md がある(未適用)**: 既存の内容は消さず、テンプレートの `## マルチ環境運用` 以降だけを末尾に追記する(H1 と説明文は追記しない)
- **適用済みで差し替えを選んだ**: `## マルチ環境運用` から次の `## `(同じ階層の見出し)の直前までを、テンプレートの同じ範囲で置き換える

## 5. .gitignore を整える

無ければ作り、以下が含まれていなければ追記する(既存の行は消さない)。

```
.DS_Store
.claude/settings.local.json
CLAUDE.local.md
```

## 6. commit / push して報告

- **このスキルで作成・変更したファイルだけ** を指定して `git add` し(`git add -A` や `git add .` は使わない)、何をなぜ整備したか分かるメッセージで commit する
- `git push -u origin <branch>`。拒否されたら `git pull --rebase` してから再 push する。コンフリクトしたら解決せずユーザーに報告する。force push はしない
- 報告は短く、**ユーザーが次に何をすればよいか** が一目で分かる形にする。選択肢の併記や仕組みの説明はしない。含めるもの:
  - 作成・変更したファイルとリモート URL(箇条書き数行)
  - 1 で見つけた未コミットの変更を commit していないこと(あった場合のみ)
  - 「次にやること」(下記の型をそのまま使う)

### 「次にやること」の型

```
## 次にやること

**まだ一度も `/web-setup` を実行していない場合だけ**(実行済みならスキップ)
- この Claude Code で `/web-setup` を実行する

**スマホで作業するとき**
1. Claude アプリの Code タブを開き、<リポジトリ名> を選ぶ
2. 作業を頼む(終わると作業ブランチが push され、PR が作られる。作られていなければ差分画面の **Create PR** で作る)
3. GitHub で PR をマージする

**Mac に戻ったとき**
- `git pull --rebase` で取り込む
```

- `/web-setup` は一度実行すれば gh で見える全リポジトリに効く(出典: https://code.claude.com/docs/en/web-quickstart )。gh が未ログインで `/web-setup` が使えない場合だけ、先に `! gh auth login` を案内する
- Web 側の変更を PR で合流させるのは、ローカルとの競合を避けるための運用上の方針で、技術的な制約ではない。クラウドの GitHub プロキシはブランチの削除とタグなどブランチ以外の push を拒否するが、push 先のブランチは制限しない("It doesn't limit which branches a push can update." 出典: https://code.claude.com/docs/en/cloud-environments#github-proxy 、2026-10-06 確認)。制限したい場合は GitHub のブランチ保護ルールを使う。リポジトリごとに別のブランチ運用(検証ブランチに Web からも直接 push する等)を決めた場合は、そちらを優先する
- Web 側のコミット作者名は未確認。報告には書かず、聞かれたら答える
