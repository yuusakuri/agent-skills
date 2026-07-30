# agent-skills

開発プロジェクトへsubmoduleとして組み込む、汎用のCodex向けSkillカタログです。

再帰的にcloneするだけで、固定バージョンのSkill 97件を利用できます。利用側でインストールスクリプトを実行したり、プロジェクト間でローカルディレクトリを共有したりする必要はありません。

このリポジトリは次を管理します。

- 重複を除いた採用Skill一覧と用途
- 外部Skillの固定コミット
- 実行時にそのまま参照できるSkill一式
- 外部Skillのライセンスと取得元
- 仕様書・設計書・提案書向けの独自Skill

採用一覧の正本は [`skills.lock.tsv`](skills.lock.tsv) です。

## リポジトリ構成

| パス | 役割 |
| --- | --- |
| `skills/` | clone直後に利用するSkill一式 |
| `.agents/skills` | このリポジトリ単体で利用するための`skills/`へのsymlink |
| `skills.lock.tsv` | Skill名、取得元、固定コミット、担当する能力、起動条件 |
| `skills/document-architecture/` | 仕様書・設計書・提案書の構成と品質確認を担う独自Skill |
| `vendor/` | 再配布せず、再帰submoduleで取得する外部Skill |
| `third-party-licenses/` | vendoringした外部Skillのライセンスと取得元 |
| `scripts/update-vendored-skills.sh` | 保守時だけ使う固定スナップショット更新コマンド |
| `scripts/validate.sh` | 重複、浮動バージョン、不正なパスを検証 |
| `tests/` | カタログ、更新処理、利用側構成の回帰テスト |

## プロジェクトへ追加

各プロジェクトが、このリポジトリを独立したsubmoduleとして固定します。

```bash
git submodule add https://github.com/yuusakuri/agent-skills.git .agents/catalog
ln -s catalog/skills .agents/skills
git add .gitmodules .agents/catalog .agents/skills
```

新規cloneではsubmoduleを再帰取得します。

```bash
git clone --recurse-submodules <project-repository-url>
```

すでにclone済みの場合:

```bash
git submodule update --init --recursive
```

利用側が固定するのは`.agents/catalog`のコミットです。更新は各プロジェクトで個別に行います。

## カタログの保守

通常の利用者はこの手順を実行しません。

1. `skills.lock.tsv`の対象行を、40文字のコミットSHAで更新する
2. 必要に応じて`vendor/`のnested submoduleを更新する
3. `./scripts/update-vendored-skills.sh`で`skills/`とライセンス情報を再生成する
4. `./scripts/update-vendored-skills.sh --check`と`./tests/*.sh`でスナップショットを検証する

同じ能力を担うSkillを追加するときは、既存の`capability`と比較し、置換か併存かを明示します。

## ライセンス

このリポジトリ独自のコードと文書はMIT Licenseです。vendoringした外部Skillには[`third-party-licenses/`](third-party-licenses/)の条件が適用されます。ライセンス宣言を確認できない外部Skillは再配布せず、[`vendor/`](vendor/)のnested submoduleから固定コミットを取得します。
