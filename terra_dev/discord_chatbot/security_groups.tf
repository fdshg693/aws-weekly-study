# ============================================
# セキュリティグループ設定
# ============================================
# Discordチャットボット用のセキュリティグループを定義します
# セキュリティグループは仮想ファイアウォールとして機能し、
# EC2インスタンスへの通信を制御します

# ============================================
# データソース: デフォルトVPC
# ============================================
# AWSアカウントに自動作成されるデフォルトVPCの情報を取得します
# 
# デフォルトVPCについて:
# - 各リージョンに1つ自動作成される
# - CIDR: 172.31.0.0/16
# - インターネットゲートウェイが自動で設定済み
# - パブリックIPアドレスが自動割り当てされる
# 
# 本番環境での推奨:
# - カスタムVPCの作成を推奨（セキュリティとネットワーク設計の柔軟性）
# - デフォルトVPCは削除または使用禁止にすることを検討
data "aws_vpc" "default" {
  default = true
}

# ============================================
# セキュリティグループ: Discordチャットボット用
# ============================================
# このセキュリティグループは以下の通信を許可します:
# - インバウンド: SSH接続（管理用）
# - アウトバウンド: HTTPS/HTTP通信（Discord API、パッケージインストール）

resource "aws_security_group" "discord_chatbot" {
  # セキュリティグループの基本情報
  # ----------------------------------
  # name: セキュリティグループ名（AWS内で一意である必要がある）
  # 命名規則: {プロジェクト}-{環境}-{用途}-sg
  name        = "${var.project_name}-${var.environment}-discord-chatbot-sg"
  description = "Security group for Discord Chatbot - Allows SSH management access and Discord API communication"

  # VPC ID: このセキュリティグループを配置するVPC
  vpc_id = data.aws_vpc.default.id

  # タグ設定
  # ----------------------------------
  # ベストプラクティス:
  # - Name: AWSコンソールで表示される名前
  # - Environment: 環境の識別（dev/stg/prod）
  # - Project: プロジェクトの識別
  # - ManagedBy: インフラ管理ツールの明示
  # - Purpose: リソースの用途を明確に記述
  tags = {
    Name        = "${var.project_name}-${var.environment}-discord-chatbot-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Purpose     = "Discord チャットボットVM用セキュリティグループ"
  }
}

# ============================================
# インバウンドルール: SSH接続
# ============================================
# 管理者がEC2インスタンスにSSH接続するためのルール
# 
# セキュリティのベストプラクティス:
# - 特定のIPアドレスのみに制限（var.my_ipで指定）
# - 0.0.0.0/0（全開放）は絶対に避ける
# - キーペアによる認証を必須とする
# - パスワード認証は無効化する
# 
# より安全な代替手段:
# 1. AWS Systems Manager Session Manager
#    - SSHポート不要、IAMベースの認証
#    - 操作ログが自動記録される
#    - インターネット接続不要（プライベートサブネットでも可）
# 
# 2. SSHポート変更
#    - デフォルトの22番ポートから変更（ポートスキャン対策）
#    - 例: 2222, 10022など
# 
# 3. VPN経由でのアクセス
#    - AWS Client VPN、Site-to-Site VPN
#    - よりセキュアな接続環境
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  # 関連付けるセキュリティグループ
  security_group_id = aws_security_group.discord_chatbot.id

  # プロトコルとポート設定
  # ----------------------------------
  # ip_protocol: 通信プロトコル（tcp, udp, icmp, または -1 で全て）
  # from_port: 開始ポート番号
  # to_port: 終了ポート番号（単一ポートの場合は from_port と同じ値）
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22

  # 送信元の指定
  # ----------------------------------
  # CIDR形式でIPアドレス範囲を指定
  # 例:
  # - 203.0.113.1/32: 単一のIPアドレス（/32は1つのIP）
  # - 203.0.113.0/24: 203.0.113.0 ～ 203.0.113.255（256個のIP）
  # - 0.0.0.0/0: 全てのIPアドレス（本番環境では非推奨）
  cidr_ipv4 = var.my_ip

  # 説明（オプション）
  # ----------------------------------
  # ルールの目的を明記することで、後から見た時に理解しやすくなる
  # 最大255文字まで
  description = "SSH access from administrator IP"

  # タグ（オプション）
  # ----------------------------------
  # ルール自体にもタグを付けることができる
  # セキュリティ監査や自動化に有用
  tags = {
    Name    = "SSH - Admin Access"
    Purpose = "管理者用SSH接続"
  }
}

# ============================================
# アウトバウンドルール: HTTPS通信
# ============================================
# Discord APIとの通信、および安全なパッケージダウンロードに必要
# 
# HTTPS (443) が必要な理由:
# - Discord API通信: Discordボットの全ての通信はHTTPS経由
# - WebSocket接続: Discordのリアルタイム通信もHTTPS上で確立
# - パッケージインストール: pip、apt、yumなどの安全なダウンロード
# 
# セキュリティ上の考慮事項:
# - アウトバウンドは基本的に制限が緩い（内部から外部への通信）
# - より厳密な制御が必要な場合:
#   * Discord APIのIP範囲に限定（但しDiscordのIPは変動する可能性あり）
#   * NAT Gateway経由にして送信元IPを固定
#   * プロキシサーバー経由でトラフィックを監視
resource "aws_vpc_security_group_egress_rule" "https" {
  # 関連付けるセキュリティグループ
  security_group_id = aws_security_group.discord_chatbot.id

  # プロトコルとポート設定
  # ----------------------------------
  # HTTPS: TCP/443
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  # 宛先の指定
  # ----------------------------------
  # 0.0.0.0/0: 全てのインターネット上のアドレスへの通信を許可
  # Discord APIは複数のエンドポイントを使用するため、全開放が推奨
  cidr_ipv4 = "0.0.0.0/0"

  # 説明
  description = "HTTPS outbound for Discord API and secure package downloads"

  # タグ
  tags = {
    Name    = "HTTPS - Outbound"
    Purpose = "Discord API通信・セキュアなパッケージダウンロード"
  }
}

# ============================================
# アウトバウンドルール: HTTP通信
# ============================================
# パッケージマネージャーによるソフトウェアインストールに必要
# 
# HTTP (80) が必要な理由:
# - パッケージリポジトリ: 一部のLinuxパッケージリポジトリはHTTPのみ対応
# - リダイレクト処理: HTTPからHTTPSへのリダイレクトを処理
# - ミラーサイト: 地域によってはHTTPミラーを使用する場合がある
# 
# セキュリティ上の懸念:
# - HTTP通信は暗号化されていない（盗聴・改ざんのリスク）
# - Man-in-the-Middle攻撃の可能性
# 
# より安全な代替案:
# 1. HTTPSのみに制限
#    - 全てのリポジトリをHTTPS対応に変更
#    - apt/yumの設定でHTTPSミラーを優先
# 
# 2. プライベートリポジトリの使用
#    - S3やArtifactoryなど社内リポジトリを構築
#    - VPCエンドポイント経由でアクセス（インターネット不要）
# 
# 3. 初期セットアップ後は削除
#    - 必要なパッケージインストール後、このルールを削除
#    - 更新時のみ一時的に追加
resource "aws_vpc_security_group_egress_rule" "http" {
  # 関連付けるセキュリティグループ
  security_group_id = aws_security_group.discord_chatbot.id

  # プロトコルとポート設定
  # ----------------------------------
  # HTTP: TCP/80
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80

  # 宛先の指定
  # ----------------------------------
  # 0.0.0.0/0: 全てのインターネット上のアドレスへの通信を許可
  cidr_ipv4 = "0.0.0.0/0"

  # 説明
  description = "HTTP outbound for package installation and repository access"

  # タグ
  tags = {
    Name    = "HTTP - Outbound"
    Purpose = "パッケージインストール・リポジトリアクセス"
  }
}

# ============================================
# 追加で検討すべきルール（コメントアウト例）
# ============================================

# 1. IPv6対応
# ------------
# IPv6アドレスからのアクセスを許可する場合
# resource "aws_vpc_security_group_ingress_rule" "ssh_ipv6" {
#   security_group_id = aws_security_group.discord_chatbot.id
#   ip_protocol       = "tcp"
#   from_port         = 22
#   to_port           = 22
#   cidr_ipv6         = "your-ipv6-address/128"  # IPv6アドレスを指定
#   description       = "SSH access from administrator IPv6"
# }

# 2. ICMP（Ping）の許可
# ----------------------
# インスタンスの疎通確認のためにPingを許可する場合
# resource "aws_vpc_security_group_ingress_rule" "icmp" {
#   security_group_id = aws_security_group.discord_chatbot.id
#   ip_protocol       = "icmp"
#   from_port         = -1  # ICMPではポート番号の代わりにtype
#   to_port           = -1  # -1は全てのICMPタイプを許可
#   cidr_ipv4         = var.my_ip
#   description       = "ICMP (Ping) from administrator IP"
# }

# 3. 特定のセキュリティグループからのアクセス
# ------------------------------------------
# 同じVPC内の別のセキュリティグループからのアクセスを許可
# 例: ロードバランサーからのアクセス、踏み台サーバーからのアクセス
# resource "aws_vpc_security_group_ingress_rule" "from_alb" {
#   security_group_id            = aws_security_group.discord_chatbot.id
#   ip_protocol                  = "tcp"
#   from_port                    = 8080
#   to_port                      = 8080
#   referenced_security_group_id = aws_security_group.alb.id  # 参照元のSG
#   description                  = "Access from Application Load Balancer"
# }

# 4. DNS解決のためのアウトバウンド（UDP/53）
# -----------------------------------------
# デフォルトでは全てのアウトバウンドが許可されているが、
# より厳密に制御したい場合は明示的に追加
# resource "aws_vpc_security_group_egress_rule" "dns" {
#   security_group_id = aws_security_group.discord_chatbot.id
#   ip_protocol       = "udp"
#   from_port         = 53
#   to_port           = 53
#   cidr_ipv4         = "0.0.0.0/0"
#   description       = "DNS resolution"
# }

# 5. NTPサーバーへのアクセス（UDP/123）
# ------------------------------------
# 時刻同期が重要なアプリケーションの場合
# resource "aws_vpc_security_group_egress_rule" "ntp" {
#   security_group_id = aws_security_group.discord_chatbot.id
#   ip_protocol       = "udp"
#   from_port         = 123
#   to_port           = 123
#   cidr_ipv4         = "0.0.0.0/0"
#   description       = "NTP time synchronization"
# }

# ============================================
# セキュリティグループのベストプラクティス
# ============================================
# 
# 1. 最小権限の原則
#    - 必要最小限の通信のみを許可
#    - 定期的にルールを見直し、不要なものは削除
# 
# 2. 送信元/宛先の明確な指定
#    - 0.0.0.0/0は可能な限り避ける
#    - 信頼できるIPアドレス範囲に限定
# 
# 3. 説明の記述
#    - 各ルールに明確な説明を付ける
#    - なぜそのルールが必要かを記録
# 
# 4. レイヤー化されたセキュリティ
#    - セキュリティグループだけでなく、NACLも併用
#    - WAF、IDS/IPSなどの追加セキュリティ対策
# 
# 5. 監査とコンプライアンス
#    - AWS Config: セキュリティグループの変更を記録
#    - CloudTrail: API呼び出しの監査ログ
#    - Security Hub: セキュリティのベストプラクティス確認
# 
# 6. ステートフル性の理解
#    - セキュリティグループはステートフル
#    - インバウンドを許可すれば、その応答は自動的に許可される
#    - 明示的な戻りトラフィックのルールは不要
# 
# 7. セキュリティグループの命名規則
#    - 一貫性のある命名規則を使用
#    - 環境、プロジェクト、用途を含める
#    - 例: {project}-{env}-{purpose}-sg
# 
# 8. チェーン参照の活用
#    - セキュリティグループ間での参照を活用
#    - IPアドレスの代わりにSG IDで指定
#    - 動的な環境での管理が容易
