# 開発での使い方

このカタログで開発エージェントを動かすときの、工程の流れ、GitHub Spec Kit
との併用、そしてテストの規律を仕組みで守らせる方法をまとめます。

## 工程の流れ

入口は `development-lifecycle` です。作業を次の工程に割り当て、担当する
Skill を名指しします。

| 工程 | 主な Skill | 残すもの |
|---|---|---|
| 把握 | `interview-me` | 依頼者が本当に求めていること |
| 仕様 | `brainstorming`、`deliver-acceptance-criteria`、`deliver-edge-cases` | 承認された設計、Given/When/Then の受け入れ基準、境界条件 |
| 設計 | `api-and-interface-design`、`documentation-and-adrs`、`security-and-hardening` | インターフェース、決定記録 |
| 計画 | `writing-plans` | 各タスクと、それを証明するテスト |
| 実装 | `test-driven-development`、`subagent-driven-development` | 失敗を確認してから通したテストとコード |
| 修正 | `systematic-debugging` | 根本原因と、それを再現するテスト |
| 検証 | `verification-before-completion`、`intended-vs-implemented` | 実行したコマンドと結果、仕様との差分 |
| レビュー | `requesting-code-review`、`receiving-code-review` | 指摘と対応 |
| 統合と公開 | `finishing-a-development-branch`、`shipping-and-launch` | マージ、または PR とリリース判断 |

変更の大きさに合わせて工程を省きます。誤字の修正に設計書は要りません。
データモデル、認証、金銭、マイグレーション、公開 API に関わる変更は全工程を
通します。

## 仕様とテストの規則

`development-lifecycle` はすべての工程で次を求めます。

1. コードより先に、期待する振る舞いを書く。
2. 受け入れ基準は検証可能に書く。
3. 各基準を、それを証明するテストに対応づける。
4. テストを先に書き、期待どおりの理由で失敗することを確かめる。
5. テストを消す、飛ばす、期待失敗にする、判定を緩める、スナップショットを
   作り直す、のいずれでも緑にしない。仕様が誤っていたら、依頼者と合意して
   仕様、テスト、コードの順に直す。
6. 不安定なテストは非決定性として原因を突き止める。再実行で緑にしない。
7. テストのないコードを作り直す前に、現在の挙動を写し取るテストを書く。
8. 完了と言う前に、そのセッションでテストを実行し、コマンドと結果を示す。

## GitHub Spec Kit と併用する

リポジトリに `.specify/` があるとき、仕様、計画、タスクの文書は Spec Kit が
持ちます。`development-lifecycle` は工程1と3で Spec Kit のコマンドを使い、
`brainstorming` と `writing-plans` で同じ内容の文書を作りません。

実装、修正、検証、レビューは引き続きこのカタログの Skill が担います。
Spec Kit の constitution に上の「仕様とテストの規則」を書き写すと、Spec Kit
自身の各ステップでも同じ規則が適用されます。

Spec Kit はプロジェクトごとに `specify init` で導入する道具なので、
このカタログには同梱していません。

## テストの規律を仕組みで守らせる

Skill は助言です。エージェントが文脈を失ったり、急いだりすると守られない
ことがあります。重要な規則は、Claude Code の hooks と CI で強制します。

### 終了前にテストを実行する

Claude Code が応答を終えようとするたびにテストを実行し、失敗していれば
終了を止めて結果をエージェントへ返します。`.claude/settings.json` に
次を加えます。

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/require-green.sh" }
        ]
      }
    ]
  }
}
```

`.claude/hooks/require-green.sh` の例です。`npm test` はプロジェクトの
テストコマンドに置き換えます。

```bash
#!/usr/bin/env bash
set -uo pipefail

input="$(cat)"
# このフックで止めた直後の再開では止めない。無限に止め続けるのを防ぐ。
if printf '%s' "${input}" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

if ! output="$(npm test 2>&1)"; then
  {
    printf 'テストが失敗しています。完了と報告する前に原因を直してください。\n'
    printf 'テストを消す、飛ばす、判定を緩めることで通してはいけません。\n\n'
    printf '%s\n' "${output}" | tail -n 60
  } >&2
  exit 2
fi
```

終了コード2で終わると、Claude Code は終了を取りやめ、標準エラーの内容を
エージェントに渡します。テストに時間がかかるプロジェクトでは、ここでは
速いテストだけを実行し、全体は CI に任せます。

### テストを黙らせる変更を止める

テストを飛ばす記法を書き込もうとしたときに、編集そのものを止めます。
`.claude/settings.json` の `hooks` に次を加えます。

```json
{
  "PreToolUse": [
    {
      "matcher": "Edit|MultiEdit|Write",
      "hooks": [
        { "type": "command", "command": "python3 .claude/hooks/no-skipped-tests.py" }
      ]
    }
  ]
}
```

`.claude/hooks/no-skipped-tests.py` の例です。検出する記法は、プロジェクトの
テストフレームワークに合わせて調整します。

```python
#!/usr/bin/env python3
import json
import re
import sys

SKIP_MARKERS = re.compile(
    r"\b(?:it|test|describe)\.(?:skip|todo)\(|\bx(?:it|describe)\("
    r"|@pytest\.mark\.(?:skip|xfail)|\bt\.Skip\(|@Disabled\b|#\[ignore\]"
)

payload = json.load(sys.stdin)
tool_input = payload.get("tool_input", {})
texts = [str(tool_input.get(key, "")) for key in ("new_string", "content")]
texts += [str(edit.get("new_string", "")) for edit in tool_input.get("edits", [])]
new_text = "\n".join(texts)

if SKIP_MARKERS.search(new_text):
    print(
        "テストを飛ばす記法は追加できません。失敗の原因を直すか、"
        "仕様の変更として利用者の承認を得てください。",
        file=sys.stderr,
    )
    sys.exit(2)
```

正当に飛ばす必要があるときは、利用者がこの hook を一時的に外して判断します。

### CI で同じ検査を必須にする

hooks は手元のエージェントにしか効きません。プルリクエストでは CI が
テストを実行し、失敗したらマージできないように、ブランチ保護で必須の
チェックに指定します。CI の設計は `ci-cd-and-automation` が扱います。
