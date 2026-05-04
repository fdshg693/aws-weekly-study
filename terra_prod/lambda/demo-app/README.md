# demo-app

`demo-app` は、`terra_prod/lambda` の API Gateway エンドポイントを**ローカルのブラウザから簡単に試すための静的 Web サイト**です。

- 依存パッケージ不要
- ビルド不要
- `GET /` のヘルスチェック対応
- `POST /` の Bedrock 呼び出し対応
- API URL / API Key / Prompt のローカル保存対応
- Homebrew で入れた `nginx` 経由での localhost 配信に対応

## ファイル構成

- `index.html` - 画面本体
- `assets/styles.css` - 画面スタイル
- `assets/js/storage.js` - localStorage 保存処理
- `assets/js/api.js` - API 呼び出し処理
- `assets/js/app.js` - UI 制御と描画
- `nginx/nginx.conf.template` - ローカル `nginx` 起動用のテンプレート設定

## 使い方

### 1. API 情報を取得

`terra_prod/lambda` ディレクトリで以下を確認します。

```bash
terraform output -raw api_invoke_url
make get-api-key ENV=dev
```

必要に応じて `ENV=prod` に変更してください。

### 2. Homebrew の NGINX でローカル配信する

`file://` で `index.html` を直接開くと、ブラウザから見る Origin が `null` になりやすく、CORS やブラウザ制約で扱いづらくなります。

このため、この demo-app は **Homebrew でインストールした `nginx` で `http://localhost:8080` として開く運用を推奨**します。

未インストールなら、先に以下を実行してください。

```bash
brew install nginx
```

`terra_prod/lambda` ディレクトリで以下を実行してください。

```bash
make demo-app-up
```

ブラウザで `http://localhost:8080` を開きます。

もし `8080` が他のプロセスに使われている場合は、たとえば次のように別ポートで起動できます。

```bash
DEMO_APP_PORT=8081 make demo-app-up
```

その場合は `http://localhost:8081` を開いてください。

停止するときは以下です。

```bash
make demo-app-down
```

### 3. Docker を使わずに NGINX を使う場合

このプロジェクトでは Docker は使わず、`make demo-app-up` がプロジェクト専用設定で `nginx` を直接起動します。

- グローバルな NGINX 設定は書き換えません
- PID とログは `demo-app/.nginx/` 配下に保存されます
- 既に起動済みなら reload します
- 別ポートを使う場合は、その Origin が `cors_allow_origins` に含まれていることを確認してください

### 4. 画面から操作

1. `API URL` に `api_invoke_url` を貼り付ける
2. `API Key` に Secrets Manager から取得したキーを貼り付ける
3. 必要なら「このブラウザに設定を保存する」を有効にする
4. `GET / を確認` で疎通確認
5. Prompt を入力して `POST / を実行`

## 補足

- API キーをローカル保存している場合、**キーがローテーションされたら再入力が必要**です。
- このアプリは API Gateway の CORS 設定が有効である前提です。
  この Terraform プロジェクトでは `cors_allow_origins` で localhost 系 Origin を明示許可しています。
- CORS 設定を変更した場合は、`terraform apply` を再実行してください。
- `POST /` は Bedrock を呼び出すため、利用量に応じて料金が発生します。

## おすすめの試し方

まずは `GET /` で接続確認し、その後に短い Prompt で `POST /` を実行すると安全です。派手さより、事故らない導線。大事です。
