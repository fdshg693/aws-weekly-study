`systemd` のユニットファイルは、`systemd` が「何を」「いつ」「どういう条件で」動かすかを定義する設定ファイルです。

ざっくり言うと、Linux における「サービス管理の設計図」です。
たとえば次のようなものを表現できます。

* Web サーバーを起動する
* OS 起動時に自動実行する
* 他のサービスが起動した後に動かす
* 異常終了したら再起動する
* ソケット接続やタイマーをきっかけに起動する

`systemd` はこれらを「ユニット(unit)」という単位で管理し、その定義を書いたものがユニットファイルです。

典型例は `*.service` ファイルです。たとえば:

```ini
[Unit]
Description=My App
After=network.target

[Service]
ExecStart=/usr/local/bin/myapp
Restart=always
User=appuser

[Install]
WantedBy=multi-user.target
```

この例ではこういう意味になります。

`[Unit]`
ユニットの説明や依存関係を書きます。
`After=network.target` は「ネットワーク関連の初期化の後で起動してね」という意味です。

`[Service]`
実際の動作内容を書きます。
`ExecStart` は起動コマンド、`Restart=always` は落ちたら再起動、`User=appuser` はそのユーザーで実行、という指定です。

`[Install]`
`enable` したときに、どの起動ターゲットにぶら下げるかを書きます。
`WantedBy=multi-user.target` は、通常のマルチユーザー環境で起動対象にする、という意味です。

ユニットには `.service` 以外にも種類があります。

* `.service` : 常駐プロセスやサービス
* `.socket` : ソケット待受で起動
* `.timer` : 定期実行
* `.mount` : マウント管理
* `.target` : 複数ユニットを束ねる到達点
* `.path` : ファイルやディレクトリ変化を監視
* `.device` : デバイス関連

保存場所もだいたい決まっています。

* `/etc/systemd/system/`
  管理者が作成・上書きする場所
* `/usr/lib/systemd/system/` または `/lib/systemd/system/`
  パッケージが提供する場所

よく使うコマンドはこれです。

```bash
sudo systemctl start myapp
sudo systemctl stop myapp
sudo systemctl restart myapp
sudo systemctl status myapp
sudo systemctl enable myapp
sudo systemctl disable myapp
sudo systemctl daemon-reload
```

`daemon-reload` は、ユニットファイルを変更したあとに `systemd` に読み直させるためのものです。ここを忘れると「設定を書いたのに効かない」という、わりと間抜けで味わい深い事故が起きます。

要するに、ユニットファイルは:

「Linux 上のサービスやジョブを、`systemd` が管理できる形で宣言する設定ファイル」

です。

次に掘るなら、「`service` ユニットの各セクション詳細」か、「`enable` と `start` の違い」に進むのが実務的です。
