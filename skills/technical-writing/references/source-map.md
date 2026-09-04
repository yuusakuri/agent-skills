# 出典との対応

このスキルは、Tossの `technical-writing` リポジトリの指針を翻案している。

https://github.com/toss/technical-writing

参照元のリポジトリは、CC BY-NC-SA 4.0で提供されている。このプロジェクトでは、Tossに由来する執筆指針を同じコンテンツライセンスで提供し、`NOTICE.md` に帰属を記載している。

## 対応表

| このリポジトリ | Tossの参照箇所 | 翻案した指針 |
| --- | --- | --- |
| `references/document-types.md` | `docs/type/*`、`docs/tutorial/*` | 学習、問題解決、リファレンス、解説、記事形式の文書の選択 |
| `references/structure-principles.md` | `docs/architecture/*` | 1ページ1話題、価値を先に示すこと、見出し、概要、予測しやすさ、背景 |
| `references/sentence-style.md` | `docs/sentence/*` | 明確な主語、簡潔さ、具体性、自然な韓国語、用語の一貫性 |
| `references/review-rubric.md` | `docs/tutorial/review-prompt.mdx` と確認項目のページ | 確認項目に沿ったレビュー手順と重大度 |
| `references/prompt-workflows.md` | `docs/tutorial/review-prompt.mdx` | AIを使った執筆、構成、レビューのプロンプト |
| `assets/templates/*` | `docs/type/index.md`、`docs/tutorial/structure.mdx` | 再利用できる文書のひな形 |

## 翻案時の指定

- Tossのページ全文をそのまま複製しない。
- 指針を翻訳し、エージェント向けの指示にまとめる。
- 帰属表示と、コンテンツに適用されるCC BY-NC-SA 4.0を保持する。
- スクリプトとテストは分離し、MITで提供する。

## 参照URL

- リポジトリ：https://github.com/toss/technical-writing
- 構成に関する文書：https://github.com/toss/technical-writing/tree/master/docs/architecture
- 文に関する文書：https://github.com/toss/technical-writing/tree/master/docs/sentence
- 文書種別に関する文書：https://github.com/toss/technical-writing/tree/master/docs/type
- チュートリアルに関する文書：https://github.com/toss/technical-writing/tree/master/docs/tutorial
