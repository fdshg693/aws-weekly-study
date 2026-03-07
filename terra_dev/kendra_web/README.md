# Amazon Kendra Web Crawler

## 概要
Amazon KendraのIndexとWeb Crawler Data Sourceを構築するTerraform構成です。指定したWebサイトをクロールし、Kendraの検索インデックスに取り込むことで、サイト内の情報を検索可能にします。

### 技術スタック
- Terraform >= 1.0
- Amazon Kendra
- AWS IAM
- CloudWatch Logs

### 作成物
指定したSeed URLから始まるWebサイトをクロールし、そのコンテンツをKendraのインデックスに登録します。クロール範囲はURL包含/除外パターン（正規表現）で制御でき、定期的な自動同期や手動での同期トリガーが可能です。検索インデックスは指定した言語に最適化され、効率的な全文検索を実現します。

## 構成ファイル
- [provider.tf](provider.tf): AWS Provider設定
- [variables.tf](variables.tf): 変数定義（Seed URL、包含/除外パターン、言語設定等）
- [iam.tf](iam.tf): Kendra用IAMロール/ポリシー（CloudWatch Logs権限含む）
- [main.tf](main.tf): Kendra IndexとData Sourceの定義
- [outputs.tf](outputs.tf): Index IDとData Source IDの出力
- dev.tfvars / prod.tfvars: 環境別設定ファイル

## コードの特徴
- **URL制御**: `url_inclusion_patterns`と`url_exclusion_patterns`を正規表現で指定することで、柔軟なクロール範囲の制御が可能
- **多言語対応**: `data_source_language_code`変数により、日本語（`ja`）や英語（`en`）など、インデックスの言語を最適化
- **スケジュール同期**: `schedule`変数にcron式を設定することで、定期的な自動同期を実現（未設定時はオンデマンド同期のみ）
- **CloudWatch Logs統合**: IAMポリシーで`logs:DescribeLogGroups`権限を付与し、Kendraのログ出力を適切に処理
- **環境分離**: tfvarsファイルによる開発環境と本番環境の設定分離

## 注意事項
- Kendraはリージョン依存のサービスのため、`aws_region`を適切に設定してください
- Web Crawlerの正規表現パターンはTerraform文字列内で記述するため、`\\.`のようなエスケープが必要です
- 初回のData Source同期は手動トリガーまたはスケジュール実行まで開始されません
- Kendraの料金は高額になる可能性があるため、使用後は`terraform destroy`での削除を推奨します
- AWS認証情報（`AWS_PROFILE`または`AWS_ACCESS_KEY_ID`等）が事前に設定されている必要があります
- CloudWatch Logsの`logs:DescribeLogGroups`権限が不足している場合、同期時にエラーが発生する可能性があります（[iam.tf](iam.tf)で対処済み）
