# ============================================================================
# Discord Chatbot EC2 Instance Configuration
# ============================================================================
# このファイルはDiscord Chatbotを実行するためのEC2インスタンスを定義します。
# 
# 構成要素:
# 1. データソース: 最新のAMI、VPC、サブネット情報の取得
# 2. キーペア: SSH接続用のキーペア作成
# 3. EC2インスタンス: チャットボット実行環境
#
# ============================================================================

# ============================================================================
# Local Values
# ============================================================================
# ローカル変数の定義
# 複数のリソースで共通して使用する値や、計算結果を保存します

locals {
  # Discord Bot Tokenの取得
  # 優先順位:
  # 1. 環境変数 TF_VAR_discord_bot_token が設定されている場合はそれを使用
  # 2. 未設定の場合は python/.env ファイルから読み取る
  discord_bot_token = var.discord_bot_token != "" ? var.discord_bot_token : trimspace(regex("DISCORD_BOT_TOKEN=(.+)", file("${path.module}/python/.env"))[0])
}

# ----------------------------------------------------------------------------
# Data Source: 最新のAmazon Linux 2023 AMI
# ----------------------------------------------------------------------------
# AWS公式が提供する最新のAmazon Linux 2023 AMIを自動的に取得します。
#
# Amazon Linux 2023の特徴:
# - 長期サポート（5年間のセキュリティアップデート）
# - Python 3.9が標準でインストール済み
# - dnfパッケージマネージャー使用（yumの後継）
# - systemd標準サポート
# - SELinux有効化（セキュリティ強化）
#
# 代替案:
# - Ubuntu 22.04 LTS: より広いコミュニティサポート、apt使用
# - Amazon Linux 2: 旧バージョンだが実績豊富（2025年サポート終了予定）
#
# フィルターの説明:
# - name: AMI名のパターンマッチング（ワイルドカード使用可）
# - virtualization-type: 仮想化タイプ（hvmが現在の標準）
# - architecture: CPUアーキテクチャ（x86_64またはarm64）
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ----------------------------------------------------------------------------
# Data Source: デフォルトサブネット
# ----------------------------------------------------------------------------
# 指定されたアベイラビリティゾーンのデフォルトサブネットを取得します。
#
# デフォルトサブネットの特徴:
# - デフォルトVPCに自動作成される
# - パブリックサブネット（インターネットゲートウェイ接続済み）
# - 自動パブリックIP割り当てが有効
#
# アベイラビリティゾーン（AZ）について:
# - 各リージョンに複数のAZが存在（東京リージョンは4つ: a, c, d）
# - AZ間は物理的に分離されており、障害発生時の影響を局所化
# - 高可用性構成では複数AZを使用することを推奨
#
# 本番環境での推奨:
# - カスタムVPC内にプライベートサブネットを作成
# - NAT Gatewayを経由してインターネットアクセス
# - マルチAZ構成でEC2インスタンスを冗長化
data "aws_subnet" "default" {
  # デフォルトサブネットであることを指定
  default_for_az = true

  # アベイラビリティゾーンを指定
  # 例: ap-northeast-1a, ap-northeast-1c, ap-northeast-1d
  # 変数化することで環境ごとに変更可能
  availability_zone = "${var.aws_region}a"

  # デフォルトVPCに属することを確認
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ----------------------------------------------------------------------------
# Resource: EC2キーペア（SSH接続用）
# ----------------------------------------------------------------------------
# EC2インスタンスにSSH接続するための公開鍵を登録します。
#
# 使い方:
# 1. ローカルで鍵ペアを生成:
#    ssh-keygen -t rsa -b 4096 -f ~/.ssh/discord-bot-key -N ""
# 2. 公開鍵を読み込んで登録（このリソース）
# 3. 秘密鍵でSSH接続:
#    ssh -i ~/.ssh/discord-bot-key ec2-user@<public-ip>
#
# セキュリティのベストプラクティス:
# - 秘密鍵は決してリポジトリにコミットしない（.gitignoreに追加）
# - 秘密鍵のパーミッションは600に設定（chmod 600 ~/.ssh/discord-bot-key）
# - 定期的な鍵のローテーション
# - パスフレーズ付き鍵の使用を推奨（-N ""を削除）
#
# 代替案:
# - AWS Systems Manager Session Manager（SSH不要、IAMベース認証）
# - EC2 Instance Connect（一時的な鍵をAWSが管理）
resource "aws_key_pair" "discord_bot" {
  # キーペア名
  # AWS内で一意である必要がある
  key_name = "${var.project_name}-${var.environment}-key"

  # 公開鍵の内容
  # ローカルマシンの公開鍵ファイルを読み込む
  # file()関数: ファイルの内容を文字列として読み込む
  # path.module: 現在のTerraformモジュールのディレクトリパス
  #
  # 注意: 実行前に公開鍵ファイルを作成する必要があります
  # 作成方法は上記のコメントを参照
  #
  # 公開鍵のパスは変数で管理（tfvarsファイルで変更可能）
  public_key = file("${path.module}/${var.ssh_public_key_path}")

  tags = {
    Name        = "${var.project_name}-${var.environment}-key"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Resource: EC2インスタンス（Discord Chatbot実行環境）
# ----------------------------------------------------------------------------
# Discord Chatbotを実行するためのEC2インスタンスを作成します。
#
# インスタンスの役割:
# - Pythonで書かれたDiscord Botアプリケーション（echo.py）の実行
# - systemdサービスとして常駐稼働
# - Discord APIとの通信（HTTPS/443）
resource "aws_instance" "discord_bot" {
  # AMI（Amazon Machine Image）
  # ----------------------------------
  # data sourceで取得した最新のAmazon Linux 2023を使用
  ami = data.aws_ami.amazon_linux_2023.id

  # インスタンスタイプ
  # ----------------------------------
  # t2.micro: 1 vCPU, 1GB RAM
  # 
  # 軽量なDiscord Botには十分なスペック
  # AWS無料利用枠対象（月750時間まで無料）
  # 
  # パフォーマンス不足の場合の対応:
  # - t2.small: 1 vCPU, 2GB RAM（メモリ増量）
  # - t3.micro: 2 vCPU, 1GB RAM（新世代、バースト性能向上）
  # - t3.small: 2 vCPU, 2GB RAM（推奨、バランス型）
  instance_type = var.instance_type

  # サブネット配置
  # ----------------------------------
  # デフォルトサブネット（パブリックサブネット）に配置
  # インターネットアクセスが可能
  subnet_id = data.aws_subnet.default.id

  # セキュリティグループ
  # ----------------------------------
  # security_groups.tfで定義されたセキュリティグループを適用
  # 
  # 許可される通信:
  # - インバウンド: SSH（22番ポート）- 管理用
  # - アウトバウンド: HTTPS（443番ポート）- Discord API通信
  # - アウトバウンド: HTTP（80番ポート）- パッケージインストール
  vpc_security_group_ids = [aws_security_group.discord_chatbot.id]

  # IAMインスタンスプロファイル
  # ----------------------------------
  # Systems Manager Session ManagerとCloudWatch Logsへのアクセス権限を付与
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # SSH接続用キーペア
  # ----------------------------------
  # EC2 Instance Connectやセキュリティ上の理由でSSH接続が不要な場合は省略可能
  # Session Managerを使用する場合はキーペアは必須ではない
  key_name = aws_key_pair.discord_bot.key_name

  # User Data（初期化スクリプト）
  # ----------------------------------
  # インスタンスの初回起動時に実行されるスクリプト
  # 
  # 実行内容（user_data.shの処理内容）:
  # 1. システムパッケージのアップデート
  # 2. Python3とpipのインストール
  # 3. AWS CLIとjqのインストール
  # 4. discord.pyとpython-dotenvのインストール
  # 5. アプリケーションディレクトリの作成（/opt/discord-bot）
  # 6. S3からBotスクリプト（echo.py）をダウンロード
  # 7. Secrets ManagerからDiscord Bot Tokenを取得
  # 8. 環境変数ファイル（.env）の自動生成
  # 9. systemdサービスの設定
  # 10. サービスの有効化と起動
  #
  # テンプレート変数:
  # - aws_region: AWSリージョン
  # - s3_bucket: アプリケーションファイルを保存するS3バケット名
  # - s3_script_key: S3バケット内のecho.pyのキー（パス）
  # - secrets_manager_secret_name: Secrets ManagerのシークレットAGE
  #
  # 注意点:
  # - user_dataは初回起動時のみ実行される
  # - 再実行が必要な場合は、インスタンスを再作成するか手動実行
  # - 実行ログは /var/log/user-data.log に記録される
  # - デバッグ時は `cat /var/log/user-data.log` でログ確認
  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region                   = var.aws_region
    s3_bucket                    = aws_s3_bucket.bot_assets.id
    s3_script_key                = aws_s3_object.echo_py.key
    secrets_manager_secret_name  = aws_secretsmanager_secret.discord_bot_token.name
    LOGFILE         = "/var/log/user-data.log"
    APP_DIR         = "/opt/discord-bot"
  })

  # ルートボリューム設定
  # ----------------------------------
  # EC2インスタンスのプライマリストレージ
  #
  # volume_size: ディスクサイズ（GB）
  # - Amazon Linux 2023 AMIは最低30GB必要
  # - Botアプリケーションには30GBで十分
  # - ログ量が多い場合は増量を検討
  #
  # volume_type: ストレージタイプ
  # - gp3: 汎用SSD（最新、コストパフォーマンス良好、推奨）
  # - gp2: 汎用SSD（従来型、安定した実績）
  # - io1/io2: プロビジョンドIOPS SSD（高性能、高コスト）
  # 
  # delete_on_termination: インスタンス削除時にボリュームも削除
  # - true: 削除される（開発環境推奨、コスト削減）
  # - false: 保持される（本番環境で重要データがある場合）
  #
  # encrypted: EBS暗号化
  # - true推奨（データ保護、コンプライアンス対応）
  # - KMSキーでカスタム暗号化も可能
  root_block_device {
    volume_size           = 60
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "${var.project_name}-${var.environment}-root-volume"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }

  # メタデータオプション
  # ----------------------------------
  # IMDSv2（Instance Metadata Service version 2）の設定
  #
  # IMDSとは:
  # - インスタンス内からインスタンス情報を取得するためのサービス
  # - http://169.254.169.254/ でアクセス可能
  # - IAMロールの一時認証情報もここから取得
  #
  # http_tokens = "required":
  # - IMDSv2を必須にする（セキュリティ強化）
  # - SSRFアタック対策
  # - セッショントークンベースの認証が必要
  #
  # http_put_response_hop_limit:
  # - メタデータリクエストのホップ数制限
  # - 1: インスタンス内からのみアクセス可能（最もセキュア）
  # - コンテナ環境では2以上が必要な場合あり
  #
  # ベストプラクティス:
  # - 常にIMDSv2を有効にする（required設定）
  # - hop_limitは最小限に設定
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # モニタリング設定
  # ----------------------------------
  # CloudWatch詳細モニタリングの有効化
  #
  # false（デフォルト）: 基本モニタリング（5分間隔、無料）
  # true: 詳細モニタリング（1分間隔、有料）
  #
  # 基本モニタリングのメトリクス:
  # - CPU使用率
  # - ディスクI/O
  # - ネットワークI/O
  # - ステータスチェック
  #
  # 詳細モニタリングが必要な場合:
  # - より短い間隔でメトリクスを確認したい
  # - Auto Scalingで素早くスケールしたい
  # - 問題の早期検出が重要
  monitoring = false

  # タグ設定
  # ----------------------------------
  # AWSリソースに付与するメタデータ
  #
  # タグのベストプラクティス:
  # 1. Name: リソースを識別するための分かりやすい名前
  # 2. Environment: 環境の識別（dev/stg/prod）
  # 3. Project: プロジェクト名
  # 4. ManagedBy: インフラ管理ツールの明示
  # 5. Owner/Team: 責任者やチーム名
  # 6. CostCenter: コスト配分用
  # 7. Application: アプリケーション名
  #
  # タグの利点:
  # - Cost Explorerでコスト分析が可能
  # - リソースのフィルタリングと検索
  # - 自動化スクリプトでの識別
  # - アクセス制御（タグベースのIAMポリシー）
  tags = {
    Name        = "${var.project_name}-${var.environment}-discord-bot"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Application = "Discord Chatbot"
    Description = "Discord Echo Bot Execution Environment"
  }

  # ライフサイクル設定
  # ----------------------------------
  # Terraformリソースの動作を制御
  #
  # ignore_changes: 指定した属性の変更を無視
  # - user_data: 初回起動後は変更不要（変更すると再作成される）
  #
  # 理由:
  # - user_dataの変更はインスタンス再作成を引き起こす
  # - 手動でインスタンス上のファイルを更新した場合、Terraformで差分が出ないようにする
  # - 再作成を避けたい場合に使用
  #
  # 注意:
  # - user_dataを変更して適用したい場合は、この設定を一時的に削除
  # - または、インスタンスを明示的に再作成（terraform taint）
  lifecycle {
    ignore_changes = [user_data]
  }
}
