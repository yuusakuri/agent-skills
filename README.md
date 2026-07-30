# agent-skills

どの開発プロジェクトでも使える、Codex向けの汎用Skillカタログです。

このリポジトリを通常どおりcloneすると、固定バージョンのSkill 97件がすべて含まれます。追加インストール、再帰clone、共有ローカルディレクトリは不要です。

| 管理対象 | 方針 |
| --- | --- |
| Skill本体 | `skills/<skill-name>/`へフラットに配置 |
| 採用一覧 | 重複する能力を除き、97件を採用 |
| 外部Skill | upstreamのcommit SHAをsource単位で固定 |
| 独自Skill | 外部Skillと同じ階層・同じ利用方法で配置 |
| 文書作成 | 仕様書、設計書、提案書の章構成と品質確認に対応 |
| 文書形式 | GitHub-Flavored Markdownを既定、Wordは明示指定時のみ |
| ライセンス | upstreamごとの本文と取得元をルートの1ファイルへ集約 |
| 作業管理 | リポジトリ内のタスクファイルではなくGitHub Issuesを使用 |

## リポジトリ構成

| パス | 役割 |
| --- | --- |
| `skills/` | clone直後に利用できるSkill 97件 |
| `.agents/skills` | このリポジトリ単体で利用するための`skills/`へのsymlink |
| `catalog.toml` | source、固定commit、ライセンス、Skill、能力、起動条件 |
| `THIRD_PARTY_NOTICES.md` | 外部sourceの取得元とライセンス本文 |
| `scripts/catalog_manifest.py` | TOMLの読み込みと共通検証 |
| `scripts/validate.py` | 重複、浮動バージョン、不正なパスを検証 |
| `scripts/update_catalog.py` | 保守時に固定スナップショットを再生成 |
| `tests/` | カタログ、更新処理、利用側構成の回帰テスト |

## 単体で利用

通常のcloneだけで利用できます。

```bash
git clone https://github.com/yuusakuri/agent-skills.git
cd agent-skills
```

clone後は`.agents/skills`から全Skillを参照できます。submoduleの初期化や更新コマンドは必要ありません。

## プロジェクトへ追加

各プロジェクトが、このリポジトリを1つのsubmoduleとして個別に固定します。

```bash
git submodule add https://github.com/yuusakuri/agent-skills.git .agents/catalog
ln -s catalog/skills .agents/skills
git add .gitmodules .agents/catalog .agents/skills
```

プロジェクトをcloneした後は、そのプロジェクトのsubmoduleを1段だけ初期化します。

```bash
git submodule update --init .agents/catalog
```

利用側が固定するのは`.agents/catalog`のcommitです。更新は各プロジェクトで個別に行い、他プロジェクトとは共有しません。

## カタログの保守

通常の利用者はこの手順を実行しません。保守コマンドにはPython 3.11以上とGitが必要です。

1. 変更の目的と受入条件をGitHub Issueへ記録する
2. `catalog.toml`のsourceまたはSkillを更新する
3. `python3 scripts/update_catalog.py`で`skills/`と通知文書を再生成する
4. `python3 scripts/update_catalog.py --check`と`tests/*.sh`で検証する

同じ能力を担うSkillを追加するときは既存の`capability`と比較し、置換か併存かをIssueとレビューで明示します。

## ライセンス

このリポジトリ独自のコードと文書は[MIT License](LICENSE)です。外部Skillの取得元、固定commit、ライセンス本文は[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)にまとめています。
