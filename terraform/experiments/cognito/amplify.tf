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

  # SPA Rewrite Rule
  # ----------------
  # すべてのパスを index.html にリライトします。
  # これにより、ブラウザで /callback などのパスに直接アクセスしても
  # Vue SPAが正しくルーティングを処理できます。
  custom_rule {
    source = "/<*>"
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
  })
  filename = "${path.module}/frontend/public/config.json"
}
