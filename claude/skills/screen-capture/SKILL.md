---
name: screen-capture
description: macOSの画面をキャプチャしてClaude Codeが視覚的に確認するスキル。ユーザーの画面状態を確認したいとき、3DCGの品質チェック、GUIアプリの操作確認、エラー画面の確認など、画面の視覚情報が必要なあらゆる場面で使用する。「画面を見て」「画面確認して」「今の状態を見て」等のリクエストで発動すること。
---

## 概要

macOSの`screencapture`コマンドでユーザーの画面をキャプチャし、Claude Codeが画像として読み取る。手動でスクリーンショットを保存・共有する手間を省き、Claude Codeが自発的に画面を確認できる。

## 前提条件

- macOS
- Claude Codeを実行しているターミナルアプリに「画面収録」権限が付与済み
  - システム設定 → プライバシーとセキュリティ → 画面収録 で設定
- 権限がない場合、`screencapture`は`could not create image from display`エラーを返す

## 使い方

### 基本: 画面全体をキャプチャ

```bash
screencapture -x /tmp/claude_screen.png
```

その後、Readツールで画像を確認:

```
Read /tmp/claude_screen.png
```

### オプション

| オプション | コマンド | 用途 |
|-----------|---------|------|
| 画面全体 | `screencapture -x /tmp/claude_screen.png` | デフォルト。最も汎用的 |
| 特定ウィンドウ | `screencapture -x -l$(osascript -e 'tell app "Blender" to id of window 1') /tmp/claude_screen.png` | 特定アプリのウィンドウのみ |
| 複数ディスプレイ | `screencapture -x /tmp/screen1.png /tmp/screen2.png` | ディスプレイごとに別ファイル |
| 低解像度（高速） | `screencapture -x -r /tmp/claude_screen.png` | Retina解像度を使わない（ファイルサイズ削減） |

### `-x` フラグ

`-x`はシャッター音を無効にする。常に付けること。

## 使用場面

### 1. ユーザーが「画面を見て」と言ったとき
```bash
screencapture -x /tmp/claude_screen.png
# → Read /tmp/claude_screen.png で確認
```

### 2. bpyスクリプト実行後のBlender画面確認
```bash
# スクリプト実行
scripts/run_blender.sh some_script.py
# 少し待ってからキャプチャ（Blenderのビューポート更新を待つ）
sleep 2 && screencapture -x /tmp/claude_screen.png
# → Read で品質チェック
```

### 3. エラー画面の確認
```bash
screencapture -x /tmp/claude_screen.png
# → Read でエラーメッセージを読み取り、原因を診断
```

### 4. GUIアプリの操作ガイド
```bash
screencapture -x /tmp/claude_screen.png
# → Read で現在のUI状態を確認し、次の操作を案内
```

## 注意事項

- キャプチャ画像にはパスワードや個人情報が映り込む可能性がある。ユーザーが画面を見せる意図を示した場合のみ使用すること
- Retina displayでは画像サイズが大きくなる。頻繁にキャプチャする場合は`-r`オプションで低解像度にすることを検討
- `/tmp/claude_screen.png`は毎回上書きされる。履歴が必要な場合はタイムスタンプ付きファイル名を使う:
  ```bash
  screencapture -x "/tmp/claude_screen_$(date +%Y%m%d_%H%M%S).png"
  ```
