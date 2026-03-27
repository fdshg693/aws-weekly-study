# terra_prod/s3 リファクタプラン

## 目的

`terra_prod/s3` は現時点でも Terraform としては動作するが、以下の課題を抱えている。

- 開発環境と本番環境が**論理上は別環境に見える一方、実態としては同じバケット命名規則に依存**している
- 本番向けの配信設計が **S3 Website 配信** と **将来の CloudFront 配信** の中間状態になっている
- タグ、命名、ポリシー、環境差分の責務が複数ファイルに分散しており、変更影響の見通しが悪い
- セキュリティ、監視、CI/CD、テスト、ドキュメントを含めて、学習用から実運用寄りへ進化させる余地が大きい

このドキュメントでは、上記を解消しつつ、既存の `NEXTSTEP.md` に記載した改善・拡張案も**すべて実施する前提**で、段階的なリファクタ計画を整理する。

## 基本方針

今回のリファクタは、単なるコード整理ではなく、以下を同時に達成することを目的とする。

1. **環境分離の明確化**
	- dev / prod / 将来の staging を、設定だけでなくリソース単位でも分離しやすい構成にする
2. **配信責務の分離**
	- 開発向けの S3 Website Hosting と、本番向けの CloudFront + private S3 構成を明確に分ける
3. **設定の一元化**
	- タグ、命名、環境差分、セキュリティ設定を `locals` / `variables` / `modules` に整理する
4. **将来拡張しやすい構造化**
	- CloudFront、Route53、CI/CD、テスト、監視を追加しても破綻しない構成にする
5. **ドキュメントと実装の整合性向上**
	- README / NEXTSTEP / 実装コードの説明を一致させる

## 現状の主要課題

### 1. 環境ごとのバケット分離が不十分

現状の `locals.tf` では、バケット名に `environment` が含まれていないため、`dev.tfvars` と `prod.tfvars` を切り替えても、同一の命名規則で同じ用途のバケットを扱う構造になっている。

#### 影響

- 開発環境と本番環境の独立性が弱い
- セキュリティ設定や配信設定を環境ごとに安全に切り替えにくい
- 将来 staging を追加した際に命名衝突や意図しない再利用を招きやすい

### 2. 本番の配信モデルが未分離

現状は `aws_s3_bucket_website_configuration` が常に存在しつつ、本番では public access を閉じる構成になっている。これにより、dev 向け構成と prod 向け構成が同一実装内で混在している。

#### 影響

- 本番環境の endpoint / output の意味が曖昧になる
- CloudFront 導入時に差分実装が増えやすい
- 「S3 Website を直接公開する構成」と「CloudFront のみ公開する構成」の責務が混ざる

### 3. タグと命名ルールの定義が分散

`provider.tf` の `default_tags`、各リソースの `tags`、`backend_bootstrap` 側のタグ変数が一貫しておらず、共通ルールとしてまとまっていない。

#### 影響

- タグポリシー変更時の修正箇所が多い
- 実際の `environment` と `Environment` タグ値が一致しない
- 学習用から実務寄りへ移行する際に運用コストが上がる

### 4. ポリシー記述方式が統一されていない

ログバケット側では `aws_iam_policy_document` を使っているが、静的サイト本体バケットは `jsonencode` 直書きであり、将来の拡張時に可読性と保守性の差が出る。

### 5. セキュリティ設定の成熟度がバケット間で不均一

ログバケットには ownership controls や lifecycle がある一方で、本体バケットには暗号化や ownership controls が未整理で、ガードレールの粒度が揃っていない。

### 6. 環境差分の表現が散在

`local.is_production` による条件分岐が複数ファイルに点在しており、環境差分の全体像を追いにくい。

### 7. オブジェクト配信設定が最低限に留まっている

`s3_objects.tf` はシンプルだが、MIME type、`Cache-Control`、SPA 配信やアセット配信最適化の観点では拡張余地が大きい。

### 8. backend lock の将来方針がコード上で明示されていない

`use_lockfile = true` と `dynamodb_table` を併用する方針は README に記載済みだが、将来的に DynamoDB 依存を縮小する方針が実装上では表現されていない。

### 9. README / NEXTSTEP / 実装の責務分離が曖昧

現状は「今できること」「今後やること」「本番想定の理想構成」が混在しており、読む人が現状把握しにくい。

## リファクタ後の到達イメージ

最終的には以下の状態を目指す。

- dev は **S3 Website で素早く確認できる構成**
- prod は **CloudFront + private S3 + HTTPS + ドメイン + ログ + 監視** を備えた構成
- 環境差分は `locals` またはモジュール引数に集約され、個別ファイルに散らばらない
- バケット命名、タグ、ポリシー、暗号化、ログ、出力値の設計が統一される
- backend bootstrap も含めて、運用方針がコードとドキュメントに一致する
- CI/CD、テスト、セキュリティスキャン、監視まで含めた「継続運用可能な構成」になる

## 実施スコープ

以下は**すべて実施対象**とする。

### A. コア構造のリファクタ

- [x] バケット命名規則に `environment` を含める
- [x] ログバケットも環境ごとに分離する
- [x] 将来の staging 追加を考慮した naming strategy にする
- [x] 共通タグを `default_tags` または `locals.common_tags` に集約する
- [x] `backend_bootstrap` 側のタグ変数を実際に反映する
- [x] 環境差分を `local.env_config` のような map に集約する
- [x] policy 定義を `aws_iam_policy_document` ベースに統一する
- [x] `jsonencode` 直書き箇所を整理する
- [x] 配信方式の責務を明確化する
- [x] dev / prod の構成差をモジュールまたは明確な構成分離で表現する

### B. S3 本体バケットの改善

- [ ] サーバーサイド暗号化（SSE-S3 または SSE-KMS）を追加する
- [ ] バケット暗号化のデフォルト設定を追加する
- [ ] 必要に応じて KMS カスタマー管理キー利用へ拡張可能にする
- [ ] ownership controls を本体バケットにも追加する
- [ ] バージョニング運用方針を環境ごとに整理する
- [ ] ライフサイクルポリシーを導入する
- [ ] 古いバージョンの削除ルールを追加する
- [ ] Intelligent-Tiering の利用可否を検討・実装する
- [ ] 非完了 multipart upload の削除ルールを追加する

### C. S3 オブジェクト配信まわりの改善

- [ ] MIME type マッピングを拡充する
- [ ] `Cache-Control` ヘッダー設定を導入する
- [ ] HTML と静的アセットでキャッシュ戦略を分ける
- [ ] 将来の SPA ルーティングに備えた配信設計にする
- [ ] 必要に応じて index fallback 設定方針を整理する

### D. CloudFront / Route53 / HTTPS 対応

- [ ] CloudFront ディストリビューションを追加する
- [ ] OAI または OAC を設定する（可能であれば OAC を優先）
- [ ] S3 バケットポリシーを CloudFront 経由のみに制限する
- [ ] HTTPS 対応のため ACM 証明書を連携する
- [ ] カスタムドメインを設定する
- [ ] Route53 統合を追加する
- [ ] CloudFront アクセスログを有効化する
- [ ] CloudFront キャッシュポリシーを最適化する
- [ ] キャッシュ無効化戦略を整備する

### E. backend / state 管理の改善

- [x] `backend_bootstrap` の命名・タグ・説明を本体と整合させる
- [x] `use_lockfile = true` を主軸とした方針を明示する
- [x] DynamoDB lock をオプション化するか、互換運用であることを明確化する
- [x] backend 出力例を現在の運用方針に合わせて整理する
- [x] 実ファイル生成フローとドキュメントを見直す

### F. モジュール化

- [ ] 再利用可能な Terraform モジュールへ分離する
- [ ] 入力変数を整理する
- [ ] バケット名 prefix / project 名 / tags / ドメイン名などを変数化する
- [ ] ルートモジュールを薄く保つ構成にする
- [ ] 将来的なモジュールバージョン管理を見据えた構成にする

### G. CI/CD・品質担保

- [ ] GitHub Actions 等で `terraform fmt` を自動実行する
- [ ] `terraform validate` を自動実行する
- [ ] Pull Request 時に plan を自動実行する
- [ ] 本番適用に承認フローを追加する
- [ ] tfsec によるセキュリティスキャンを追加する
- [ ] checkov による構成検証を追加する
- [ ] 必要に応じて AWS Config 連携を検討する

### H. 監視・コスト・運用

- [ ] CloudWatch メトリクス監視を追加する
- [ ] 4xx / 5xx エラー率監視を追加する
- [ ] 異常トラフィック検知アラームを追加する
- [ ] SNS 通知を統合する
- [ ] コスト可視化用タグを最適化する
- [ ] コストアラートを設計する

### I. テスト

- [ ] Terratest によるインフラテストを追加する
- [ ] バケットポリシーの検証テストを追加する
- [ ] エンドポイント疎通確認を自動化する
- [ ] セキュリティ設定の検証を追加する

### J. 高度機能

- [ ] CloudFront Functions または Lambda@Edge を検討する
- [ ] SPA ルーティングを実装する
- [ ] Basic 認証などの簡易アクセス制御の適用可否を検討する
- [ ] A/B テストやカナリアリリースに対応可能な構成を検討する

### K. 環境管理

- [ ] staging 環境を追加する
- [ ] 各環境の tfvars / backend / ドメイン / ログを整理する
- [ ] Terraform Workspace 採用可否を比較検討する

### L. ドキュメント

- [ ] `README.md` を「現状」「制約」「将来構成」に整理する
- [ ] `NEXTSTEP.md` を roadmap として再編する
- [ ] `REFACTOR.md` を実施計画書として維持する
- [ ] アーキテクチャ図を追加する
- [ ] トラブルシューティングガイドを追加する
- [ ] ロールバック手順書を追加する
- [ ] DR 観点のメモを追加する

## 実装方針の詳細

### 1. 命名規則の統一

以下のような情報を組み合わせてリソース名を生成する。

- project 名
- environment
- account id
- region
- resource role

例:

- 静的サイト本体バケット
- アクセスログ用バケット
- CloudFront 関連ログプレフィックス
- backend state バケット
- lock table

命名規則は `locals` で統一し、個別リソースでは再定義しない。

### 2. 環境差分の集約

環境差分は `local.is_production` のような単純ブール値だけでなく、次のような設定マップで表現する。

- website endpoint を有効にするか
- public read を許可するか
- versioning を有効にするか
- CloudFront を有効にするか
- custom domain を使うか
- 厳しめのセキュリティ設定を適用するか

これにより、「どの環境で何が有効か」が 1 箇所で分かる状態にする。

### 3. 配信方式の分離

配信責務は最低でも以下のどちらかで分ける。

#### 案1: モジュール分離

- `modules/s3_static_website_public`
- `modules/s3_static_site_cloudfront_private`

#### 案2: 単一モジュール + 明示的な mode 変数

- `delivery_mode = "s3_public"`
- `delivery_mode = "cloudfront_private"`

最終的には、**本番では S3 Website endpoint を公開経路にしない** 方針とする。

### 4. タグ設計の統一

共通タグの候補:

- `ManagedBy = Terraform`
- `Project = terra-prod-s3` または統一した project 名
- `Environment = development | production | staging`
- `Purpose = static website hosting | access log storage | terraform remote state`

resource ごとの `tags` は、共通タグに対して差分だけを載せる構成にする。

### 5. ポリシー記述の統一

バケットポリシーは原則として `aws_iam_policy_document` を利用する。

理由:

- statement の追加や条件分岐がしやすい
- CloudFront OAC/OAI への移行時の差分が追いやすい
- JSON 直書きよりレビューしやすい

### 6. セキュリティベースラインの整備

少なくとも以下を全 S3 バケットで方針として整理する。

- public access block
- encryption
- ownership controls
- logging
- lifecycle
- secure transport の強制

dev では一部緩和が必要な場合でも、「なぜ緩和するのか」をコメントとドキュメントで説明できる状態にする。

## 推奨実施順序

### Phase 1: 構造の土台を整える

最初に、後続フェーズへ影響が大きいコア部分を直す。

- [x] 命名規則の統一
- [x] 環境分離の明確化
- [x] タグの一元化
- [x] 環境差分マップ化
- [x] policy 記述方式の統一
- [x] backend 方針の明確化

### Phase 2: S3 セキュリティと配信の整理

- [ ] 本体バケットの暗号化
- [ ] ownership controls の導入
- [ ] lifecycle の追加
- [ ] オブジェクト metadata / cache 制御の導入
- [ ] S3 Website と CloudFront 配信責務の分離

### Phase 3: 本番構成への進化

- [ ] CloudFront 追加
- [ ] OAC / OAI 設定
- [ ] HTTPS / ACM / Route53 対応
- [ ] CloudFront ログとキャッシュ戦略の整備

### Phase 4: 運用品質の強化

- [ ] CI/CD 自動化
- [ ] tfsec / checkov / validate / plan の自動実行
- [ ] Terratest 導入
- [ ] CloudWatch / SNS 監視
- [ ] コスト監視

### Phase 5: 拡張性とドキュメント整備

- [ ] モジュール化完了
- [ ] staging 追加
- [ ] 高度ルーティング・SPA 対応
- [ ] README / NEXTSTEP / REFACTOR の再整理
- [ ] 補助ドキュメント整備

## ファイル単位の見直し方針

### `locals.tf`

- 命名規則の中心にする
- 共通タグを定義する
- MIME type / cache rule / 環境設定マップをまとめる

### `variables.tf`

- project 名、tags、delivery mode、domain、certificate などを追加する
- optional / required の境界を見直す
- validation を強化する

### `provider.tf`

- `default_tags` を本格利用する
- 必要に応じて `allowed_account_ids` 等のガードレールを検討する

### `s3_bucket.tf`

- 本体バケットのベースライン設定を集約する
- versioning / encryption / ownership controls を整理する

### `s3_policy.tf`

- `aws_iam_policy_document` ベースへ統一する
- dev / prod の公開制御責務を分離する

### `s3_website.tf`

- dev 専用に寄せるか、mode 変数で出し分ける
- prod で不要な website endpoint を安易に持たない構造にする

### `s3_logging.tf`

- S3 access log / CloudFront log の責務整理
- ログバケットの naming / lifecycle / policy を本体設計に揃える

### `s3_objects.tf`

- MIME type / cache control / asset strategy を整理する
- 必要に応じて HTML と asset で分岐する

### `outputs.tf`

- dev / prod で意味のある output のみ出す
- website endpoint, CloudFront domain, custom domain を役割ごとに整理する

### `backend_bootstrap/*`

- 本体と同じ命名・タグ・運用ルールに揃える
- DynamoDB lock の扱いを明確化する

### `README.md` / `NEXTSTEP.md`

- README: 現状の使い方と制約
- NEXTSTEP: 中長期 roadmap
- REFACTOR: 実施計画と設計判断

## 完了条件

以下を満たしたら、本リファクタは完了とみなす。

- dev / prod / staging が命名・設定・公開経路の面で分離されている
- 本番環境は CloudFront + HTTPS + private S3 で運用可能である
- バケット、ログ、backend のタグ・暗号化・ポリシー方針が統一されている
- `terraform fmt` / `terraform validate` / セキュリティスキャン / テストが自動実行される
- README / NEXTSTEP / REFACTOR が実装状態と矛盾しない

## 実施時の注意

- リソース命名変更は既存 state や実バケット移行に影響するため、適用順序を慎重に設計する
- CloudFront / Route53 / ACM はリージョン要件や証明書発行手順を踏まえる必要がある
- S3 Website endpoint と CloudFront private origin は共存できるが、本番公開経路は一本化する
- backend 周りの変更は state 管理に直結するため、別フェーズで安全に実施する

## 備考

本ドキュメントは、単なる改善メモではなく、`terra_prod/s3` を

- 学習用サンプル
- 再利用可能な Terraform 構成
- 実運用へ近づけた静的サイト配信基盤

へ育てるための実施計画である。

今後の実装では、この `REFACTOR.md` を基準に、各フェーズごとに差分を反映しながら進める。
