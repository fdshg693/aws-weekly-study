# Ansible実行の簡易ガイド

## クイックスタート

1. **Terraformでインフラをデプロイ**
   ```bash
   terraform apply -var-file="dev.tfvars"
   ```

2. **1〜2分待つ（EC2起動とAnsibleインストール完了を待つ）**

3. **Ansibleでアプリケーションをセットアップ**
   ```bash
   cd ansible
   ./run_playbook.sh dev
   ```

3. **Webブラウザでアクセス**
   ```bash
   # 公開IPを確認
   terraform output instance_public_ip
   
   # ブラウザで http://<PUBLIC_IP> にアクセス
   ```

## run_playbook.shスクリプトの機能

このスクリプトは以下を自動で実行します：

1. Terraformから公開IPを自動取得
2. SSH接続テスト
3. 一時的なインベントリファイルを作成
4. Ansibleプレイブックを実行
5. 実行結果の表示

**重要**: EC2インスタンスはuser_data.shで起動時にAnsibleを自動インストールします。
インスタンス作成直後は1〜2分待ってからAnsibleを実行してください。

## トラブルシューティング

### SSH接続エラー

```bash
# SSH設定を確認
ssh -i ~/.ssh/id_rsa ec2-user@<PUBLIC_IP>

# セキュリティグループを確認（ポート22が開いているか）
terraform show | grep ingress -A 5
```

### Ansibleエラー

```bash
# 詳細ログを出力
cd ansible
ansible-playbook -i inventory.ini playbook.yml -e "environment=dev" -vvv
```

### Ansibleが見つからない

EC2の起動直後はuser_dataがまだ実行中の可能性があります。

対処方法：
```bash
# user_dataのログを確認
ssh -i ~/.ssh/id_rsa ec2-user@<PUBLIC_IP>
sudo cat /var/log/user-data.log

# Ansibleのインストール完了を確認
ansible --version

# 完了していない場合は1〜2分待ってから再試行
```

## カスタマイズ

### Nginxの追加設定

`ansible/playbook.yml`にタスクを追加：

```yaml
- name: Copy custom nginx config
  ansible.builtin.copy:
    src: files/nginx.conf
    dest: /etc/nginx/nginx.conf
  notify: Reload Nginx
```

### 追加パッケージのインストール

```yaml
- name: Install additional packages
  ansible.builtin.dnf:
    name:
      - git
      - docker
    state: present
```
