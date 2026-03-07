# MCP サーバーの認証・認可フロー詳細解説

このドキュメントでは、本プロジェクトの **方式 B（サーバーサイド OAuth）** において、Claude Desktop 等の MCP クライアントがどのような手順で認証を行うかを詳しく説明する。

MCP 仕様（2025-06-18）の [Authorization Flow Steps](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization#authorization-flow-steps) に準拠した実装である。

---

## 前提知識: 用語と概念

### OAuth 2.1 の登場人物（ロール）

OAuth は「あるサービスのデータに、別のアプリからアクセスしてもよいか？」をユーザーに確認し、許可証（トークン）を発行する仕組みである。以下の 4 つのロール（役割）が登場する。

| ロール | 本プロジェクトでの実体 | 説明 |
|---|---|---|
| **リソースオーナー（Resource Owner）** | あなた（ユーザー） | 保護されたリソースの所有者。「このアプリにアクセスを許可しますか？」と聞かれて「はい」と答える人 |
| **クライアント（Client）** | Claude Desktop | ユーザーの代わりにリソースへアクセスしたいアプリケーション |
| **認可サーバー（Authorization Server）** | Amazon Cognito | ユーザーの認証（ログイン）を処理し、アクセストークンを発行するサーバー |
| **リソースサーバー（Resource Server）** | この MCP サーバー（ECS 上の server.py） | 保護されたリソース（MCP ツール）を持ち、アクセストークンを検証してリクエストを受け付けるサーバー |

### パブリッククライアントとコンフィデンシャルクライアント

OAuth のクライアントには 2 種類ある。

- **コンフィデンシャルクライアント（Confidential Client）**: サーバーサイドで動作し、`client_secret` を安全に保管できるアプリ。例: ALB の authenticate-oidc（方式 A）
- **パブリッククライアント（Public Client）**: デスクトップアプリやブラウザアプリなど、`client_secret` を安全に保管できないアプリ。例: Claude Desktop（方式 B）

パブリッククライアントは `client_secret` を持てないため、代わりに **PKCE** で安全性を確保する。

### PKCE（Proof Key for Code Exchange）

読み方は「ピクシー」。認可コードが途中で傍受されても悪用できないようにする仕組み。

1. クライアントがランダムな文字列 `code_verifier` を生成する
2. その SHA-256 ハッシュ `code_challenge` を認可リクエストに含める
3. 認可コードを受け取った後、トークン交換時に元の `code_verifier` を送る
4. 認可サーバーは `code_verifier` をハッシュして、最初の `code_challenge` と一致するか検証する

→ 認可コードだけ盗んでも、`code_verifier` を知らないとトークンに交換できない。

### JWT（JSON Web Token）

読み方は「ジョット」。署名付きの JSON データをコンパクトにエンコードしたトークン形式。`ヘッダー.ペイロード.署名` の 3 パートからなる。

- **ヘッダー**: 署名アルゴリズム（RS256 等）と鍵 ID（kid）
- **ペイロード**: ユーザー情報や有効期限などのクレーム（claims）
- **署名**: ヘッダーとペイロードを秘密鍵で署名したもの

リソースサーバーは認可サーバーの公開鍵（JWKS）を使って署名を検証し、トークンが改竄されていないことを確認する。

### JWKS（JSON Web Key Set）

認可サーバーが公開している公開鍵のセット。JWT の署名検証に使う。Cognito の場合は以下の URL で取得できる:

```
https://cognito-idp.{region}.amazonaws.com/{userPoolId}/.well-known/jwks.json
```

### RFC とは

「Request for Comments」の略。インターネットの技術標準を定めた文書群。OAuth 関連では以下が登場する:

| RFC | 内容 | 一言で言うと |
|---|---|---|
| RFC 8414 | OAuth 2.0 Authorization Server Metadata | 認可サーバーの情報を `.well-known` で公開する仕組み |
| RFC 9728 | OAuth 2.0 Protected Resource Metadata | リソースサーバーが「どの認可サーバーを使うか」を公開する仕組み |
| RFC 7591 | OAuth 2.0 Dynamic Client Registration | クライアントが認可サーバーに自動登録する仕組み |
| RFC 8707 | Resource Indicators for OAuth 2.0 | トークンの対象リソースを明示する `resource` パラメータ |

---

## 認証フロー全体像

```text
Claude Desktop                MCP サーバー (ECS)              Cognito (認可サーバー)
      │                              │                              │
      │  ① GET /mcp (トークンなし)    │                              │
      │─────────────────────────────→│                              │
      │  ← 401 Unauthorized          │                              │
      │     WWW-Authenticate: Bearer  │                              │
      │                              │                              │
      │  ② GET /.well-known/         │                              │
      │     oauth-protected-resource  │                              │
      │─────────────────────────────→│                              │
      │  ← リソースメタデータ          │                              │
      │    (authorization_servers)     │                              │
      │                              │                              │
      │  ③ GET /.well-known/         │                              │
      │     oauth-authorization-server│                              │
      │─────────────────────────────→│                              │
      │  ← AS メタデータ              │                              │
      │    (認可/トークン/登録URL)      │                              │
      │                              │                              │
      │  ④ POST /oauth/register      │                              │
      │─────────────────────────────→│                              │
      │  ← client_id                  │                              │
      │                              │                              │
      │  ⑤ ブラウザで認可URLを開く     │                              │
      │──────────────────────────────────────────────────────────→│
      │                              │     Cognito Hosted UI        │
      │                              │     (ログイン画面)             │
      │                              │                              │
      │  ⑥ ユーザーがログイン          │                              │
      │                              │  ← 認可コード付きリダイレクト   │
      │←─────────────────────────────────────────────────────────│
      │     → claude.ai/api/mcp/auth_callback?code=xxx           │
      │                              │                              │
      │  ⑦ POST /oauth2/token        │                              │
      │    (code + code_verifier)     │                              │
      │──────────────────────────────────────────────────────────→│
      │  ← アクセストークン + リフレッシュトークン                     │
      │←─────────────────────────────────────────────────────────│
      │                              │                              │
      │  ⑧ GET /mcp                  │                              │
      │    Authorization: Bearer xxx  │                              │
      │─────────────────────────────→│                              │
      │              JWT 署名検証 (JWKS)                             │
      │  ← MCP レスポンス             │                              │
      │←────────────────────────────│                              │
```

---

## 各ステップの詳細

### ステップ① 初回リクエストと 401 レスポンス

**クライアントが MCP サーバーにトークンなしでアクセスし、認証が必要だと知る。**

Claude Desktop はまず、MCP サーバーのエンドポイントに素のリクエストを送る:

```http
GET /mcp HTTP/1.1
Host: mcp.example.com
```

server.py の OAuth ミドルウェアは `Authorization` ヘッダーがないことを検出し、401 を返す:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer
```

> **実装箇所**: [server.py:248-255](docker/server.py#L248-L255)
>
> MCP 仕様（2025-06-18）では、この `WWW-Authenticate` ヘッダーに `resource_metadata` URL を含めることが MUST とされているが（RFC 9728 Section 5.1）、現在の実装では簡易的に `Bearer` のみを返している。Claude Desktop は 401 を受け取った時点で次のディスカバリーステップに進む。

### ステップ② Protected Resource Metadata の取得

**リソースサーバー（MCP サーバー）が「自分はどの認可サーバーを使うか」を教える。**

RFC 9728 で定められた仕組み。MCP 仕様（2025-06-18）で追加された要件。

```http
GET /.well-known/oauth-protected-resource HTTP/1.1
Host: mcp.example.com
```

レスポンス:

```json
{
  "resource": "https://mcp.example.com/mcp",
  "authorization_servers": ["https://mcp.example.com"],
  "scopes_supported": ["openid", "profile", "email"],
  "bearer_methods_supported": ["header"]
}
```

> **実装箇所**: [server.py:180-196](docker/server.py#L180-L196)

**なぜこのステップが必要か？**

MCP の世界では、リソースサーバー（MCP サーバー）と認可サーバー（Cognito 等）が別々のサーバーであることが一般的。クライアントは最初にリソースサーバーに接続するが、認証は認可サーバーで行う必要がある。このメタデータが「認可サーバーはここだよ」という道案内の役割を果たす。

**`authorization_servers` が自分自身の URL を指している理由:**

本プロジェクトでは、MCP サーバー自身が AS メタデータ（`/.well-known/oauth-authorization-server`）を配信するプロキシ的な役割を担っている。実際の認可処理は Cognito が行うが、クライアントはまず MCP サーバーの URL からメタデータを取得し、その中に書かれた Cognito のエンドポイントへアクセスする。

### ステップ③ Authorization Server Metadata の取得

**認可サーバーの各エンドポイント URL を一括取得する。**

RFC 8414 で定められた仕組み。クライアントはステップ②で得た `authorization_servers` の URL をもとに、AS メタデータを取得する:

```http
GET /.well-known/oauth-authorization-server HTTP/1.1
Host: mcp.example.com
```

レスポンス:

```json
{
  "issuer": "https://cognito-idp.ap-northeast-1.amazonaws.com/ap-northeast-1_XXXXXXX",
  "authorization_endpoint": "https://your-domain.auth.ap-northeast-1.amazoncognito.com/oauth2/authorize",
  "token_endpoint": "https://your-domain.auth.ap-northeast-1.amazoncognito.com/oauth2/token",
  "registration_endpoint": "https://mcp.example.com/oauth/register",
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "token_endpoint_auth_methods_supported": ["none"],
  "code_challenge_methods_supported": ["S256"],
  "scopes_supported": ["openid", "profile", "email"]
}
```

> **実装箇所**: [server.py:154-178](docker/server.py#L154-L178)

**ポイント:**

- `issuer` は Cognito の実際の URL だが、このメタデータ自体は MCP サーバーが配信している
- `authorization_endpoint` と `token_endpoint` は Cognito の URL → クライアントはこれらに直接アクセスする
- `registration_endpoint` は MCP サーバー自身の URL → DCR はこのサーバーが処理する
- `token_endpoint_auth_methods_supported: ["none"]` → パブリッククライアント（client_secret 不要）
- `code_challenge_methods_supported: ["S256"]` → PKCE 必須

### ステップ④ Dynamic Client Registration（DCR）

**クライアントが OAuth の client_id を自動取得する。**

RFC 7591 で定められた仕組み。通常の OAuth では、事前にクライアントを認可サーバーに登録して client_id を取得する必要がある。しかし MCP の世界では、クライアント（Claude Desktop）が接続先の MCP サーバーを事前に知らないことが多い。DCR により、この登録を自動化する。

```http
POST /oauth/register HTTP/1.1
Host: mcp.example.com
Content-Type: application/json

{
  "client_name": "Claude Desktop",
  "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none"
}
```

レスポンス:

```json
{
  "client_id": "xxxxxxxxxxxxxxxxxxxxxxxxxx",
  "client_name": "Claude Desktop",
  "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none"
}
```

> **実装箇所**: [server.py:204-221](docker/server.py#L204-L221)

**本プロジェクトの簡易実装について:**

本来の DCR では、リクエストに応じて新しい client_id を動的に発行する。しかし本プロジェクトでは、Terraform で事前に作成した Cognito のパブリッククライアント（`aws_cognito_user_pool_client.claude_desktop`）の client_id を固定で返す簡易実装としている。これは学習用プロジェクトとしての割り切りである。

> **Cognito クライアントの定義**: [cognito.tf:102-129](cognito.tf#L102-L129)

### ステップ⑤ 認可リクエスト（ブラウザでログイン画面を開く）

**ユーザーの承認を得るため、ブラウザで認可サーバーのログイン画面を開く。**

Claude Desktop はステップ③で取得した `authorization_endpoint` を使い、PKCE パラメータ付きで認可リクエストを構築し、ブラウザを起動する:

```
https://your-domain.auth.ap-northeast-1.amazoncognito.com/oauth2/authorize?
  response_type=code
  &client_id=xxxxxxxxxxxxxxxxxxxxxxxxxx
  &redirect_uri=https://claude.ai/api/mcp/auth_callback
  &scope=openid profile email
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256
  &state=xyz123
  &resource=https://mcp.example.com
```

**各パラメータの意味:**

| パラメータ | 値 | 説明 |
|---|---|---|
| `response_type` | `code` | 認可コードフローを使うことを示す |
| `client_id` | ステップ④で取得した値 | Cognito 上のクライアント識別子 |
| `redirect_uri` | `https://claude.ai/api/mcp/auth_callback` | 認可後のリダイレクト先（Claude Desktop 固定） |
| `scope` | `openid profile email` | 要求するアクセス範囲 |
| `code_challenge` | PKCE で生成したハッシュ | 認可コード傍受対策 |
| `code_challenge_method` | `S256` | SHA-256 ハッシュを使用 |
| `state` | ランダム文字列 | CSRF 対策用 |
| `resource` | MCP サーバーの URL | トークンの対象リソースを明示（RFC 8707） |

ブラウザには Cognito Hosted UI のログイン画面が表示される。

### ステップ⑥ ユーザー認証と認可コードの発行

**ユーザーがログインし、Cognito が認可コードをコールバック URL に返す。**

1. ユーザーが Cognito Hosted UI でメールアドレスとパスワードを入力
2. Cognito が認証に成功すると、認可コード（authorization code）を生成
3. Cognito がブラウザを以下の URL にリダイレクト:

```
https://claude.ai/api/mcp/auth_callback?code=AUTHORIZATION_CODE&state=xyz123
```

4. Claude Desktop がこのコールバックを受け取り、`state` の一致を確認する

**認可コードの特徴:**

- 一度しか使えない（使い捨て）
- 短い有効期限（通常数分）
- これ単体ではリソースにアクセスできない → トークンに交換する必要がある

### ステップ⑦ トークン交換

**認可コードをアクセストークンに交換する。**

Claude Desktop はステップ③で取得した `token_endpoint` に、認可コードと PKCE の `code_verifier` を送る:

```http
POST /oauth2/token HTTP/1.1
Host: your-domain.auth.ap-northeast-1.amazoncognito.com
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=AUTHORIZATION_CODE
&redirect_uri=https://claude.ai/api/mcp/auth_callback
&client_id=xxxxxxxxxxxxxxxxxxxxxxxxxx
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
&resource=https://mcp.example.com
```

**Cognito は以下を検証する:**

1. `code` が有効か（未使用・未期限切れ）
2. `client_id` が正しいか
3. `redirect_uri` が登録済みの値と一致するか
4. `code_verifier` を SHA-256 ハッシュして、ステップ⑤の `code_challenge` と一致するか（PKCE 検証）

検証に成功すると、Cognito はトークンを返す:

```json
{
  "access_token": "eyJraWQiOiJ...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "eyJjdHkiOi...",
  "id_token": "eyJraWQiOiJ..."
}
```

**各トークンの役割:**

| トークン | 用途 | 有効期限（本プロジェクト） |
|---|---|---|
| `access_token` | MCP サーバーへのリクエストに使う | 1 時間 |
| `refresh_token` | access_token の期限切れ後に新しいトークンを取得する | 30 日 |
| `id_token` | ユーザー情報（メール等）を含む。MCP では通常使わない | 1 時間 |

> **トークン有効期限の設定**: [cognito.tf:120-128](cognito.tf#L120-L128)

### ステップ⑧ Bearer トークンによる MCP 通信

**アクセストークンを使って MCP サーバーにリクエストする。**

以降、Claude Desktop はすべてのリクエストに `Authorization` ヘッダーを付与する:

```http
GET /mcp HTTP/1.1
Host: mcp.example.com
Authorization: Bearer eyJraWQiOiJ...
```

server.py の OAuth ミドルウェアが以下を検証する:

1. **`Authorization` ヘッダーの存在確認**: `Bearer ` プレフィックスがあるか
2. **JWT の署名検証**: Cognito の JWKS（公開鍵セット）を取得し、トークンの署名が正当か確認
3. **issuer の検証**: トークンの `iss` クレームが `OAUTH_ISSUER`（Cognito の URL）と一致するか
4. **有効期限の検証**: トークンの `exp` クレームが現在時刻より未来か

> **実装箇所**: [server.py:110-142](docker/server.py#L110-L142)（トークン検証）、[server.py:229-268](docker/server.py#L229-L268)（ミドルウェア）

検証に成功すれば、リクエストは FastMCP のハンドラに到達し、MCP レスポンスが返る。

---

## MCP 仕様のどのフローを使っているか

本プロジェクトは、MCP 仕様（2025-06-18）の [Authorization Flow Steps](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization#authorization-flow-steps) に基づいている。

この仕様が定めるフローの骨格は以下の通りで、本プロジェクトの実装と対応する:

| MCP 仕様のステップ | 本プロジェクトの実装 |
|---|---|
| MCP request without token → 401 | server.py ミドルウェアが 401 を返す |
| Protected Resource Metadata の取得 | `/.well-known/oauth-protected-resource` エンドポイント |
| Authorization Server Metadata の取得 | `/.well-known/oauth-authorization-server` エンドポイント |
| Dynamic Client Registration | `/oauth/register` エンドポイント（簡易実装） |
| PKCE + Authorization Code Flow | Cognito Hosted UI + パブリッククライアント |
| Bearer トークンによるリクエスト | server.py ミドルウェアが JWT を検証 |

Claude Desktop はこの仕様に準拠した MCP クライアントとして動作しており、上記フローをそのまま実行する。**あなたの理解は正しい。**

---

## 補足: 方式 A（ALB OIDC 認証）との違い

方式 A はブラウザ向けの認証で、ALB が OAuth フロー全体を代行する。方式 B との主な違い:

| 比較項目 | 方式 A（ALB OIDC） | 方式 B（サーバーサイド OAuth） |
|---|---|---|
| 認証の主体 | ALB | MCP サーバー（server.py） |
| クライアント種別 | Confidential（ALB が client_secret を保持） | Public（PKCE で保護） |
| 対象ユーザー | ブラウザ | Claude Desktop 等の MCP クライアント |
| セッション管理 | ALB が Cookie で管理 | クライアントが Bearer トークンを管理 |
| メタデータ配信 | 不要（ALB に直接設定） | MCP サーバーが `.well-known` で配信 |
| MCP 仕様準拠 | 非該当（MCP 仕様外の方式） | 準拠 |

---

## 補足: 認証不要のパス

以下のパスは認証なしでアクセスできる。いずれも OAuth フローの一部として、またはインフラの正常性確認として、認証前にアクセスされる必要があるためである。

| パス | 用途 |
|---|---|
| `/health` | ALB / ECS のヘルスチェック |
| `/.well-known/*` | OAuth メタデータ配信（ステップ②③） |
| `/oauth/*` | Dynamic Client Registration（ステップ④） |

> **実装箇所**: [server.py:242](docker/server.py#L242)（ミドルウェアの除外判定）、[alb.tf:100-135](alb.tf#L100-L135)（ALB ルール）
