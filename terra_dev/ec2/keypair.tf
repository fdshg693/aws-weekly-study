# SSH公開鍵からKey Pairを作成（key_nameが指定されていない場合）
resource "aws_key_pair" "generated" {
  count      = var.key_name == "" ? 1 : 0
  key_name   = "${var.environment}-ec2-key"
  public_key = file(pathexpand(var.public_key_path)) # pathexpandによって、~をホームディレクトリに展開

  tags = {
    Name = "${var.environment}-ec2-key"
  }
}
