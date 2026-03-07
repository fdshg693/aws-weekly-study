# 最新のAmazon Linux 2023 AMIを取得
# AMIとは、Amazon Machine Imageの略で、EC2インスタンスのOSイメージのこと
# dataブロックは実行のたびに最新の情報を取得する
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  # AMIフィルタリング条件　複数を指定するとAND条件で絞り込み

  # 名前に"al2023-ami-*-x86_64"を含むものを対象
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  # 仮想化タイプが"hvm"のものを対象
  # hvmとは、ハードウェア仮想化を利用したAMIのこと
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# デフォルトVPCを取得
# AWSアカウントを作成したときに各リージョンに自動的に作成される、事前設定済みのVPC(Virtual Private Cloud)
# CIDR範囲: 172.31.0.0/16 が割り当てられる
# サブネット: 各アベイラビリティゾーン(AZ)に自動的にパブリックサブネットが作成される
# 本番環境では非推奨: セキュリティ上の理由から、本番環境では専用のカスタムVPCを作成することが推奨されます

# 既に存在するリソースを参照するため、resourceではなくdataを使用
data "aws_vpc" "default" {
  default = true
}
