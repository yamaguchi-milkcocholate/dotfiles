#!/bin/bash
# Claude Code の Stop / Notification フックから macOS 通知を出す。
# メインセッション自身の完了・入力待ちだけを通知し、バックグラウンド作業が残る Stop と
# 他エージェント由来の通知(agent_completed / agent_needs_input)は出さない。
in=$(cat)
ev=$(jq -r '.hook_event_name // ""' <<<"$in")
proj=$(basename "$(jq -r '.cwd // ""' <<<"$in")")
sid=$(jq -r '.session_id // ""' <<<"$in")

notify() {
  terminal-notifier -title "$1" -subtitle "$proj" -message "$2" \
    -group "cc-$sid" -activate com.microsoft.VSCode ${3:+-sound "$3"} >/dev/null 2>&1
}

case "$ev" in
Stop)
  n=$(jq '.background_tasks // [] | length' <<<"$in")
  [ "$n" -gt 0 ] && exit 0
  msg=$(jq -r '.last_assistant_message // ""
    | gsub("```[^`]*```"; " ")
    | gsub("[#*`|>]"; "")
    | gsub("\\s+"; " ")
    | ltrimstr(" ")
    | .[0:120]' <<<"$in")
  notify "✅ 完了" "${msg:-応答を終えました}" アブソル
  ;;
Notification)
  t=$(jq -r '.notification_type // ""' <<<"$in")
  m=$(jq -r '.message // ""' <<<"$in")
  case "$t" in
    permission_prompt) notify "🔐 許可待ち" "$m" エーフィ ;;
    idle_prompt)       notify "💤 入力待ち" "$m" ナエトル ;;
    elicitation*)      notify "❓ 質問があります" "$m" ボスコドラ ;;
    *)                 ;;
  esac
  ;;
esac
exit 0
