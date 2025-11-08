# S3 バケットポリシー サンプルフラグメント集

各フラグメントは実務で頻出するパターンを中心に、ステートメント内の主要要素を抜き出したものです。

## 1. 公開読み取り（静的Webサイトホスティング）

```json
{
  "Principal": "*",
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-website-bucket/*"
}
```
**用途**：全ての人がWebサイトのコンテンツを読み取り可能に設定

---

## 2. 特定のIAMユーザーに限定

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:user/alice"
  },
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::my-private-bucket/*"
}
```
**用途**：特定のIAMユーザーのみに読み書き権限を付与

---

## 3. 特定のIAMロールに限定

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:role/lambda-execution-role"
  },
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::lambda-data-bucket/*"
}
```
**用途**：Lambda関数がS3からデータを読み書きできるように設定

---

## 4. 別のAWSアカウント全体に許可（クロスアカウント）

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::987654321098:root"
  },
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::shared-bucket/*"
}
```
**用途**：別のAWSアカウント内の全てのエンティティがアクセス可能に設定

---

## 5. 特定のAWSサービスにのみ許可（CloudFront）

```json
{
  "Principal": {
    "Service": "cloudfront.amazonaws.com"
  },
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::cdn-bucket/*"
}
```
**用途**：CloudFrontディストリビューションがオリジンとしてアクセス

---

## 6. IP制限（社内ネットワークのみ）

```json
{
  "Principal": "*",
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::internal-docs-bucket/*",
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": ["203.0.113.0/24", "198.51.100.50/32"]
    }
  }
}
```
**用途**：特定のIPアドレスレンジからのアクセスのみ許可

---

## 7. SSL/TLS必須（暗号化通信のみ）

```json
{
  "Principal": "*",
  "Effect": "Deny",
  "Action": "s3:*",
  "Resource": ["arn:aws:s3:::secure-bucket", "arn:aws:s3:::secure-bucket/*"],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```
**用途**：HTTP通信を明示的に拒否し、HTTPSのみを強制

---

## 8. 特定のフォルダのみアクセス可能

```json
[
  {
    "Principal": {
      "AWS": "arn:aws:iam::123456789012:user/bob"
    },
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::data-bucket/public/*"
  },
  {
    "Principal": {
      "AWS": "arn:aws:iam::123456789012:user/bob"
    },
    "Effect": "Deny",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::data-bucket/private/*"
  }
]
```
**用途**：ユーザーがアクセスできるフォルダを明示的に制限

---

## 9. MFA認証必須（追加セキュリティ）

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:user/alice"
  },
  "Effect": "Allow",
  "Action": "s3:DeleteObject",
  "Resource": "arn:aws:s3:::critical-data-bucket/*",
  "Condition": {
    "Bool": {
      "aws:MultiFactorAuthPresent": "true"
    }
  }
}
```
**用途**：重要なデータ削除時にMFA認証を必須に設定

---

## 10. リファラ制限（特定のWebサイトからのみ）

```json
{
  "Principal": "*",
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::media-bucket/*",
  "Condition": {
    "StringLike": {
      "aws:Referer": "https://www.example.com/*"
    }
  }
}
```
**用途**：特定のWebサイトからのリクエストのみアクセス許可（ホットリンク対策）

---

## 11. 時間ベースのアクセス制限

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:user/alice"
  },
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "arn:aws:s3:::maintenance-bucket/*",
  "Condition": {
    "DateGreaterThan": {
      "aws:CurrentTime": "2025-01-01T00:00:00Z"
    },
    "DateLessThan": {
      "aws:CurrentTime": "2025-12-31T23:59:59Z"
    }
  }
}
```
**用途**：特定の期間のみアクセス可能に設定

---

## 12. ログ配信専用（CloudTrail/ELB からのみ書き込み）

```json
{
  "Principal": {
    "Service": "logging.s3.amazonaws.com"
  },
  "Effect": "Allow",
  "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::log-bucket/logs/*",
  "Condition": {
    "StringEquals": {
      "s3:x-amz-acl": "bucket-owner-full-control"
    }
  }
}
```
**用途**：ログ配信サービスがログファイルを自動書き込み

---

## 13. 読み取り専用アクセス（複数アクション指定）

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:role/read-only-role"
  },
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:ListBucket",
    "s3:GetBucketLocation"
  ],
  "Resource": [
    "arn:aws:s3:::read-only-bucket",
    "arn:aws:s3:::read-only-bucket/*"
  ]
}
```
**用途**：読み取り専用ロールに必要な複数のアクションを一度に付与

---

## 14. 拒否ルール（管理者以外の削除禁止）

```json
{
  "Principal": "*",
  "Effect": "Deny",
  "Action": "s3:DeleteObject",
  "Resource": "arn:aws:s3:::protected-bucket/*",
  "Condition": {
    "StringNotEquals": {
      "aws:PrincipalOrgID": "o-xxxxxxxxxx"
    }
  }
}
```
**用途**：特定の組織外のエンティティによるオブジェクト削除を禁止

---

## 15. ワイルドカードを使った柔軟なアクション指定

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:user/developer"
  },
  "Effect": "Allow",
  "Action": "s3:*Object",
  "Resource": "arn:aws:s3:::dev-bucket/*"
}
```
**用途**：GetObject、PutObject、DeleteObject など「*Object」にマッチする全てのアクションを許可

---

## 16. 複合条件（複数条件すべてを満たす場合のみ許可）

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:user/alice"
  },
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::multi-condition-bucket/*",
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": "203.0.113.0/24"
    },
    "StringEquals": {
      "aws:username": "alice"
    },
    "Bool": {
      "aws:SecureTransport": "true"
    }
  }
}
```
**用途**：IP制限 AND ユーザー確認 AND HTTPS通信の全てを満たす場合のみアクセス許可

---

## 17. 特定の拡張子のみを許可

```json
{
  "Principal": "*",
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::content-bucket/*.pdf",
  "Condition": {
    "StringLike": {
      "s3:key": "*.pdf"
    }
  }
}
```
**用途**：PDF ファイルのみ公開し、他のファイル形式は制限

---

## 18. VPC エンドポイント経由のみアクセス許可

```json
{
  "Principal": "*",
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::private-vpc-bucket/*",
  "Condition": {
    "StringEquals": {
      "aws:SourceVpce": "vpce-1a2b3c4d"
    }
  }
}
```
**用途**：VPC エンドポイント経由でのみアクセス可能に設定（インターネットアクセス不可）

---

## 19. バージョニング有効時の古いバージョン削除を拒否

```json
{
  "Principal": "*",
  "Effect": "Deny",
  "Action": "s3:DeleteObjectVersion",
  "Resource": "arn:aws:s3:::versioned-bucket/*"
}
```
**用途**：バージョニング対応バケットで過去バージョン削除を防止

---

## 20. 複数の Principal を OR 条件で指定

```json
{
  "Principal": {
    "AWS": [
      "arn:aws:iam::123456789012:user/alice",
      "arn:aws:iam::123456789012:user/bob",
      "arn:aws:iam::987654321098:root"
    ]
  },
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::shared-bucket/*"
}
```
**用途**：複数のユーザー/ロール/アカウントに同時にアクセス権を付与

---

## 使用上の注意

- **複数ステートメント**：上記のフラグメントは、ポリシードキュメント内の `Statement` 配列内に複数組み込むことで組み合わせ利用
- **優先度**：Deny ルールは Allow より優先されるため、拒否ルールは慎重に設計
- **最小権限の原則**：必要最小限のアクセス権を設定し、定期的に見直し
- **テスト環境での検証**：本番環境に適用する前に、テスト環境で動作確認を推奨
