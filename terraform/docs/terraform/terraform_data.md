Terraform 1.4で導入された`terraform_data`について詳しく説明します。

## terraform_dataとは

`terraform_data`は`null_resource`の後継として設計された、より柔軟で直感的なリソースです。外部リソースを作成せずに、Terraformの機能（トリガー、依存関係、プロビジョナー）を活用できます。

## null_resourceとの違い

| 項目 | null_resource | terraform_data |
|------|---------------|----------------|
| プロバイダー | hashicorp/null が必要 | Terraform本体に組み込み |
| 柔軟性 | triggersのみ | input/outputの概念あり |
| 推奨度 | 非推奨ではないが古い | 推奨 |

## 基本的な構文

```hcl
resource "terraform_data" "example" {
  # 入力値（任意のデータを保存可能）
  input = "some value"
  
  # トリガー（変更検知用）
  triggers_replace = {
    timestamp = timestamp()
  }
}
```

## 主な使用パターン

### 1. 依存関係の制御

```hcl
resource "aws_instance" "app" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
}

resource "terraform_data" "deployment_gate" {
  # インスタンスが作成されるまで待機
  depends_on = [aws_instance.app]
}

resource "aws_route53_record" "app" {
  # deployment_gateの後に実行
  depends_on = [terraform_data.deployment_gate]
  
  zone_id = "Z1234567890"
  name    = "app.example.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.app.public_ip]
}
```

### 2. 値の変更検知とトリガー

```hcl
resource "terraform_data" "config_version" {
  input = filemd5("config.json")
  
  triggers_replace = {
    config_hash = filemd5("config.json")
  }
  
  provisioner "local-exec" {
    command = "echo '設定ファイルが更新されました'"
  }
}
```

### 3. データの受け渡し

```hcl
resource "terraform_data" "build_info" {
  input = {
    version    = "1.2.3"
    build_time = timestamp()
    git_commit = var.git_commit_hash
  }
}

# 他のリソースで参照
resource "aws_ssm_parameter" "build_version" {
  name  = "/app/build/version"
  type  = "String"
  value = terraform_data.build_info.output.version
}

output "build_info" {
  value = terraform_data.build_info.output
}
```

### 4. 複雑な依存関係の管理

```hcl
# データベース初期化
resource "terraform_data" "db_init" {
  depends_on = [
    aws_db_instance.main,
    aws_security_group.db
  ]
  
  provisioner "local-exec" {
    command = "python scripts/init_db.py"
    environment = {
      DB_HOST = aws_db_instance.main.endpoint
    }
  }
}

# アプリケーションデプロイ（DB初期化後）
resource "terraform_data" "app_deploy" {
  depends_on = [terraform_data.db_init]
  
  triggers_replace = {
    app_version = var.app_version
  }
  
  provisioner "local-exec" {
    command = "kubectl apply -f k8s/"
  }
}
```

### 5. 条件付き実行

```hcl
resource "terraform_data" "conditional_task" {
  count = var.environment == "production" ? 1 : 0
  
  input = {
    environment = var.environment
    task_name   = "production_setup"
  }
  
  provisioner "local-exec" {
    command = "bash scripts/production_setup.sh"
  }
}
```

### 6. 複数の値の監視

```hcl
resource "terraform_data" "multi_trigger" {
  triggers_replace = {
    ami_id          = data.aws_ami.latest.id
    instance_type   = var.instance_type
    security_groups = join(",", var.security_group_ids)
  }
  
  # いずれかの値が変更されたら再実行
  provisioner "local-exec" {
    command = "echo 'インフラ設定が変更されました'"
  }
}
```

## 実践的なAzure例

```hcl
# Azure VM作成後のカスタムスクリプト実行
resource "azurerm_linux_virtual_machine" "game_server" {
  name                = "game-server-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_NC6s_v3"  # GPU VM
  
  # ... その他の設定
}

resource "terraform_data" "game_server_setup" {
  depends_on = [azurerm_linux_virtual_machine.game_server]
  
  triggers_replace = {
    vm_id           = azurerm_linux_virtual_machine.game_server.id
    setup_script_md5 = filemd5("scripts/setup_unity_server.sh")
  }
  
  input = {
    vm_public_ip = azurerm_linux_virtual_machine.game_server.public_ip_address
    vm_name      = azurerm_linux_virtual_machine.game_server.name
  }
  
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = azurerm_linux_virtual_machine.game_server.public_ip_address
      user        = "adminuser"
      private_key = file("~/.ssh/id_rsa")
    }
    
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nvidia-driver-525",
      "curl -O https://unity3d.com/get-unity/download",
      "bash setup_unity_server.sh"
    ]
  }
}

output "server_info" {
  value = terraform_data.game_server_setup.output
}
```

## ベストプラクティス

1. **null_resourceより優先して使用** - 新規プロジェクトでは`terraform_data`を選択
2. **inputを活用** - 後で参照したいデータは`input`に格納
3. **triggers_replaceを適切に設定** - 不必要な再実行を避ける
4. **provisioner は最終手段** - 可能な限りネイティブリソースを使用

何か具体的な実装例が必要でしたら、お知らせください！