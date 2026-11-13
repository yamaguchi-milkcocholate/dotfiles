#!/usr/bin/env bash
# 公開リポジトリに入れてはいけない情報が含まれていないかを調べる
#   使い方: check-secrets.sh <ファイル>...
#   見つかったら内容を表示して終了コード 1 を返す（pre-commit と sync.sh から呼ばれる）
set -uo pipefail

PATTERNS=(
  '/Users/[^/"[:space:]]+'             # ホームディレクトリの絶対パス（ユーザー名やプロジェクト名が出る）
  'sk-ant-[A-Za-z0-9_-]{10,}'          # Anthropic API キー
  'gh[pousr]_[A-Za-z0-9]{20,}'         # GitHub トークン
  'github_pat_[A-Za-z0-9_]{20,}'
  'xox[abprs]-[A-Za-z0-9-]{10,}'       # Slack トークン
  'AKIA[0-9A-Z]{16}'                   # AWS アクセスキー
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
)

found=0
for f in "$@"; do
  [ -f "$f" ] || continue
  # このスクリプト自体はパターンを含むので対象外
  [ "$(basename "$f")" = "check-secrets.sh" ] && continue
  # バイナリ（通知音など）は対象外
  if ! grep -Iq . "$f" 2>/dev/null; then continue; fi
  for p in "${PATTERNS[@]}"; do
    if hits=$(grep -nE -e "$p" "$f"); then
      echo "秘密情報の可能性: $f"
      echo "$hits" | sed 's/^/    /'
      found=1
    fi
  done
  # auto mode の環境情報はプロジェクト固有の内容が入るため、ユーザー設定には置かない
  # （/auto-mode-setup は承認すると必ず ~/.claude/settings.json に書き込む。
  #   autoMode はプロジェクトの .claude/settings*.json からは読まれないので、移しても効かない）
  case "$f" in
    *settings.json)
      if jq -e '.autoMode.environment // empty' "$f" >/dev/null 2>&1; then
        echo "秘密情報の可能性: $f に autoMode.environment があります（/auto-mode-setup が書き込んだものです。claude auto-mode reset で消すか、必要なら claude --settings <ファイル> で読み込んでください）"
        found=1
      fi
      ;;
  esac
done
exit $found
