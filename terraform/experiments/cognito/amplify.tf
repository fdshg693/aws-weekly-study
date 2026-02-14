# AWS Amplify Hosting Configuration
# ==================================
# Vue 3 SPAを配信するためのAmplify Hostingリソースを作成します。
# Git連携は使用せず、手動デプロイ（CLI経由）を行います。
#
# 参考:
# - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/amplify_app

# ========================================
# Amplify App
# ========================================
# SPAのホスティング基盤です。
# platform = "WEB" で静的サイトホスティングを行います。

resource "aws_amplify_app" "frontend" {
  name     = "${var.project_name}-${var.environment}-frontend"
  platform = "WEB"

  # SPA Rewrite Rules
  # -----------------
  # Amplifyはcustom_ruleを定義順に評価します。
  #
  # ルール1: 拡張子付きのパス（静的ファイル）はそのまま配信
  # これがないと、config.json等の静的ファイルもindex.htmlにリライトされ、
  # SPAが設定を読み込めなくなります。
  custom_rule {
    source = "</^[^.]+$|\\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json|webp)$)([^.]+$)/>"
    status = "200"
    target = "/index.html"
  }

  tags = merge(
    {
      Name = "${var.project_name}-${var.environment}-frontend"
    },
    var.additional_tags
  )
}

# ========================================
# Amplify Branch
# ========================================
# 手動デプロイのターゲットとなるブランチです。
# Git連携ではないため、ブランチ名は論理的な識別子として使用されます。

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.frontend.id
  branch_name = "main"
}

# ========================================
# Frontend Config File
# ========================================
# TerraformのOutputからVue SPAが実行時に読み込む設定ファイルを生成します。
# ビルド時に環境変数を埋め込む方式と異なり、
# デプロイ後にCognito設定を変更してもリビルド不要です。

resource "local_file" "frontend_config" {
  content = jsonencode({
    region        = var.aws_region
    userPoolId    = aws_cognito_user_pool.main.id
    clientId      = aws_cognito_user_pool_client.main.id
    cognitoDomain = "${aws_cognito_user_pool_domain.main[0].domain}.auth.${var.aws_region}.amazoncognito.com"
    redirectUri   = "https://main.${aws_amplify_app.frontend.default_domain}/callback"
    logoutUri     = "https://main.${aws_amplify_app.frontend.default_domain}/"
    # BFF API Gateway URL
    # フロントエンドがBFF APIを呼び出すためのベースURL。
    # ローカル開発ではViteプロキシを使用するため、この値は無視されます。
    bffUrl = aws_apigatewayv2_stage.bff.invoke_url
  })
  filename = "${path.module}/frontend/public/config.json"
}

# ========================================
# BFF Config File
# ========================================
# BFFサーバーが使用する設定ファイルを生成します。
# client_secretを含むため、フロントエンドの公開ディレクトリには置きません。
# このファイルはgitignore対象です。

resource "local_file" "bff_config" {
  content = jsonencode({
    region        = var.aws_region
    userPoolId    = aws_cognito_user_pool.main.id
    clientId      = aws_cognito_user_pool_client.main.id
    clientSecret  = aws_cognito_user_pool_client.main.client_secret
    cognitoDomain = "${aws_cognito_user_pool_domain.main[0].domain}.auth.${var.aws_region}.amazoncognito.com"
    redirectUri   = "http://localhost:3000/auth/callback"
    logoutUri     = "http://localhost:3000/"
  })
  filename = "${path.module}/bff/config.json"
}
