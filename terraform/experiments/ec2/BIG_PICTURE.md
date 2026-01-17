# Big Picture - EC2 + Ansible Infrastructure

## アーキテクチャ全体像

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (ap-northeast-1)                  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                     Default VPC                               │  │
│  │                                                               │  │
│  │  ┌──────────────────────────────────────────────────────┐    │  │
│  │  │           Security Group                             │    │  │
│  │  │  • SSH (22)  ← allowed_ssh_cidr                     │    │  │
│  │  │  • HTTP (80)  ← 0.0.0.0/0                           │    │  │
│  │  │  • HTTPS (443) ← 0.0.0.0/0                          │    │  │
│  │  └────────────────────┬─────────────────────────────────┘    │  │
│  │                       │                                       │  │
│  │  ┌────────────────────▼──────────────────────────────┐       │  │
│  │  │         EC2 Instance (t2.micro/t3.small)          │       │  │
│  │  │  ┌──────────────────────────────────────────────┐ │       │  │
│  │  │  │   OS: Amazon Linux 2023                      │ │       │  │
│  │  │  │                                              │ │       │  │
│  │  │  │   user_data.sh (起動時実行)                 │ │       │  │
│  │  │  │   └─► pip3 install ansible                  │ │       │  │
│  │  │  │                                              │ │       │  │
│  │  │  │   Apps:                                      │ │       │  │
│  │  │  │   • Nginx (port 80)                          │ │       │  │
│  │  │  │   • Custom HTML (env-based)                  │ │       │  │
│  │  │  └──────────────────────────────────────────────┘ │       │  │
│  │  │                                                    │       │  │
│  │  │   EBS Volume (gp3, encrypted)                     │       │  │
│  │  │   └─► 8GB (default) / カスタマイズ可能             │       │  │
│  │  │                                                    │       │  │
│  │  │   IAM Instance Profile                             │       │  │
│  │  │   └─► Session Manager Access                      │       │  │
│  │  └────────────────────────────────────────────────────┘       │  │
│  │                       │                                       │  │
│  │                       ▼                                       │  │
│  │               Elastic IP (固定)                               │  │
│  │               └─► Public IP: x.x.x.x                         │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

                               ▲
                               │
          ┌────────────────────┴────────────────────┐
          │                                         │
    Terraform                                  Ansible
    (Infrastructure)                     (Configuration)
          │                                         │
          │                                         │
┌─────────▼─────────┐                    ┌──────────▼─────────┐
│  terraform apply  │                    │ run_playbook.sh    │
│  -var-file=dev    │                    │  • SSH接続         │
│                   │                    │  • Nginx install   │
│  作成リソース:    │                    │  • HTML deploy     │
│  • EC2            │                    └────────────────────┘
│  • Security Group │
│  • Elastic IP     │
│  • IAM Role       │
│  • Key Pair       │
└───────────────────┘

```

## デプロイフロー

```
[ローカルマシン]
     │
     │ 1. terraform init
     ▼
[Terraform State]
     │
     │ 2. terraform apply -var-file=dev.tfvars
     ▼
[AWS API] ──► リソース作成
     │
     ├─► EC2 Instance 起動
     │   └─► user_data.sh 実行
     │       └─► Ansible インストール
     │
     ├─► Security Group 作成
     ├─► IAM Role 作成
     ├─► Elastic IP 割り当て
     └─► SSH Key Pair 登録
     
     │ 待機 1〜2分（user_data完了）
     │
     │ 3. cd ansible && ./run_playbook.sh dev
     ▼
[SSH経由でAnsible実行]
     │
     ├─► Nginx インストール
     ├─► 環境変数ベースの設定
     └─► HTMLテンプレートデプロイ
     
     │
     ▼
[Webサーバー稼働] ← http://x.x.x.x/
```

## 主要な設計思想

### 1. 責務の分離
- **Terraform**: インフラの生成・破棄（イミュータブル）
- **Ansible**: アプリケーション設定（ミュータブル）

### 2. 環境管理
- `.tfvars`ファイルで環境を切り替え
- dev/prod で異なるインスタンスタイプ、セキュリティ設定が可能

### 3. セキュリティレイヤー
```
Internet
   │
   ▼
Security Group ──► IP制限、ポート制限
   │
   ▼
EC2 Instance ──► IAM Role（Session Manager）
   │
   ▼
EBS Volume ──► 暗号化（デフォルト有効）
```

### 4. アクセス方法の選択肢
- **SSH**: 従来型、Key Pair必須
- **Session Manager**: 推奨、Key Pair不要、監査ログ記録

## ファイル間の関係性

```
variables.tf ──► 変数定義
     │
     ▼
dev.tfvars / prod.tfvars ──► 環境別の値
     │
     ├─► provider.tf ──► AWS認証
     │
     ├─► data.tf ──► AMI、VPC取得
     │
     ├─► security_groups.tf ──► ファイアウォールルール
     │
     ├─► iam.tf ──► IAMロール、ポリシー
     │
     ├─► keypair.tf ──► SSH公開鍵登録
     │
     └─► main.tf ──► EC2、Elastic IP作成
             │
             └─► user_data.sh ──► 起動スクリプト
     
outputs.tf ──► IP、IDを出力
     │
     ▼
ansible/run_playbook.sh ──► 自動取得してAnsible実行
     │
     └─► playbook.yml ──► Nginx設定
             │
             └─► templates/index.html.j2 ──► HTMLテンプレート
```

## コスト最適化のポイント

1. **t2.micro** を選択すれば AWS 無料利用枠対象
2. **Elastic IP** は起動中のインスタンスに紐付けていれば無料
3. **EBS Volume** は gp3 で十分（コスト効率が良い）
4. 使わない時は `terraform destroy` でコストゼロ

## トラブルシューティングの流れ

```
問題発生
   │
   ├─► SSH接続できない？
   │   ├─► Security Group確認（allowed_ssh_cidr）
   │   ├─► Elastic IP確認（terraform output）
   │   └─► Key Pair確認（~/.ssh/id_rsa）
   │
   ├─► Ansibleが失敗？
   │   ├─► EC2起動直後？ → 1〜2分待つ
   │   ├─► user_data確認: ssh -> cat /var/log/user-data.log
   │   └─► Ansible詳細ログ: ansible-playbook -vvv
   │
   └─► Webサーバー見れない？
       ├─► Ansibleが実行された？ → ./run_playbook.sh dev
       ├─► Nginx起動確認: sudo systemctl status nginx
       └─► ポート確認: Security Groupで80/443開放？
```
