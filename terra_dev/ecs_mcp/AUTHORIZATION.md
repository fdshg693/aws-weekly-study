# MCP サーバーの認証・認可フロー詳細解説

このドキュメントでは、本プロジェクトの **方式 B（サーバーサイド OAuth）** において、Claude Desktop 等の MCP クライアントが **Keycloak** とどのように認証を行うかを説明する。

実装は MCP Authorization / Security Best Practices と、Keycloak を使った実装チュートリアルの考え方に合わせている。

---

## 前提知識: 用語と概念

### OAuth 2.1 の登場人物（ロール）

OAuth は「あるサービスのデータに、別のアプリからアクセスしてもよいか？」をユーザーに確認し、許可証（トークン）を発行する仕組みである。以下の 4 つのロール（役割）が登場する。

| ロール | 本プロジェクトでの実体 | 説明 |
|---|---|---|
| **リソースオーナー（Resource Owner）** | あなた（ユーザー） | 保護されたリソースの所有者。「このアプリにアクセスを許可しますか？」と聞かれて「はい」と答える人 |
| **クライアント（Client）** | Claude Desktop | ユーザーの代わりにリソースへアクセスしたいアプリケーション |
| **認可サーバー（Authorization Server）** | Keycloak | ユーザーの認証（ログイン）を処理し、アクセストークンを発行するサーバー |
| **リソースサーバー（Resource Server）** | この MCP サーバー（ECS 上の MCP Gateway） | 保護されたリソース（MCP ツール）を持ち、アクセストークンを検証してリクエストを受け付けるサーバー |

### パブリッククライアントとコンフィデンシャルクライアント

OAuth のクライアントには 2 種類ある。

- **パブリッククライアント（Public Client）**: デスクトップアプリやブラウザアプリなど、`client_secret` を安全に保管できないアプリ。例: Claude Desktop（方式 B）

パブリッククライアントは `client_secret` を持てないため、代わりに **PKCE** で安全性を確保する。

### PKCE（Proof Key for Code Exchange）

読み方は「ピクシー」。認可コードが途中で傍受されても悪用できないようにする仕組み。

1. クライアントがランダムな文字列 `code_verifier` を生成する
2. その SHA-256 ハッシュ `code_challenge` を認可リクエストに含める
3. 認可コードを受け取った後、トークン交換時に元の `code_verifier` を送る
4. 認可サーバーは `code_verifier` をハッシュして、最初の `code_challenge` と一致するか検証する

→ 認可コードだけ盗んでも、`code_verifier` を知らないとトークンに交換できない。

### Token introspection

本プロジェクトでは、MCP サーバー自身が JWT を細かく自前実装で検証する代わりに、
**Keycloak の token introspection endpoint** に問い合わせてトークンの有効性を確認する。

そのうえでサーバー側でも次を追加チェックする。

- `iss` が想定の realm issuer と一致すること
- `aud` がこの MCP サーバー向けであること
- `scope` が `mcp:tools` など必要最小限を満たすこと

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
Claude Desktop                MCP サーバー (ECS)              Keycloak (認可サーバー)
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
      │                              │     Keycloak Login           │
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
      │              Token introspection + issuer/aud/scope 検証     │
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

MCP Gateway の OAuth ミドルウェアは `Authorization` ヘッダーがないことを検出し、401 を返す:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer realm="mcp", resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource", scope="mcp:tools"
```

このヘッダーは MCP Authorization 仕様に合わせて `resource_metadata` を含めている。

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
  "scopes_supported": ["mcp:tools"],
  "bearer_methods_supported": ["header"]
}
```

> **実装箇所**: `docker/mcp_gateway/app.py`

**なぜこのステップが必要か？**

MCP の世界では、リソースサーバー（MCP サーバー）と認可サーバー（Keycloak 等）が別々のサーバーであることが一般的。クライアントは最初にリソースサーバーに接続するが、認証は認可サーバーで行う必要がある。このメタデータが「認可サーバーはここだよ」という道案内の役割を果たす。

**`authorization_servers` が自分自身の URL を指している理由:**

本プロジェクトでは、MCP サーバー自身が AS metadata を配信しつつ、実際の認可処理は Keycloak に委譲する。クライアントは MCP サーバーの URL からメタデータを取得し、その中に書かれた Keycloak の endpoint にアクセスする。

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
  "issuer": "https://mcp.example.com/keycloak/realms/mcp",
  "authorization_endpoint": "https://mcp.example.com/keycloak/realms/mcp/protocol/openid-connect/auth",
  "token_endpoint": "https://mcp.example.com/keycloak/realms/mcp/protocol/openid-connect/token",
  "registration_endpoint": "https://mcp.example.com/oauth/register",
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "token_endpoint_auth_methods_supported": ["none"],
  "code_challenge_methods_supported": ["S256"],
  "scopes_supported": ["mcp:tools"]
}
```

> **実装箇所**: `docker/mcp_gateway/app.py`

**ポイント:**

- `issuer` は Keycloak realm の URL だが、このメタデータ自体は MCP サーバーが配信している
- `authorization_endpoint` と `token_endpoint` は Keycloak の URL → クライアントはこれらに直接アクセスする
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

> **実装箇所**: `docker/mcp_gateway/app.py`

**本プロジェクトの実装について:**

- `keycloak_enable_dynamic_client_registration = true` の場合は Keycloak 自身の DCR endpoint を metadata に載せる
- `false` の場合は、MCP Gateway の `/oauth/register` が事前登録済み `keycloak_public_client_id` を返す

学習用・社内運用どちらにも寄せやすいように両対応にしている。

### ステップ⑤ 認可リクエスト（ブラウザでログイン画面を開く）

**ユーザーの承認を得るため、ブラウザで認可サーバーのログイン画面を開く。**

Claude Desktop はステップ③で取得した `authorization_endpoint` を使い、PKCE パラメータ付きで認可リクエストを構築し、ブラウザを起動する:

```
https://mcp.example.com/keycloak/realms/mcp/protocol/openid-connect/auth?
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
| `client_id` | ステップ④で取得した値 | Keycloak 上のクライアント識別子 |
| `redirect_uri` | `https://claude.ai/api/mcp/auth_callback` | 認可後のリダイレクト先（Claude Desktop 固定） |
| `scope` | `openid profile email` | 要求するアクセス範囲 |
| `code_challenge` | PKCE で生成したハッシュ | 認可コード傍受対策 |
| `code_challenge_method` | `S256` | SHA-256 ハッシュを使用 |
| `state` | ランダム文字列 | CSRF 対策用 |
| `resource` | MCP サーバーの URL | トークンの対象リソースを明示（RFC 8707） |

ブラウザには Keycloak のログイン画面が表示される。

### ステップ⑥ ユーザー認証と認可コードの発行

**ユーザーがログインし、Keycloak が認可コードをコールバック URL に返す。**

1. ユーザーが Keycloak のログイン画面で認証する
2. Keycloak が認証に成功すると、認可コード（authorization code）を生成
3. Keycloak がブラウザを以下の URL にリダイレクト:

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
Host: mcp.example.com
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=AUTHORIZATION_CODE
&redirect_uri=https://claude.ai/api/mcp/auth_callback
&client_id=xxxxxxxxxxxxxxxxxxxxxxxxxx
&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
&resource=https://mcp.example.com
```

**Keycloak は以下を検証する:**

1. `code` が有効か（未使用・未期限切れ）
2. `client_id` が正しいか
3. `redirect_uri` が登録済みの値と一致するか
4. `code_verifier` を SHA-256 ハッシュして、ステップ⑤の `code_challenge` と一致するか（PKCE 検証）

検証に成功すると、Keycloak はトークンを返す:

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

> **トークン有効期限の設定**: Keycloak realm / client 側の設定に従う。

### ステップ⑧ Bearer トークンによる MCP 通信

**アクセストークンを使って MCP サーバーにリクエストする。**

以降、Claude Desktop はすべてのリクエストに `Authorization` ヘッダーを付与する:

```http
GET /mcp HTTP/1.1
Host: mcp.example.com
Authorization: Bearer eyJraWQiOiJ...
```

MCP Gateway の OAuth ミドルウェアが以下を検証する:

1. **`Authorization` ヘッダーの存在確認**: `Bearer ` プレフィックスがあるか
2. **Keycloak introspection**: introspection endpoint に問い合わせて token が active か確認
3. **issuer の検証**: トークンの `iss` クレームが `OAUTH_ISSUER`（Keycloak realm URL）と一致するか
4. **audience の検証**: `aud` がこの MCP サーバー向けか確認
5. **scope の検証**: `mcp:tools` など必要 scope を満たすか確認

> **実装箇所**: `docker/mcp_gateway/auth.py`, `docker/mcp_gateway/app.py`

検証に成功すれば、リクエストは FastMCP のハンドラに到達し、MCP レスポンスが返る。

---

## MCP 仕様のどのフローを使っているか

本プロジェクトは、MCP 仕様（2025-06-18）の [Authorization Flow Steps](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization#authorization-flow-steps) に基づいている。

この仕様が定めるフローの骨格は以下の通りで、本プロジェクトの実装と対応する:

| MCP 仕様のステップ | 本プロジェクトの実装 |
|---|---|
| MCP request without token → 401 | MCP Gateway ミドルウェアが 401 を返す |
| Protected Resource Metadata の取得 | `/.well-known/oauth-protected-resource` エンドポイント |
| Authorization Server Metadata の取得 | `/.well-known/oauth-authorization-server` エンドポイント |
| Dynamic Client Registration | Keycloak DCR または `/oauth/register` エンドポイント |
| PKCE + Authorization Code Flow | Keycloak Login + public client |
| Bearer トークンによるリクエスト | MCP Gateway が introspection / issuer / audience / scope を検証 |

Claude Desktop はこの仕様に準拠した MCP クライアントとして動作し、上記フローをそのまま実行する。

---

## 補足: 認証不要のパス

以下のパスは認証なしでアクセスできる。いずれも OAuth フローの一部として、またはインフラの正常性確認として、認証前にアクセスされる必要があるためである。

| パス | 用途 |
|---|---|
| `/health` | ALB / ECS のヘルスチェック |
| `/.well-known/*` | OAuth メタデータ配信（ステップ②③） |
| `/oauth/*` | Dynamic Client Registration（事前登録 fallback を含む） |

> **実装箇所**: `docker/mcp_gateway/app.py`, `alb.tf`
