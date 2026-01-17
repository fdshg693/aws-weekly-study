# Ec2でのCloud-InitとAnsibleの使い方

## Cloud-Initについて

### インストール状況

**ほとんどのAMIには既にインストール済み**です：
- Amazon Linux 2/2023
- Ubuntu
- RHEL
- CentOS
- Debian

確認方法：
```bash
# インストール確認
which cloud-init
cloud-init --version

# もしなければ（稀ですが）
# Amazon Linux/RHEL
sudo yum install -y cloud-init

# Ubuntu/Debian
sudo apt-get install -y cloud-init
```

### AWS側の設定

**特別な設定は不要**です。User Dataに`#cloud-config`で始まるYAMLを書くだけで自動的にCloud-Initが解釈します。

```yaml
#cloud-config
package_update: true
packages:
  - docker
  - git
```

EC2起動時、AWSは自動的に：
1. User DataをインスタンスのメタデータAPIに配置
2. Cloud-InitがメタデータAPIからUser Dataを取得
3. `#cloud-config`を検出してYAMLとして処理

## Ansibleを使う場合

Ansibleは**プル型ではなくプッシュ型**なので、アプローチが異なります。

### パターン1: User Data + Ansible Pull

EC2起動時にAnsibleをインストールし、リモートリポジトリからPlaybookを取得して実行：

```bash
#!/bin/bash
# User Data

# Ansibleインストール
amazon-linux-extras install -y ansible2

# Playbookを取得して実行
ansible-pull -U https://github.com/yourorg/ansible-playbooks.git \
    -i localhost, \
    playbooks/ec2-setup.yml
```

**Playbook例（ec2-setup.yml）:**
```yaml
---
- hosts: localhost
  connection: local
  become: yes
  
  tasks:
    - name: Update all packages
      yum:
        name: '*'
        state: latest
    
    - name: Install Docker
      yum:
        name: docker
        state: present
    
    - name: Start Docker service
      systemd:
        name: docker
        state: started
        enabled: yes
```

### パターン2: Terraform + Ansible（プッシュ型）

より一般的な方法です。Terraformでインスタンス作成後、ローカルからAnsibleを実行：

```hcl
# main.tf
resource "aws_instance" "web" {
  ami           = "ami-xxxxx"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  
  tags = {
    Name = "web-server"
  }

  # 基本的なUser Data（Pythonだけインストール）
  user_data = <<-EOF
              #!/bin/bash
              yum install -y python3
              EOF
}

# Ansibleプロビジョナー
resource "null_resource" "ansible_provisioner" {
  depends_on = [aws_instance.web]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 60  # インスタンス起動待ち
      ansible-playbook -i '${aws_instance.web.public_ip},' \
        --private-key ${var.private_key_path} \
        -u ec2-user \
        playbooks/setup.yml
    EOT
  }

  triggers = {
    instance_id = aws_instance.web.id
  }
}
```

**動的インベントリを使う場合:**

```hcl
# インベントリファイル生成
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    web_ip = aws_instance.web.public_ip
  })
  filename = "${path.module}/inventory/hosts"
}

resource "null_resource" "ansible" {
  depends_on = [local_file.ansible_inventory]
  
  provisioner "local-exec" {
    command = "ansible-playbook -i inventory/hosts playbooks/setup.yml"
  }
}
```

### パターン3: AWS Systems Manager + Ansible

SSMを使えばSSH不要でAnsibleを実行できます：

```hcl
resource "aws_ssm_document" "ansible_playbook" {
  name          = "RunAnsiblePlaybook"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Run Ansible Playbook"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "runAnsible"
      inputs = {
        runCommand = [
          "#!/bin/bash",
          "yum install -y ansible",
          "ansible-pull -U https://github.com/yourorg/playbooks.git playbook.yml"
        ]
      }
    }]
  })
}

resource "aws_ssm_association" "run_ansible" {
  name = aws_ssm_document.ansible_playbook.name

  targets {
    key    = "tag:Environment"
    values = ["production"]
  }
}
```

### パターン4: Packer + Ansible（推奨）

事前にAnsibleでAMIを作成し、それを使ってEC2を起動：

```hcl
# packer.pkr.hcl
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

source "amazon-ebs" "app" {
  ami_name      = "my-app-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  instance_type = "t3.micro"
  region        = "ap-northeast-1"
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["amazon"]
    most_recent = true
  }
  ssh_username = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.app"]

  provisioner "ansible" {
    playbook_file = "playbooks/setup.yml"
    user          = "ec2-user"
  }
}
```

## 比較表

| 方法 | メリット | デメリット | 使い所 |
|------|---------|-----------|--------|
| **User Data + Shell** | シンプル、AWS標準 | 複雑な設定は難しい | 軽い初期設定 |
| **Cloud-Init** | 宣言的、べき等性 | 複雑な処理は苦手 | 標準的な初期設定 |
| **Ansible Pull** | 構成管理可能 | リポジトリ管理必要 | 動的な環境 |
| **Terraform + Ansible Push** | 柔軟、強力 | SSH設定必要 | 本番環境の構築 |
| **Packer + Ansible** | 起動高速、一貫性 | ビルド時間かかる | 本番環境（推奨） |

## 私の推奨構成

```
1. 開発環境: Cloud-Init（シンプルさ重視）
2. ステージング: Terraform + Ansible Push
3. 本番環境: Packer + Ansible でゴールデンイメージ作成
              → Terraformでデプロイ
              → 設定変更のみUser Data/Cloud-Init
```

どのような環境を構築しようとしていますか？用途に応じて最適な方法を提案できます。