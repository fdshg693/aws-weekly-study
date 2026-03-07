#===============================================================================
# main.tf - ルートモジュール
#===============================================================================
#
# このファイルは、SQS Lambda アーキテクチャのルートモジュールです。
# 各サブモジュールを呼び出し、リソース間の依存関係を管理します。
#
# ■ アーキテクチャ概要
# ┌──────────────┐     ┌─────────────┐     ┌──────────────┐     ┌──────────────┐
# │ API Gateway  │────▶│   Producer  │────▶│     SQS      │────▶│   Consumer   │
# │   (REST)     │     │   Lambda    │     │    Queue     │     │   Lambda     │
# └──────────────┘     └─────────────┘     └──────────────┘     └──────────────┘
#                                                                      │
#                                                                      ▼
#                                                               ┌──────────────┐
#                                                               │   DynamoDB   │
#                                                               │    Table     │
#                                                               └──────────────┘
#
# ■ モジュール間の依存関係
#
# 1. DynamoDB モジュール
#    └─▶ 独立して作成可能（他のモジュールに依存しない）
#
# 2. SQS モジュール
#    └─▶ 独立して作成可能（他のモジュールに依存しない）
#
# 3. Producer Lambda モジュール
#    ├─▶ SQS モジュールの queue_url を環境変数として必要
#    └─▶ SQS モジュールの queue_arn を IAM ポリシーで参照
#
# 4. Consumer Lambda モジュール
#    ├─▶ DynamoDB モジュールの table_name を環境変数として必要
#    ├─▶ DynamoDB モジュールの table_arn を IAM ポリシーで参照
#    └─▶ SQS モジュールの queue_arn を IAM ポリシーで参照
#
# 5. イベントソースマッピング
#    ├─▶ Consumer Lambda の function_arn を必要
#    └─▶ SQS モジュールの queue_arn を必要
#
# 6. API Gateway モジュール
#    └─▶ Producer Lambda の invoke_arn と function_name を必要
#
#===============================================================================

#-------------------------------------------------------------------------------
# Data Sources - AWS アカウント情報の取得
#-------------------------------------------------------------------------------
# 
# データソースは、既存の AWS リソースや情報を参照するために使用します。
# terraform apply 時に AWS API を呼び出して最新の情報を取得します。
#

# 現在の AWS アカウント ID を取得
# 用途: IAM ポリシーの ARN 構築、リソースの一意な命名など
data "aws_caller_identity" "current" {}

# 現在のリージョン情報を取得
# 用途: リージョン固有の ARN 構築、エンドポイント URL の構築など
data "aws_region" "current" {}

#===============================================================================
# モジュール呼び出し
#===============================================================================

#-------------------------------------------------------------------------------
# DynamoDB モジュール
#-------------------------------------------------------------------------------
#
# 注文データを永続化するための DynamoDB テーブルを作成します。
#
# ■ モジュールの役割
#   - orders テーブルの作成（パーティションキー: order_id）
#   - GSI の作成（顧客別検索用）
#   - TTL 設定（古い注文の自動削除）
#   - Point-in-Time Recovery の設定
#
# ■ 依存関係
#   - 他のモジュールに依存しない（独立して作成可能）
#   - Consumer Lambda がこのテーブルにデータを書き込む
#
module "dynamodb" {
  source = "./modules/dynamodb"

  # 必須変数
  # environment: リソース名のサフィックス（例: orders-table-dev）
  environment = var.environment

  # project_name: リソース名のプレフィックス
  project_name = var.project_name

  # オプション: 追加タグ
  tags = {
    Component = "Database"
    Purpose   = "Order storage"
  }
}

#-------------------------------------------------------------------------------
# SQS モジュール
#-------------------------------------------------------------------------------
#
# Producer Lambda から Consumer Lambda へメッセージを非同期で渡すための
# SQS キューと Dead Letter Queue を作成します。
#
# ■ モジュールの役割
#   - メインキューの作成（orders-queue）
#   - Dead Letter Queue の作成（処理失敗メッセージの隔離）
#   - リドライブポリシーの設定（失敗時の DLQ 転送）
#
# ■ 依存関係
#   - 他のモジュールに依存しない（独立して作成可能）
#   - Producer Lambda がメッセージを送信
#   - Consumer Lambda がメッセージを受信
#
# ■ 重要な設定
#   - visibility_timeout_seconds: Lambda タイムアウトの6倍を推奨
#   - max_receive_count: 失敗回数の閾値（超えると DLQ へ移動）
#
module "sqs" {
  source = "./modules/sqs"

  # 必須変数
  environment  = var.environment
  project_name = var.project_name

  # SQS キューの設定
  # メッセージ保持期間（秒）- ルート変数から取得
  message_retention_seconds = var.sqs_message_retention_seconds

  # 可視性タイムアウト（秒）- Lambda タイムアウトより長く設定
  # Lambda タイムアウト × 6 が AWS 推奨
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds

  # DLQ 移動までの最大受信回数
  max_receive_count = var.sqs_max_receive_count

  # オプション: 追加タグ
  tags = {
    Component = "Messaging"
    Purpose   = "Order queue"
  }
}

#-------------------------------------------------------------------------------
# Producer Lambda モジュール
#-------------------------------------------------------------------------------
#
# API Gateway からのリクエストを受け取り、
# 注文情報を SQS キューに送信する Lambda 関数です。
#
# ■ モジュールの役割
#   - Lambda 関数の作成（コードのパッケージングとデプロイ）
#   - IAM ロールの作成（基本実行権限 + 追加ポリシー）
#   - CloudWatch Logs グループの作成
#
# ■ 依存関係
#   - SQS モジュールの出力（queue_url, queue_arn）に依存
#   - API Gateway から呼び出される
#
# ■ IAM ポリシー設計
#   Producer Lambda には以下の権限が必要:
#   
#   1. 基本実行権限（モジュール内で自動付与）
#      - logs:CreateLogGroup
#      - logs:CreateLogStream
#      - logs:PutLogEvents
#   
#   2. SQS 送信権限（additional_policies で追加）
#      - sqs:SendMessage
#      - リソース: 特定の SQS キューのみ（最小権限の原則）
#
module "lambda_producer" {
  source = "./modules/lambda"

  # 関数名: {project_name}-producer-{environment}
  # 例: order-processor-producer-dev
  function_name = "${var.project_name}-producer-${var.environment}"

  # 環境名（タグ付けに使用）
  environment = var.environment

  # Lambda コードのソースディレクトリ
  # このディレクトリ内のファイルが ZIP 化されてデプロイされる
  source_path = "${path.module}/lambda_code/producer"

  # Lambda ランタイム設定
  handler = "index.lambda_handler" # index.py の lambda_handler 関数
  runtime = "python3.12"           # Python ランタイム

  # リソース設定（ルート変数から取得）
  memory_size                    = var.lambda_memory_size
  timeout                        = var.lambda_timeout
  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions

  # ログ保持期間
  log_retention_days = var.log_retention_days

  #-----------------------------------------------------------------------------
  # 環境変数
  #-----------------------------------------------------------------------------
  # Lambda 関数内で使用する設定値を環境変数として渡す
  # process.env.SQS_QUEUE_URL のようにアクセス可能
  #
  environment_variables = {
    # SQS キューの URL（メッセージ送信先）
    # SQS モジュールの出力を参照
    SQS_QUEUE_URL = module.sqs.queue_url

    # 環境名（ログ出力やデバッグに使用）
    ENVIRONMENT = var.environment

    # ログレベル（開発時は DEBUG、本番は INFO を推奨）
    LOG_LEVEL = var.environment == "dev" ? "DEBUG" : "INFO"
  }

  #-----------------------------------------------------------------------------
  # 追加 IAM ポリシー - SQS SendMessage 権限
  #-----------------------------------------------------------------------------
  # 
  # ■ 最小権限の原則
  #   - 必要なアクション（sqs:SendMessage）のみ許可
  #   - 特定のキュー ARN のみ対象（ワイルドカードを避ける）
  #
  # ■ ポリシーの構造
  #   - Version: IAM ポリシーのバージョン（2012-10-17 が最新）
  #   - Statement: 権限ステートメントの配列
  #     - Effect: Allow（許可）または Deny（拒否）
  #     - Action: 許可する AWS API アクション
  #     - Resource: 対象となる AWS リソースの ARN
  #
  additional_policies = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          # SQS メッセージ送信権限
          Sid    = "AllowSQSSendMessage"
          Effect = "Allow"
          Action = [
            "sqs:SendMessage"
          ]
          # SQS モジュールの出力から ARN を取得
          # 特定のキューのみに制限（最小権限）
          Resource = module.sqs.queue_arn
        }
      ]
    })
  ]

  # オプション: 追加タグ
  tags = {
    Component = "Lambda"
    Role      = "Producer"
  }
}

#-------------------------------------------------------------------------------
# Consumer Lambda モジュール
#-------------------------------------------------------------------------------
#
# SQS キューからメッセージを受け取り、
# 注文情報を DynamoDB に保存する Lambda 関数です。
#
# ■ モジュールの役割
#   - Lambda 関数の作成
#   - IAM ロールの作成（SQS 受信権限 + DynamoDB 書き込み権限）
#   - CloudWatch Logs グループの作成
#
# ■ 依存関係
#   - SQS モジュールの出力（queue_arn）に依存
#   - DynamoDB モジュールの出力（table_name, table_arn）に依存
#   - イベントソースマッピングから呼び出される
#
# ■ IAM ポリシー設計
#   Consumer Lambda には以下の権限が必要:
#   
#   1. 基本実行権限（モジュール内で自動付与）
#   
#   2. SQS 受信権限（Lambda がポーリングするために必要）
#      - sqs:ReceiveMessage: メッセージの取得
#      - sqs:DeleteMessage: 処理完了後のメッセージ削除
#      - sqs:GetQueueAttributes: キュー属性の取得（スケーリング用）
#   
#   3. DynamoDB 操作権限
#      - dynamodb:PutItem: 新規アイテムの書き込み
#      - dynamodb:GetItem: アイテムの取得（重複チェック用）
#      - dynamodb:UpdateItem: 既存アイテムの更新
#
module "lambda_consumer" {
  source = "./modules/lambda"

  # 関数名: {project_name}-consumer-{environment}
  function_name = "${var.project_name}-consumer-${var.environment}"

  # 環境名
  environment = var.environment

  # Lambda コードのソースディレクトリ
  source_path = "${path.module}/lambda_code/consumer"

  # Lambda ランタイム設定
  handler = "index.lambda_handler" # index.py の lambda_handler 関数
  runtime = "python3.12"

  # リソース設定
  memory_size                    = var.lambda_memory_size
  timeout                        = var.lambda_timeout
  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions

  # ログ保持期間
  log_retention_days = var.log_retention_days

  #-----------------------------------------------------------------------------
  # 環境変数
  #-----------------------------------------------------------------------------
  environment_variables = {
    # DynamoDB テーブル名（データ保存先）
    # DynamoDB モジュールの出力を参照
    DYNAMODB_TABLE_NAME = module.dynamodb.table_name

    # 環境名
    ENVIRONMENT = var.environment

    # ログレベル
    LOG_LEVEL = var.environment == "dev" ? "DEBUG" : "INFO"
  }

  #-----------------------------------------------------------------------------
  # 追加 IAM ポリシー - SQS 受信権限 + DynamoDB 操作権限
  #-----------------------------------------------------------------------------
  #
  # ■ 複数サービスへのアクセス
  #   Consumer Lambda は複数の AWS サービスにアクセスするため、
  #   それぞれのサービスに対する権限を Statement 配列に追加
  #
  # ■ SQS ポーリングについて
  #   Lambda は自動的に SQS をポーリングしてメッセージを取得する
  #   （イベントソースマッピングで設定）
  #   このポーリングには sqs:ReceiveMessage 権限が必要
  #
  additional_policies = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          # SQS からのメッセージ受信・削除権限
          # Lambda がイベントソースとして SQS を使用する際に必要
          Sid    = "AllowSQSReceiveDelete"
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",    # メッセージの取得
            "sqs:DeleteMessage",     # 処理完了後の削除
            "sqs:GetQueueAttributes" # キュー属性の取得（Lambda サービスが使用）
          ]
          Resource = module.sqs.queue_arn
        },
        {
          # DynamoDB への CRUD 操作権限
          Sid    = "AllowDynamoDBOperations"
          Effect = "Allow"
          Action = [
            "dynamodb:PutItem",   # 新規アイテム作成
            "dynamodb:GetItem",   # アイテム取得（重複チェック、べき等性）
            "dynamodb:UpdateItem" # 既存アイテム更新
          ]
          # DynamoDB モジュールの出力から ARN を取得
          Resource = module.dynamodb.table_arn
        }
      ]
    })
  ]

  # オプション: 追加タグ
  tags = {
    Component = "Lambda"
    Role      = "Consumer"
  }
}

#-------------------------------------------------------------------------------
# SQS イベントソースマッピング
#-------------------------------------------------------------------------------
#
# SQS キューと Consumer Lambda を接続するイベントソースマッピングです。
# Lambda サービスが SQS をポーリングし、メッセージを Lambda に渡します。
#
# ■ イベントソースマッピングとは
#   - Lambda を特定のイベントソースに接続する設定
#   - SQS、Kinesis、DynamoDB Streams などをサポート
#   - Lambda サービスがポーリングを行う（Lambda 関数は受動的）
#
# ■ バッチ処理について
#   - 複数のメッセージをまとめて Lambda に渡すことができる
#   - batch_size: 1回の呼び出しで処理するメッセージ数の上限
#   - maximum_batching_window_in_seconds: バッチを貯める最大待機時間
#
# ■ 失敗処理について
#   - function_response_types: Lambda からの部分的な失敗レポートを有効化
#   - "ReportBatchItemFailures" を指定すると、バッチ内の
#     失敗したメッセージのみが再処理される（効率的）
#   - 指定しない場合、1つでも失敗するとバッチ全体が再処理される
#
# ■ 依存関係
#   - Consumer Lambda の function_arn が必要
#   - SQS キューの ARN が必要
#   - Consumer Lambda に SQS アクセス権限が必要
#
resource "aws_lambda_event_source_mapping" "sqs_to_consumer" {
  # イベントソース: SQS キュー
  # Lambda サービスがこのキューをポーリングする
  event_source_arn = module.sqs.queue_arn

  # ターゲット: Consumer Lambda 関数
  function_name = module.lambda_consumer.function_arn

  #-----------------------------------------------------------------------------
  # バッチ設定
  #-----------------------------------------------------------------------------

  # 1回の Lambda 呼び出しで処理するメッセージ数の上限
  # 範囲: 1-10000（SQS 標準キューの場合）
  # 推奨: 処理時間とメモリ使用量を考慮して設定
  # 
  # batch_size = 10 の場合:
  # - event["Records"] に最大10件のメッセージが含まれる
  # - 処理時間は Lambda タイムアウト内に収める必要がある
  batch_size = 10

  # バッチを貯める最大待機時間（秒）
  # 0: メッセージが届いたら即座に Lambda を呼び出す
  # 1-300: 指定した秒数またはバッチサイズに達するまで待機
  #
  # トレードオフ:
  # - 0: 低レイテンシー、Lambda 呼び出し回数が増加
  # - 長い値: 高スループット、レイテンシーが増加
  maximum_batching_window_in_seconds = 0

  #-----------------------------------------------------------------------------
  # 失敗処理設定
  #-----------------------------------------------------------------------------

  # Lambda からの部分的な失敗レポートを有効化
  # 
  # ■ 動作の違い
  # 
  # function_response_types = [] （デフォルト）の場合:
  #   - Lambda がエラーを返すと、バッチ全体が失敗扱い
  #   - 全てのメッセージが再処理される（非効率）
  #
  # function_response_types = ["ReportBatchItemFailures"] の場合:
  #   - Lambda は失敗したメッセージの ID を返す
  #   - 失敗したメッセージのみが再処理される（効率的）
  #
  # ■ Lambda 側の実装例
  # 
  # def handler(event, context):
  #     batch_item_failures = []
  #     for record in event["Records"]:
  #         try:
  #             process_message(record)
  #         except Exception as e:
  #             # 失敗したメッセージの ID を記録
  #             batch_item_failures.append({
  #                 "itemIdentifier": record["messageId"]
  #             })
  #     
  #     return {
  #         "batchItemFailures": batch_item_failures
  #     }
  #
  function_response_types = ["ReportBatchItemFailures"]

  # イベントソースマッピングの有効/無効
  # false にすると、メッセージの処理が停止される（メンテナンス時に有用）
  enabled = true

  # スケーリング設定（オプション）
  # scaling_config {
  #   maximum_concurrency = 10  # 最大同時実行数
  # }

  # 依存関係の明示的な設定
  # Lambda モジュールの IAM ポリシーが作成されてから
  # イベントソースマッピングを作成する
  depends_on = [
    module.lambda_consumer
  ]
}

#-------------------------------------------------------------------------------
# API Gateway モジュール
#-------------------------------------------------------------------------------
#
# REST API を公開し、Producer Lambda と統合します。
# クライアントは API Gateway 経由で注文を送信します。
#
# ■ モジュールの役割
#   - REST API の作成
#   - /orders リソースとPOST メソッドの作成
#   - Lambda プロキシ統合の設定
#   - ステージ（dev/prod）のデプロイ
#   - アクセスログの設定
#
# ■ 依存関係
#   - Producer Lambda の invoke_arn と function_name が必要
#   - Lambda のリソースポリシーで API Gateway からの呼び出しを許可
#
# ■ Lambda プロキシ統合について
#   - API Gateway がリクエスト全体を Lambda に転送
#   - Lambda がレスポンス形式を完全に制御
#   - 最も柔軟で、一般的に推奨される統合方式
#
module "api_gateway" {
  source = "./modules/api_gateway"

  # 環境名（ステージ名としても使用）
  environment = var.environment

  # プロジェクト名（API 名のプレフィックス）
  project_name = var.project_name

  # 統合する Lambda 関数の情報
  # invoke_arn: API Gateway から Lambda を呼び出すための特別な ARN
  # function_name: Lambda 関数の名前（リソースポリシー設定に使用）
  lambda_invoke_arn    = module.lambda_producer.invoke_arn
  lambda_function_name = module.lambda_producer.function_name

  # オプション: 追加タグ
  tags = {
    Component = "API"
    Purpose   = "Order ingestion"
  }
}

#===============================================================================
# ローカル値（デバッグ・参考用）
#===============================================================================
#
# locals ブロックは、モジュール内で繰り返し使用する値や
# 複雑な式を定義するのに便利です。
#
locals {
  # 現在の AWS アカウント ID
  account_id = data.aws_caller_identity.current.account_id

  # 現在のリージョン
  # 注: name 属性は非推奨のため、id を使用
  region = data.aws_region.current.id

  # 共通タグ
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

#===============================================================================
# 補足: Terraform の依存関係解決
#===============================================================================
#
# Terraform は以下の方法で依存関係を解決します:
#
# 1. 暗黙的な依存関係（Implicit Dependencies）
#    - あるリソースが別のリソースの属性を参照している場合
#    - 例: module.sqs.queue_url を参照 → SQS モジュールが先に作成
#    - Terraform が自動的に依存関係を検出
#
# 2. 明示的な依存関係（Explicit Dependencies）
#    - depends_on で明示的に指定
#    - 暗黙的な依存関係が検出できない場合に使用
#    - 例: IAM ポリシーのアタッチ完了を待つ場合
#
# 3. 作成順序の例（このアーキテクチャの場合）
#    
#    ┌─────────────┐    ┌─────────────┐
#    │  DynamoDB   │    │     SQS     │
#    └──────┬──────┘    └──────┬──────┘
#           │                  │
#           │    ┌─────────────┴─────────────┐
#           │    │                           │
#           ▼    ▼                           ▼
#    ┌─────────────────┐             ┌─────────────────┐
#    │ Consumer Lambda │             │ Producer Lambda │
#    └────────┬────────┘             └────────┬────────┘
#             │                               │
#             ▼                               ▼
#    ┌─────────────────┐             ┌─────────────────┐
#    │ Event Source    │             │  API Gateway    │
#    │ Mapping         │             │                 │
#    └─────────────────┘             └─────────────────┘
#
#===============================================================================
