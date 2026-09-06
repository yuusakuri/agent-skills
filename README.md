# agent-skills

開発、設計、品質確認、プロダクト運営、文書作成に使う汎用 Agent
Skills カタログです。Skill 本体をリポジトリに含めているため、単体では
通常の clone だけで利用できます。各プロジェクトへは submodule として
追加し、プロジェクトごとに利用バージョンを固定します。

## 対応エージェント

| エージェント | プロジェクト内の入口 | 対応方法 |
|---|---|---|
| Codex | `.agents/skills` | 正本の `skills/` を指すディレクトリ symlink |
| Claude Code 2.1.203以降 | `.claude/skills/<skill-name>` | 各 Skill の正本を指す個別 symlink |

正本はすべて `skills/<skill-name>/` にあります。各ディレクトリの
`SKILL.md` が、その Skill の必須エントリーポイントです。リポジトリ全体を
表すルート `SKILL.md` は必要ありません。エージェントは各 `SKILL.md` の
`name` と `description` から適用する Skill を選びます。

`using-agent-skills` は、利用者が Skill の選び方を尋ねた場合や複数候補の
責務が曖昧な場合だけ使う補助 Skill です。通常の自動選択に先立って毎回
実行するものではありません。

## リポジトリ構成

| パス | 役割 |
|---|---|
| `skills/<skill-name>/` | `SKILL.md` と、その Skill 専用の `references/`、`scripts/`、`assets/` |
| `.agents/skills` | Codex 用エントリーポイント |
| `.claude/skills/` | Claude Code 用の個別 Skill エントリーポイント |
| `catalog.toml` | 外部取得元、固定 commit、ライセンス、同梱リソース、名前の対応関係 |
| `THIRD_PARTY_NOTICES.md` | 外部取得元とライセンス本文を source ごとに集約した通知 |
| `scripts/update_catalog.py` | 固定した外部 source から正本を再生成 |
| `scripts/sync_agent_links.py` | Codex と Claude Code のエントリーポイントを同期・検証 |
| `scripts/validate.py` | カタログ定義と Skill メタデータを検証 |
| `tests/` | カタログ、更新、リンク、利用側 clone の回帰テスト |

外部 Skill も通常のディレクトリとして `skills/` に取り込まれています。
このリポジトリ内に nested submodule はなく、追加のインストールや共有
ローカルディレクトリを必要としません。

## 単体で利用

```bash
git clone https://github.com/yuusakuri/agent-skills.git
cd agent-skills
```

clone 後は Codex と Claude Code の入口がどちらも準備済みです。

## プロジェクトへ追加

プロジェクトごとに、このリポジトリを submodule として追加します。

```bash
git submodule add https://github.com/yuusakuri/agent-skills.git .agents/catalog
python3 .agents/catalog/scripts/sync_agent_links.py \
  --project-root . \
  --catalog-root .agents/catalog \
  --write
git add .gitmodules .agents/catalog .agents/skills .claude/skills
```

同期コマンドが作るリンクもプロジェクトへ commit します。以後、利用者が
Skill を個別にインストールする必要はありません。

既存プロジェクトを取得するときは、そのプロジェクトの submodule を
初期化します。

```bash
git submodule update --init .agents/catalog
```

submodule の commit は各プロジェクトが個別に保持するため、別の
プロジェクトを更新しても連動しません。

## 文書作成

[tech-writing.md](tech-writing.md) は、文章構成、技術文書の執筆、日本語の
推敲を扱う日本語の文書です。3つの執筆指針と、その参照内容・テンプレートを
1ファイルに収めています。このファイルを直接編集して利用できます。

`document-architecture` は、次の正式文書を共同執筆・再構成・品質確認する
ための Skill です。

| 文書 | 主な判断対象 |
|---|---|
| 要件定義書 | 背景、目的、業務・機能・非機能要件、制約、受入条件 |
| 技術仕様書 | アーキテクチャ、コンポーネント、データ、API、セキュリティ、障害処理、テスト |
| 基本設計書 | 画面、帳票、API、データ、バッチ、権限、外部連携 |
| 詳細設計書 | モジュール、クラス、関数、処理フロー、データ更新、例外処理、単体テスト |
| システム提案書 | 課題、解決方針、構成、導入計画、体制、費用、効果、リスク |
| 業務提案書 | 現状、原因、施策、効果、実行計画、費用、評価指標 |

文書種別ごとの章構成と確認基準は、その Skill の `references/` に分離されて
います。成果物は GitHub-Flavored Markdown を既定とし、Word は利用者が
明示した場合だけ作成します。

## カタログの更新

更新作業には Python 3.11 以降と Git が必要です。

```bash
python3 scripts/update_catalog.py
python3 scripts/sync_agent_links.py \
  --project-root . \
  --catalog-root . \
  --write
python3 scripts/update_catalog.py --check
python3 scripts/sync_agent_links.py \
  --project-root . \
  --catalog-root . \
  --check
for test_file in tests/*.sh; do bash "${test_file}"; done
```

外部 source は `catalog.toml` の完全な commit SHA で固定します。共通参照
ファイルは、それを使う Skill の内部へ取り込み、単独の Skill
ディレクトリとしても自己完結する状態を保ちます。

## ライセンス

このリポジトリ独自のコードと文書は [MIT License](LICENSE) です。外部
Skill の取得元、固定 commit、ライセンス本文は
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) にまとめています。

`tech-writing.md` の日本語訳・統合部分は
[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) で提供します。
非営利・表示・継承条件があり、上記のMIT Licenseの適用対象には含みません。
原文に対して、日本語訳、英文法・英語固有の語法の除外、ファイルの統合、
見出しと参照先の調整を行っています。

| 提供元 | 固定した原文 | 原文のライセンス |
|---|---|---|
| William Strunk Jr.／Jesse Vincent（obra） | [writing-clearly-and-concisely](https://github.com/obra/the-elements-of-style/tree/05fc4f0d2b97b7c042dd9949ad658568e4a1324e/skills/writing-clearly-and-concisely) | Public Domain（提供元表記） |
| k16shikano | [japanese-tech-writing](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d/c7189cdc9c2520be50418209834145bdf3a46e97) | [Unlicenseの適用表明](https://gist.github.com/k16shikano/67625f2a7d96e3bbdfae8d571a936063/1092e6b60296c760071c308624e344469ec345cf) |

gwagjiug版は、[Tossのtechnical-writing](https://github.com/toss/technical-writing)
の指針に由来し、構成は [epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai)
を参考にしています。Strunkの原著は1918年の
[The Elements of Style](https://www.gutenberg.org/files/37134/37134-h/37134-h.htm) です。
