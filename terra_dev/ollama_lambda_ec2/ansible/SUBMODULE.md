# ansible サブモジュール

## 概要
このサブモジュールは、`terra_dev/ollama_lambda_ec2` で Terraform が作成した EC2 インスタンスに対して、**Session Manager 経由で Ansible を実行し、Ollama 推論サーバーを導入・起動する**ための構成です。

Terraform が担当するのは AWS リソース作成までで、EC2 内部のアプリケーション設定はこの `ansible/` 配下で管理します。SSH ではなく `amazon.aws.aws_ssm` 接続プラグインを使うため、EC2 の inbound を開けずにセットアップできるのが特徴です。

既定の運用では、Ansible は **ホストに直接インストールせず Docker コンテナ内のランナー** で実行します。これにより、`ansible-core`、`amazon.aws` collection、AWS CLI、Session Manager Plugin のバージョン差分をホスト OS から切り離して管理できます。

### 作成物
- EC2 内に Ollama 実行用のユーザー・グループを作成します。
- Ollama のホームディレクトリとモデル保存ディレクトリを作成します。
- 公式インストールスクリプトを使って `ollama` バイナリを導入します。
- `systemd` ユニットを配置し、`ollama serve` を常駐起動できるようにします。
- デフォルトモデルとして `qwen2.5:0.5b` を pull し、初回リクエスト前の準備を行います。
- 最後に `ollama list` を実行し、モデル取得まで完了したことを簡易確認します。
- Terraform 本体とは「AWS 上の箱を作る役割」と「箱の中身を整える役割」で責務分離されています。

## 構成ファイル
- `../docker/ansible-runner/Dockerfile`
  - Docker 版 Ansible ランナーの定義です。`ansible-core`、`ansible-runner`、AWS CLI、Session Manager Plugin、`amazon.aws` collection をまとめて入れます。
- `ansible.cfg`
  - 動的インベントリ `inventory.aws_ec2.yml` を既定値に設定し、`amazon.aws.aws_ec2` プラグインを有効化します。
- `inventory.aws_ec2.yml`
  - AWS の EC2 情報を動的に取得するインベントリです。`Project=ollama-lambda-ec2` タグと `running` 状態のインスタンスを対象にします。
- `playbook.yml`
  - すべての対象ホストに対して `ollama_server` ロールを適用するエントリーポイントです。
- `requirements.yml`
  - 利用する Ansible Collection として `amazon.aws` を定義します。
- `group_vars/all.yml`
  - 接続方式、リージョン、Python パス、Ollama の既定モデルや待受アドレスなどの共通変数を定義します。
- `roles/ollama_server/defaults/main.yml`
  - ロールのデフォルト値を定義します。モデル名、待受アドレス、リトライ回数などをここで上書きしやすくしています。
- `roles/ollama_server/tasks/main.yml`
  - パッケージ導入、ユーザー作成、Ollama インストール、systemd 設定、モデル pull、動作確認までの実処理を定義します。Amazon Linux 2023 の既定パッケージに合わせ、`curl` ではなく `curl-minimal` を利用します。
- `roles/ollama_server/templates/ollama.service.j2`
  - `OLLAMA_HOST` や `OLLAMA_MODELS` を埋め込んだ `systemd` ユニットファイルのテンプレートです。

## 注意事項
- このサブモジュールは **Terraform apply 後**、EC2 が起動し、Systems Manager の Managed Instance として見えている状態で実行してください。
- 既定の `make ansible` は Docker ランナーを使うため、ホスト側の必須要件は **Docker** と **AWS 認証情報** です。`~/.aws` をコンテナに read-only mount し、必要に応じて `AWS_PROFILE` / 一時クレデンシャル環境変数も引き継ぎます。
- ローカル実行に切り替えたい場合だけ `ANSIBLE_RUNNER=local` を指定し、その場合はホスト側に AWS CLI、Ansible、Session Manager Plugin、`amazon.aws` Collection が必要です。
- 接続は SSH ではなく **Session Manager 経由** です。EC2 のセキュリティグループで SSH を開ける前提ではありません。
- 動的インベントリは `ap-northeast-1` を対象にし、`Project=ollama-lambda-ec2` タグでホストを絞り込みます。`tags.Environment` を keyed group にしているため、`dev` / `prod` の切り替えは `tag_dev` / `tag_prod` のようなグループ制限で行います。
- `amazon.aws.aws_ssm` 接続プラグインはモジュール転送に **S3 バケットが必須** です。`Makefile` の `make ansible` はアカウント単位の一時バケットを自動利用し、既定ではそのまま Docker ランナーに渡します。必要に応じて `ANSIBLE_AWS_SSM_BUCKET` 環境変数で既存バケットへ上書きできます。
- Ollama は `0.0.0.0:11434` で待ち受けますが、想定されるアクセス元は Terraform 側で許可した Lambda からの内部通信です。外部公開用の設定ではありません。
- 初回のモデル pull は時間がかかることがあります。また、EC2 からインターネットへ `ollama` 本体やモデルを取得できることが前提です。