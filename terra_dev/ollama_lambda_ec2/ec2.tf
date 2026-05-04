# EC2インスタンス
# ----------------
# このEC2は default public subnet に配置し、public IP を持たせています。
# これにより、NAT Gateway を別途用意しなくても、初期セットアップ、パッケージ取得、
# モデルのダウンロード、Session Manager 経由の運用が可能になります。
# なお、インターネットからの受信を広く開ける構成にはしていません。

resource "aws_instance" "ollama" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  # local.ec2_subnet_id は variables.tf で計算しており、その元は data.tf の
  # data.aws_subnets.default です。つまり「default subnet を実際に使っている場所」は
  # この subnet_id の指定箇所です。
  subnet_id                   = local.ec2_subnet_id
  associate_public_ip_address = true
  # EC2 に IAM ロールの権限を渡すには、ロールをそのまま直接ぶら下げるのではなく、
  # Instance Profile 経由で関連付けます。
  # この設定では aws_iam_instance_profile.ec2 の中に aws_iam_role.ec2 が入り、
  # インスタンス内のプロセスは IMDS から一時クレデンシャルを取得できます。
  # その結果、このEC2は AmazonSSMManagedInstanceCore の権限で Systems Manager
  # (Session Manager など) を利用でき、SSH鍵を前提にしない運用が可能になります。
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data              = file("${path.module}/user_data.sh")
  # user_data.sh が変わったら既存インスタンスをそのまま残さず、インスタンスを作り直します。
  # user_data は通常「初回起動時にだけ」実行されるため、この設定がないと user_data を
  # 変更しても既存サーバーにその差分が自動反映されないことがあります。
  user_data_replace_on_change = true

  # EC2 Instance Metadata Service (IMDS) の設定です。
  # IMDS は、インスタンス内のアプリケーションが「自分自身のメタデータ」を取得するための
  # 仕組みで、たとえば instance-id、AZ、アタッチされた IAM ロールの一時認証情報などを
  # 取得できます。ここでは、IMDS を有効にするか、IMDSv2 のトークンを必須にするか、
  # 応答の hop 数をいくつまで許すか、タグも参照可能にするかを制御しています。
  metadata_options {
    # IMDS 自体を有効化します。これにより、インスタンス内のソフトウェアはメタデータや
    # IAM ロールの一時クレデンシャルを取得できます。
    http_endpoint = "enabled"
    # IMDSv2 のトークンを必須にします。
    # このトークンは、メタデータを読む前にインスタンス内のクライアントが先に取得する
    # 短命なセッショントークンで、以後のメタデータ取得リクエストにヘッダーで添付します。
    # これにより、古い IMDSv1 のような「ヘッダーなしの単純な HTTP アクセス」を拒否でき、
    # SSRF などによる認証情報の取り出しリスクを下げられます。
    http_tokens = "required"
    # IMDS 応答を受け取れるネットワーク hop 数の上限です。
    # 1 が最も厳格で、2 にするとコンテナや中間ネットワーク層が入る構成でも少し余裕を
    # 持たせられます。この構成では 2 を許可しています。
    http_put_response_hop_limit = 2
    # EC2 タグを IMDS 経由でも参照できるようにします。
    # インスタンス内の処理が、自分に付いたタグを設定情報として読みたい場合に使えます。
    instance_metadata_tags = "enabled"
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.name_prefix}-ec2"
    Role = "ollama-server"
  }
}
