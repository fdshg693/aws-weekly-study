# =====================================
# Lambda実行ロール
# =====================================

# Lambda関数が使用するIAMロール
# このロールにより、Lambda関数が他のAWSサービスと対話できる
resource "aws_iam_role" "lambda_role" {
  # ロール名
  # 環境名を含めることで環境ごとに分離
  name = "${var.environment}-${var.function_name}-role"
  
  # ロールの説明
  description = "IAM role for ${var.environment}-${var.function_name} Lambda function"
  
  # 信頼ポリシー（誰がこのロールを引き受けられるか）
  # Lambda サービスにこのロールの引き受けを許可
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        # 条件を追加してセキュリティを強化（オプション）
        # Condition = {
        #   StringEquals = {
        #     "sts:ExternalId" = "unique-external-id"
        #   }
        # }
      }
    ]
  })
  
  # ロールの最大セッション時間（秒）
  # デフォルト: 3600秒（1時間）
  # 範囲: 3600秒 〜 43200秒（12時間）
  max_session_duration = 3600
  
  # パーミッション境界（オプション）
  # ロールに付与できる権限の上限を設定
  # permissions_boundary = "arn:aws:iam::aws:policy/PowerUserAccess"
  
  tags = {
    Name        = "${var.environment}-${var.function_name}-role"
    Environment = var.environment
  }
}

# =====================================
# CloudWatch Logsへの書き込み権限
# =====================================

# Lambda関数がCloudWatch Logsにログを書き込むための権限
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  # アタッチ先のロール
  role = aws_iam_role.lambda_role.name
  
  # AWSが管理する基本的な実行ポリシー
  # 以下の権限が含まれる:
  # - logs:CreateLogGroup
  # - logs:CreateLogStream
  # - logs:PutLogEvents
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =====================================
# VPC内での実行権限（VPC有効時のみ）
# =====================================

# Lambda関数がVPC内で実行される場合に必要な権限
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = var.enable_vpc ? 1 : 0
  
  role = aws_iam_role.lambda_role.name
  
  # VPC内での実行に必要な権限:
  # - ec2:CreateNetworkInterface
  # - ec2:DescribeNetworkInterfaces
  # - ec2:DeleteNetworkInterface
  # - ec2:AssignPrivateIpAddresses
  # - ec2:UnassignPrivateIpAddresses
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# =====================================
# X-Rayトレーシング権限（トレーシング有効時のみ）
# =====================================

# Lambda関数がAWS X-Rayにトレースデータを送信する権限
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  count = var.tracing_mode == "Active" ? 1 : 0
  
  role = aws_iam_role.lambda_role.name
  
  # X-Rayへのアクセス権限:
  # - xray:PutTraceSegments
  # - xray:PutTelemetryRecords
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =====================================
# カスタムIAMポリシー
# =====================================

# Lambda関数に必要な追加の権限を定義
# 例: S3バケットへのアクセス、DynamoDBテーブルの読み書き等
resource "aws_iam_role_policy" "lambda_custom_policy" {
  name = "${var.environment}-${var.function_name}-custom-policy"
  role = aws_iam_role.lambda_role.id
  
  # カスタムポリシードキュメント
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3バケットへの読み取り・書き込み権限の例
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          # 特定のバケットとオブジェクトへのアクセスを制限
          "arn:aws:s3:::my-bucket-name/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-bucket-name"
        ]
      },
      
      # DynamoDBテーブルへのアクセス権限の例
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "dynamodb:GetItem",
      #     "dynamodb:PutItem",
      #     "dynamodb:UpdateItem",
      #     "dynamodb:DeleteItem",
      #     "dynamodb:Query",
      #     "dynamodb:Scan"
      #   ]
      #   Resource = [
      #     "arn:aws:dynamodb:${var.aws_region}:*:table/my-table-name"
      #   ]
      # },
      
      # SQSキューへのアクセス権限の例
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "sqs:SendMessage",
      #     "sqs:ReceiveMessage",
      #     "sqs:DeleteMessage",
      #     "sqs:GetQueueAttributes"
      #   ]
      #   Resource = [
      #     "arn:aws:sqs:${var.aws_region}:*:my-queue-name"
      #   ]
      # },
      
      # Secrets Managerからのシークレット取得の例
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "secretsmanager:GetSecretValue"
      #   ]
      #   Resource = [
      #     "arn:aws:secretsmanager:${var.aws_region}:*:secret:my-secret-*"
      #   ]
      # },
      
      # Systems Manager Parameter Storeへのアクセスの例
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "ssm:GetParameter",
      #     "ssm:GetParameters",
      #     "ssm:GetParametersByPath"
      #   ]
      #   Resource = [
      #     "arn:aws:ssm:${var.aws_region}:*:parameter/myapp/*"
      #   ]
      # },
      
      # SNSトピックへの発行権限の例
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "sns:Publish"
      #   ]
      #   Resource = [
      #     "arn:aws:sns:${var.aws_region}:*:my-topic-name"
      #   ]
      # },
      
      # KMSキーの使用権限の例（暗号化・復号化）
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "kms:Decrypt",
      #     "kms:Encrypt",
      #     "kms:GenerateDataKey"
      #   ]
      #   Resource = [
      #     "arn:aws:kms:${var.aws_region}:*:key/your-key-id"
      #   ]
      # }
    ]
  })
}

# =====================================
# 管理ポリシーのアタッチ（オプション）
# =====================================

# AWSが管理するポリシーをアタッチする例
# resource "aws_iam_role_policy_attachment" "lambda_s3_readonly" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
# }

# resource "aws_iam_role_policy_attachment" "lambda_dynamodb_full" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
# }

# =====================================
# リソースベースのポリシー（Lambda関数への呼び出し許可）
# =====================================

# 他のAWSサービスにLambda関数の呼び出しを許可
# 例: API Gatewayからの呼び出し許可
# resource "aws_lambda_permission" "allow_api_gateway" {
#   statement_id  = "AllowExecutionFromAPIGateway"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.main.function_name
#   principal     = "apigateway.amazonaws.com"
#   
#   # 特定のAPI Gatewayのみ許可する場合
#   source_arn = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
# }

# 例: S3バケットイベントからの呼び出し許可
# resource "aws_lambda_permission" "allow_s3" {
#   statement_id  = "AllowExecutionFromS3"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.main.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.source.arn
# }

# 例: SNSトピックからの呼び出し許可
# resource "aws_lambda_permission" "allow_sns" {
#   statement_id  = "AllowExecutionFromSNS"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.main.function_name
#   principal     = "sns.amazonaws.com"
#   source_arn    = aws_sns_topic.trigger.arn
# }

# 例: EventBridgeルールからの呼び出し許可
# resource "aws_lambda_permission" "allow_eventbridge" {
#   statement_id  = "AllowExecutionFromEventBridge"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.main.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.lambda_trigger.arn
# }

# =====================================
# IAMポリシーの参考リンク
# =====================================

# AWS管理ポリシーの一覧:
# https://docs.aws.amazon.com/ja_jp/aws-managed-policy/latest/reference/policy-list.html
#
# Lambda実行ロールのベストプラクティス:
# https://docs.aws.amazon.com/ja_jp/lambda/latest/dg/lambda-intro-execution-role.html
#
# 最小権限の原則:
# 必要最小限の権限のみを付与し、定期的に見直すことを推奨
