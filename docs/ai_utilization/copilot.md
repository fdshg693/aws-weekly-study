# Github Copilot活用

## Agents

サブエージェントとして扱うことが可能なエージェントには _sub エージェントという接尾辞をつけることにする。
ただし、直接の呼び出しも想定している。
_sub がつかないエージェントは、 `disable-model-invocation: true` として他のエージェントから呼び出されることを想定しない。

- aws_expert_sub
    - AWS MCP を使って、最新の情報を元にAWS関連の質問に答えるエージェント
    - `.ai/temp` フォルダにドキュメントの抜粋や参照情報を保存する
    - 要点をまとめた回答を提供する

- orchestrator
    - 汎用的なサブエージェントを利用するオーケストレーターエージェント

- terraform_expert.agent
    - オーバーヘッドの少ないテラフォーム実装エージェント＋AWS MCP