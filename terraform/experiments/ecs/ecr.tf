# ECR（Elastic Container Registry）
# Dockerイメージを保存・管理するAWSのコンテナレジストリサービス
# Docker Hubのようなパブリックレジストリではなく、AWSアカウント内のプライベートレジストリ

resource "aws_ecr_repository" "main" {
  name = "${var.environment}-${var.project_name}"

  # イメージタグのミュータビリティ設定
  # IMMUTABLE: 同じタグで上書きプッシュを禁止（本番推奨、意図しない上書きを防止）
  # MUTABLE: 同じタグで上書きプッシュを許可（開発環境では便利だが事故の元）
  image_tag_mutability = "IMMUTABLE"

  # プッシュ時にセキュリティスキャンを自動実行
  # コンテナイメージ内の脆弱性（CVE）を検出する
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-ecr"
  }
}

# ライフサイクルポリシー
# 古いイメージを自動的に削除してストレージコストを削減
# untaggedイメージ（タグが外れた古いイメージ）を一定期間後に削除
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 4 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 4 # 最新の4イメージを保持し、それ以上は自動削除
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
