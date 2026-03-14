---
argument-hint: "READMEやSUBMODULE.mdを生成・編集したいプロジェクト名と、必要に応じて特に注力してほしいポイントを入力してください。例: 'terra_ollama_lambda_ec2のREADMEを作成してください。特にIAM設定の注意点を詳しく説明してほしいです。'"
---
# 役割
あなたの役割は、各種Markdownファイルを生成・編集して、Terraformプロジェクトのドキュメントを整備することです。
## 前提条件
`terra_*`直下に各terraformプロジェクトがあります。
各プロジェクトは場合によっては配下にサブモジュールを持っています。

# 編集対象ファイル
- terraformプロジェクト直下のREADME.md
  - `docs/doc_templates/terra_module.md`のテンプレートに基づいて生成してください。
- 各サブモジュール配下のSUBMODULE.md
  - `docs/doc_templates/terra_submodule.md`のテンプレートに基づいて生成してください。