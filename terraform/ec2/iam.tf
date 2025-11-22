# EC2インスタンス用のIAMロール
# IAMロールは、AWSリソースに対して一時的な権限を付与するための仕組み
# EC2インスタンスにこのロールをアタッチすることで、インスタンス内のアプリケーションが
# AWSサービス（S3、DynamoDB、CloudWatchなど）にアクセスできるようになります
# 
# このロール自体は「箱」のようなもので、実際の権限は後からポリシーをアタッチすることで付与されます
resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-ec2-role"

  # assume_role_policy: このロールを「誰が引き受けられるか」を定義
  # ここでは ec2.amazonaws.com サービスがこのロールを引き受けられるよう設定
  # つまり「EC2インスタンスがこのロールの権限を使えるようにする」という意味
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole" # STSサービスを使ってロールを引き受ける
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" # EC2サービスにロールの引き受けを許可
        }
      }
    ]
  })
}

# SSM接続用のポリシーをアタッチ（Session Managerで接続可能にする）
# ここで上記のec2_roleに具体的な権限を付与しています
# 
# aws_iam_role_policy_attachment: 既存のIAMロールに、AWSが管理するポリシーをアタッチするリソース
# これにより、空の「箱」だったec2_roleに実際の権限が追加されます
# 
# AmazonSSMManagedInstanceCore ポリシーの内容:
# - Systems Manager（SSM）経由でEC2インスタンスに接続する権限
# - SSHキーなしでブラウザからセキュアに接続できる
# - CloudWatch Logsへのログ送信権限なども含まれる
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name                             # 上で作成したロールを参照
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # AWSが事前に用意している管理ポリシー
}

# IAMインスタンスプロファイルの作成
# インスタンスプロファイルは、IAMロールとEC2インスタンスを繋ぐ「コネクタ」のような役割
# 
# なぜ必要？
# - IAMロールは論理的な権限の集合体
# - EC2インスタンスは物理的なコンピューティングリソース
# - この2つを直接結びつけることはできないため、インスタンスプロファイルという中間層が必要
# 
# 流れ: EC2インスタンス → インスタンスプロファイル → IAMロール → 権限
# これにより、EC2インスタンス内のアプリケーションがAWS APIを呼び出すときに
# 自動的にIAMロールの権限を使って認証・認可が行われます
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name # 上で作成したロールをこのプロファイルに関連付け
}
