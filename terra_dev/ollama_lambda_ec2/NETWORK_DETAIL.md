# NETWORK DETAIL

`network.tf` の先頭コメントに書かれているネットワーク構成を、非同期版の実装に合わせて図と文章で詳しく整理したメモです。

## 登場人物

### 1. Client
- 利用者、検証用の `curl`、あるいは別アプリケーションです。
- 公開されている入口は API Gateway のみです。
- `POST /generate` と `GET /requests/{request_id}` の両方に `x-api-key` ヘッダー付きでアクセスします。

### 2. API Gateway HTTP API
- インターネットから受ける公開 HTTPS エンドポイントです。
- このプロジェクトでは次の 2 ルートを公開します。
  - `POST /generate`
  - `GET /requests/{request_id}`
- リクエストは Lambda Proxy Integration（payload v2.0）で API Lambda に渡されます。

### 3. API Lambda service / API Lambda ENI
- API Lambda 本体は AWS Lambda サービス上で動きます。
- VPC 接続のため、Default VPC の default subnet 群に ENI を持ちます。
- `security_group_ids = [aws_security_group.lambda.id]` で Lambda 用 Security Group が付きます。
- この関数の役割は次のとおりです。
  - `x-api-key` の検証
  - Secrets Manager から共有シークレット取得
  - DynamoDB への `QUEUED` レコード保存
  - SQS FIFO への投入
  - `GET /requests/{request_id}` での状態参照

### 4. SQS FIFO queue + DLQ
- API Lambda がリクエスト本体を積む FIFO キューです。
- `MessageDeduplicationId = request_id` を使って、同一リクエストの重複送信を避けます。
- 再試行上限を超えたメッセージは FIFO の DLQ に送られます。
- ここが「受け付け」と「実処理」を切り離す境界です。

### 5. Worker Lambda service / Worker Lambda ENI
- SQS Event Source Mapping によって起動されるワーカーです。
- この関数も Default VPC の default subnet 群に ENI を持ちます。
- API Lambda と同じ Lambda Security Group を共有します。
- `reserved_concurrent_executions = 1` と `batch_size = 1` により、実処理は常に 1 件ずつです。
- この関数の役割は次のとおりです。
  - DynamoDB 状態を `PROCESSING` に更新
  - EC2 上の Ollama を private IP で呼び出し
  - 成功時は `SUCCEEDED`、失敗時は `FAILED` を保存

### 6. DynamoDB requests table
- リクエスト状態と結果を保持するテーブルです。
- 主な状態は `QUEUED` / `PROCESSING` / `SUCCEEDED` / `FAILED` です。
- 結果 JSON、エラー情報、TTL 用 `expires_at` もここに保存します。

### 7. Secrets Manager Interface VPC Endpoint
- API Lambda が NAT Gateway なしで Secrets Manager を使うための Interface Endpoint です。
- `private_dns_enabled = true` により、通常の Secrets Manager 名で引いても VPC 内 private IP に解決されます。
- Endpoint 側にも専用 Security Group があり、Lambda からの `443/tcp` のみ受けます。

### 8. SQS Interface VPC Endpoint
- API Lambda が NAT Gateway なしで SQS FIFO に `SendMessage` するための Interface Endpoint です。
- こちらも `private_dns_enabled = true` です。
- Endpoint 側の Security Group は Lambda からの `443/tcp` のみ受けます。

### 9. DynamoDB Gateway VPC Endpoint
- API Lambda / Worker Lambda が NAT Gateway なしで DynamoDB にアクセスするための Gateway Endpoint です。
- Interface Endpoint ではなく Route Table にぶら下がる Gateway 型です。
- Lambda 側では DynamoDB Prefix List 向け `443/tcp` の egress を明示しています。

### 10. VPC DNS Resolver
- VPC 内で名前解決を行う内部 DNS です。
- Terraform では `cidrhost(data.aws_vpc.default.cidr_block, 2)` で resolver の IP を計算しています。
- Lambda と EC2 の両方が、private DNS や一般的な名前解決のために `53/tcp` と `53/udp` を使います。

### 11. EC2 Ollama server
- Default VPC の default subnet の 1 つに配置される EC2 インスタンスです。
- Public IP は付きますが、外部から入ってくる通信は Security Group で開放しません。
- Ollama は `11434/tcp` で待ち受けますが、その到達元は Lambda Security Group のみに限定されます。
- インターネット向き outbound は、初期セットアップ・モデル取得・SSM 関連通信のために許可されています。

### 12. Internet / public AWS services
- EC2 から見た外向き通信先です。
- 具体的には以下のような用途を想定しています。
  - パッケージリポジトリへのアクセス
  - Ollama 本体やモデルのダウンロード
  - Session Manager 関連の外向き通信
- ただし、インターネットから EC2 へ直接入る経路は開けません。

## 通信経路

### 経路1: Client → API Gateway
- プロトコル: HTTPS
- ポート: `443`
- 役割: 外部クライアントが API を呼び出す入口です。
- 利用ルート:
  - `POST /generate`
  - `GET /requests/{request_id}`

### 経路2: API Gateway → API Lambda
- 方式: Lambda Proxy Integration
- 役割: HTTP リクエストを API Lambda 実行イベントとして渡します。
- この部分は VPC 内通信ではなく、AWS マネージドサービス間の連携です。

### 経路3: API Lambda → Secrets Manager Interface VPC Endpoint
- プロトコル: HTTPS
- ポート: `443`
- 制御:
  - Lambda 側 egress で Endpoint SG 宛て `443/tcp` を許可
  - Endpoint 側 ingress で Lambda SG からの `443/tcp` を許可
- 役割: 共有 API シークレットを private 経路で取得します。

### 経路4: API Lambda → SQS Interface VPC Endpoint → SQS FIFO
- プロトコル: HTTPS
- ポート: `443`
- 制御:
  - Lambda 側 egress で SQS Endpoint SG 宛て `443/tcp` を許可
  - Endpoint 側 ingress で Lambda SG からの `443/tcp` を許可
- 役割: API Lambda が受け付けた推論リクエストを FIFO キューに投入します。

### 経路5: API Lambda / Worker Lambda → DynamoDB Gateway Endpoint → DynamoDB
- プロトコル: HTTPS
- ポート: `443`
- 制御:
  - Lambda 側 egress で DynamoDB Prefix List 宛て `443/tcp` を許可
  - Route Table には Gateway Endpoint を関連付ける
- 役割:
  - API Lambda: `QUEUED` 登録、状態参照
  - Worker Lambda: `PROCESSING` / `SUCCEEDED` / `FAILED` 更新

### 経路6: API Lambda / Worker Lambda → VPC DNS Resolver
- プロトコル: DNS
- ポート: `53/tcp`, `53/udp`
- 役割: private DNS 名やその他必要な名前を解決します。

### 経路7: SQS FIFO → Worker Lambda
- 方式: SQS Event Source Mapping
- 役割: キューのメッセージを Worker Lambda に届けます。
- この部分は AWS マネージドな連携であり、Worker Lambda が VPC から直接 SQS API をポーリングする構図ではありません。

### 経路8: Worker Lambda → EC2(Ollama)
- プロトコル: HTTP
- ポート: `11434/tcp`
- 制御:
  - Lambda 側 egress で EC2 SG 宛て `11434/tcp` を許可
  - EC2 側 ingress で Lambda SG からの `11434/tcp` を許可
- 役割: Worker Lambda が Ollama API を private IP 宛てに呼び出し、推論を実行させます。

### 経路9: EC2 → VPC DNS Resolver
- プロトコル: DNS
- ポート: `53/tcp`, `53/udp`
- 役割: EC2 がパッケージ取得先や AWS 関連宛先を名前解決するために使います。

### 経路10: EC2 → Internet
- プロトコル: HTTP / HTTPS
- ポート: `80/tcp`, `443/tcp`
- 役割:
  - パッケージのインストール
  - Ollama のセットアップ
  - モデル pull
  - Session Manager 利用時の関連通信

## 明示的に閉じている通信

この構成は「必要な通信だけを個別に開ける」方針です。特に次が重要です。

- インターネット → EC2 の inbound は開けない
  - `22/tcp`（SSH）なし
  - `80/tcp`（HTTP）なし
  - `443/tcp`（HTTPS）なし
  - `11434/tcp`（Ollama API）なし
- Lambda からの outbound も無制限にはせず、以下に限定する
  - EC2 への `11434/tcp`
  - Secrets Manager Endpoint への `443/tcp`
  - SQS Endpoint への `443/tcp`
  - DynamoDB Prefix List への `443/tcp`
  - DNS Resolver への `53/tcp`, `53/udp`
- NAT Gateway は使わない
  - Secrets Manager / SQS は Interface Endpoint に逃がす
  - DynamoDB は Gateway Endpoint に逃がす

## この全体構成で実現していること

このネットワーク構成全体で実現しているのは、**「外部公開は API Gateway だけに限定しつつ、受け付けと実処理を分離し、実際の推論サーバーである EC2 上の Ollama は VPC 内の private 通信でのみ利用する」** という形です。

実現しているポイントを分解すると、次のとおりです。

1. **クライアントの入口を 1 つに集約している**
   - 外部利用者は API Gateway だけを見ればよく、EC2 の存在や private IP を知る必要がありません。

2. **受け付けと実処理を切り離している**
   - API Lambda は速やかに `202 Accepted` を返し、重い処理は SQS FIFO と Worker Lambda に移譲します。

3. **Ollama を直接公開しない**
   - EC2 に Public IP はあっても inbound は閉じているため、Ollama API をインターネットへ露出しません。

4. **NAT Gateway なしでも Lambda が必要な AWS サービスを利用できる**
   - Secrets Manager / SQS は Interface Endpoint、DynamoDB は Gateway Endpoint を使うことで、閉じた経路を維持します。

5. **最小限の通信だけを Security Group と Route で明示している**
   - Lambda と EC2 の関係
   - Lambda と VPC Endpoint の関係
   - Lambda と DynamoDB の関係
   - それぞれの DNS 利用
   - EC2 の必要最小限の外向き通信
   を個別に定義し、学習しやすく追跡しやすい構成にしています。

6. **FIFO 直列処理で Ollama の負荷を安定化している**
   - Worker Lambda の単一同時実行と `batch_size = 1` により、EC2 上の Ollama に一度に大量リクエストが流れ込みません。

## ひとことで言うと

この構成は、**「公開 API はサーバーレスで受け、秘密情報とキュー投入は private endpoint 経由で行い、推論本体だけを private な EC2 上の Ollama に順番待ちで流す」** ネットワーク設計です。