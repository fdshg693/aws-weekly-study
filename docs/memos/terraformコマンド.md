## 使用方法

### 初期化
```bash
terraform init
```

### 開発環境へのデプロイ
```bash
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### 本番環境へのデプロイ
```bash
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

### リソースの削除
```bash
terraform destroy -var-file="dev.tfvars"
```
