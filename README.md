# agent-skills

`open-choice` など複数プロジェクトで共有する、Codex向けSkillカタログです。

このリポジトリは次の3点だけを管理します。

1. 採用するSkillの一覧と用途
2. 外部Skillの固定コミット
3. このリポジトリで保守する独自Skill

採用一覧の正本は [`skills.lock.tsv`](skills.lock.tsv) です。READMEには一覧を複製しません。

## 構成

| パス | 役割 |
| --- | --- |
| `skills.lock.tsv` | Skill名、取得元、固定コミット、担当する能力、起動条件 |
| `skills/document-architecture/` | 仕様書・設計書・提案書の構成と品質確認を担う独自Skill |
| `scripts/validate.sh` | 重複、浮動バージョン、不正なパス、ローカルSkillを検証 |
| `scripts/install.sh` | 取得元ごとに固定コミットを1回取得し、成功時だけ対象を置換 |
| `tests/` | バリデータとインストーラの回帰テスト |

## インストール

Gitが必要です。外部SkillはSkill単位ではなく、同じリポジトリとコミットを共有する単位でまとめて取得します。

```bash
./scripts/install.sh --target /path/to/project/.agents/skills
```

失敗時は既存のインストール先を保持します。同じlockから再実行しても結果は変わりません。

## open-choiceから使う

このリポジトリを `.agents/catalog` にsubmoduleとして置き、プロジェクト側の薄いラッパーを実行します。

```bash
git submodule update --init --recursive
./tools/install-external-skills.sh
```

生成される `.agents/skills/` はGit管理しません。更新対象はsubmoduleのコミットだけです。

## 更新方法

1. `skills.lock.tsv` の対象行だけを変更する
2. 外部Skillは40文字のコミットSHAへ固定する
3. `./scripts/validate.sh skills.lock.tsv .` を実行する
4. `./tests/validate_test.sh` と `./tests/install_test.sh` を実行する
5. 一時ディレクトリへの実インストールで全件を確認する

同じ能力を担うSkillを追加するときは、既存の `capability` と比較し、置換か併存かを明示してください。

## ライセンス

このリポジトリ独自のコードと文書はMIT Licenseです。外部Skill本体は再配布せず、各取得元のライセンスに従います。
