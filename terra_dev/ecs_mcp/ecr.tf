# ECR（Elastic Container Registry）
# このプロジェクトの Docker イメージを保存するプライベートレジストリ。
resource "aws_ecr_repository" "main" {
  name = "${var.environment}-${var.project_name}"

  # 学習用でも、タグ上書き事故を避けたいので IMMUTABLE を採用する。
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
