# S3 Static Website Hosting - Terraform構成

## 概要
S3を使った静的ウェブサイトホスティングのTerraform構成。開発環境と本番環境で異なる設定を適用可能。

## 構成ファイル

### コア設定
- **`provider.tf`**: Terraformプロバイダー設定（AWS Provider v6.0）
- **`variables.tf`**: 変数定義（リージョン、環境）
- **`locals.tf`**: ローカル変数（バケット名生成、MIMEタイプマッピング）
- **`outputs.tf`**: 出力値定義（ウェブサイトURL、バケット名）

### リソース定義
- **`s3_bucket.tf`**: S3バケット本体とバージョニング設定
- **`s3_policy.tf`**: パブリックアクセス設定とバケットポリシー
- **`s3_website.tf`**: 静的ウェブサイトホスティング設定
- **`s3_objects.tf`**: ファイルアップロード設定（自動MIMEタイプ判定）

### 環境別設定
- **`dev.tfvars`**: 開発環境設定
- **`prod.tfvars`**: 本番環境設定

## 主な機能

### 1. 環境別設定
- **開発環境**: パブリックアクセス許可、バージョニング停止
- **本番環境**: パブリックアクセスブロック、バージョニング有効

### 2. 自動化機能
- バケット名の自動生成（アカウントID + リージョンで一意性を確保）
- ファイル拡張子による自動MIMEタイプ判定
- ファイル変更検知（ETag/MD5ハッシュ）

### 3. セキュリティ
- 本番環境では完全なパブリックアクセスブロック
- 環境変数のバリデーション（リージョン、環境名）
- Terraform管理タグの自動付与

## 使用方法

### 初期化
```bash
terraform init
```

### 開発環境へのデプロイ
```bash
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### 本番環境へのデプロイ
```bash
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

### リソースの削除
```bash
terraform destroy -var-file="dev.tfvars"
```

## 出力情報
- `website_endpoint`: S3ウェブサイトエンドポイント
- `bucket_name`: 作成されたバケット名
- `website_url`: 完全なウェブサイトURL（http://付き）

## ファイル構造
```
website/
├── index.html    # トップページ
└── error.html    # エラーページ
```

## 対応MIMEタイプ
- HTML (.html)
- CSS (.css)
- JavaScript (.js)
- JSON (.json)
- PNG (.png)
- JPEG (.jpg)
- SVG (.svg)

## 注意事項
- バケット名はグローバルで一意である必要があります
- 本番環境ではCloudFront経由のアクセスを推奨（現在は未実装）
- S3ウェブサイトエンドポイントはHTTPのみ対応（HTTPSはCloudFrontで実装）
