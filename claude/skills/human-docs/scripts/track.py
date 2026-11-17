#!/usr/bin/env python3
"""human-docs スキルで書いた文書を覚えておき、ユーザーが手で直したことに気づくための道具。

使い方:
  track.py add <ファイル>...   文書を登録する。今の中身を「スキルが書いた状態」として覚える
                               learn を終えた後にも呼ぶ
  track.py diff <ファイル>     覚えた状態と、今の中身の差分を出す
  track.py list                登録してある文書と、変わっているかどうかを出す
  track.py check --hook        フック用。変わっている文書があれば Claude に知らせる
  track.py touch --hook        フック用。Claude が登録済みの文書を編集したら、覚えた状態を更新する

状態は ~/.claude/human-docs/ に置く。文書の写しを含むので、dotfiles には入れない。
"""

from __future__ import annotations

import difflib
import hashlib
import json
import sys
from datetime import date
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / "human-docs"
STATE_FILE = STATE_DIR / "state.json"
BASE_DIR = STATE_DIR / "base"
SKILL_DIR = Path(__file__).resolve().parent.parent


def load() -> dict:
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    return {}


def save(state: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(STATE_FILE)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def base_path(key: str) -> Path:
    return BASE_DIR / (hashlib.sha256(key.encode()).hexdigest()[:24] + ".txt")


def remember(state: dict, path: Path) -> None:
    key = str(path)
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    base_path(key).write_bytes(path.read_bytes())
    state[key] = {"hash": digest(path), "date": date.today().isoformat(), "pending": False}


def changed(state: dict) -> list[str]:
    """登録済みで、覚えた状態から中身が変わっている文書。消えた文書は登録から外す。"""
    result = []
    for key in list(state):
        path = Path(key)
        if not path.is_file():
            base_path(key).unlink(missing_ok=True)
            del state[key]
            continue
        if digest(path) != state[key]["hash"]:
            result.append(key)
    return result


def hook_input() -> dict:
    try:
        return json.load(sys.stdin)
    except Exception:
        return {}


def cmd_add(files: list[str]) -> int:
    state = load()
    for f in files:
        path = Path(f).expanduser().resolve()
        if not path.is_file():
            print(f"ファイルがない: {path}", file=sys.stderr)
            return 1
        remember(state, path)
        print(f"登録した: {path}")
    save(state)
    return 0


def cmd_diff(f: str) -> int:
    path = Path(f).expanduser().resolve()
    key = str(path)
    state = load()
    if key not in state:
        print(f"登録されていない: {path}", file=sys.stderr)
        return 1
    before = base_path(key).read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    after = path.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    sys.stdout.writelines(difflib.unified_diff(before, after, "スキルが書いた状態", "今の中身"))
    return 0


def cmd_list() -> int:
    state = load()
    diff = set(changed(state))
    save(state)
    for key, entry in state.items():
        mark = "変わっている" if key in diff else "同じ"
        print(f"{mark}\t{entry['date']}\t{key}")
    return 0


def cmd_check() -> int:
    data = hook_input()
    event = data.get("hook_event_name", "UserPromptSubmit")
    cwd = data.get("cwd") or str(Path.cwd())
    state = load()
    # 今のプロジェクトの下にある文書だけを見る
    targets = [k for k in changed(state) if k == cwd or k.startswith(cwd.rstrip("/") + "/")]
    # 同じ変更は、同じセッションの中で 2 度は知らせない。セッションの最初には、残っているものを全部知らせる
    if event != "SessionStart":
        targets = [k for k in targets if state[k].get("pending") != digest(Path(k))]
    for key in targets:
        state[key]["pending"] = digest(Path(key))
    save(state)
    if not targets:
        return 0
    script = SKILL_DIR / "scripts" / "track.py"
    lines = "\n".join(f"- {k}" for k in targets)
    message = (
        "human-docs スキルで書いた次の文書が、その後で書き換えられている。"
        "ユーザーが手で直した可能性が高い。\n"
        f"{lines}\n"
        "ユーザーの今の依頼を先にこなしたうえで、同じ返答の中で human-docs スキルの learn を実行すること"
        "（Skill ツールで human-docs を読み、learn の手順に従う）。ユーザーに learn の指定を求めない。\n"
        f"差分は `python3 {script} diff <ファイル>` で取る。"
    )
    print(json.dumps(
        {"hookSpecificOutput": {"hookEventName": event, "additionalContext": message}},
        ensure_ascii=False,
    ))
    return 0


def cmd_touch() -> int:
    data = hook_input()
    f = (data.get("tool_input") or {}).get("file_path")
    if not f:
        return 0
    path = Path(f).expanduser().resolve()
    key = str(path)
    state = load()
    entry = state.get(key)
    if entry is None or not path.is_file():
        return 0
    # ユーザーの直しをまだ取り込んでいない間は、覚えた状態を更新しない（差分が消えるため）
    if entry.get("pending"):
        return 0
    remember(state, path)
    save(state)
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, rest = argv[1], argv[2:]
    try:
        if cmd == "add" and rest:
            return cmd_add(rest)
        if cmd == "diff" and len(rest) == 1:
            return cmd_diff(rest[0])
        if cmd == "list":
            return cmd_list()
        if cmd == "check":
            return cmd_check()
        if cmd == "touch":
            return cmd_touch()
    except Exception as e:  # フックで失敗しても、ユーザーの作業を止めない
        print(f"human-docs track.py: {e}", file=sys.stderr)
        return 0 if "--hook" in rest else 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
