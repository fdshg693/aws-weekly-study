# CloudFormation テンプレート検証

## 目次
- [テンプレート検証の重要性](#テンプレート検証の重要性)
- [基本的な検証](#基本的な検証)
- [詳細な検証方法](#詳細な検証方法)
- [テンプレートの見積もり](#テンプレートの見積もり)
- [ベストプラクティス](#ベストプラクティス)
- [実践的な例](#実践的な例)

## テンプレート検証の重要性

テンプレート検証により、スタック作成前に構文エラーや論理エラーを発見できます。これにより、時間とコストの節約が可能になります。

### 検証のメリット
- 構文エラーの早期発見
- デプロイ失敗のリスク軽減
- 開発サイクルの高速化
- リソース制限の確認

## 基本的な検証

### validate-template コマンド
```bash
# ローカルテンプレートの検証
aws cloudformation validate-template \
  --template-body file://template.yaml

# S3上のテンプレートの検証
aws cloudformation validate-template \
  --template-url https://s3.amazonaws.com/my-bucket/template.yaml
```

### 検証結果の確認
```bash
# 検証結果をJSON形式で取得
aws cloudformation validate-template \
  --template-body file://template.yaml \
  --output json

# パラメータ情報のみ表示
aws cloudformation validate-template \
  --template-body file://template.yaml \
  --query 'Parameters' \
  --output table

# 必須パラメータの確認
aws cloudformation validate-template \
  --template-body file://template.yaml \
  --query 'Parameters[?NoEcho==`true` || DefaultValue==null]' \
  --output table
```

### 検証エラーの例
```bash
# エラーを含むテンプレートの検証
aws cloudformation validate-template \
  --template-body file://invalid-template.yaml 2>&1

# エラーメッセージの例:
# An error occurred (ValidationError) when calling the ValidateTemplate operation:
# Template format error: YAML not well-formed. (line 15, column 5)
```

## 詳細な検証方法

### cfn-lint による検証
```bash
# cfn-lintのインストール
pip install cfn-lint

# 基本的な検証
cfn-lint template.yaml

# 詳細な出力
cfn-lint template.yaml --format pretty

# 特定のルールを無視
cfn-lint template.yaml --ignore-checks W2001 W1020

# 複数ファイルを一度に検証
cfn-lint templates/*.yaml

# JSON形式で出力（CI/CD統合用）
cfn-lint template.yaml --format json
```

### cfn-lint 設定ファイル
```bash
# .cfnlintrc ファイルを作成
cat > .cfnlintrc << 'EOF'
ignore_checks:
  - W2001  # Parameter not used
  - W1020  # Sub not required

regions:
  - us-east-1
  - ap-northeast-1

ignore_templates:
  - templates/legacy/*.yaml
EOF

# 設定ファイルを使用して検証
cfn-lint template.yaml
```

### リージョン固有の検証
```bash
# 特定リージョンでの検証
cfn-lint template.yaml --regions us-west-2

# 複数リージョンでの検証
cfn-lint template.yaml --regions us-east-1,eu-west-1,ap-northeast-1
```

### カスタムルールの作成
```bash
# カスタムルールディレクトリを作成
mkdir -p .cfnlint/rules

# カスタムルールを作成
cat > .cfnlint/rules/CustomTagRule.py << 'EOF'
from cfnlint.rules import CloudFormationLintRule
from cfnlint.rules import RuleMatch

class CustomTagRule(CloudFormationLintRule):
    """Check if all resources have required tags"""
    id = 'E9001'
    shortdesc = 'Required tags must be present'
    description = 'All resources must have Environment and Owner tags'
    source_url = 'https://example.com/tagging-policy'
    tags = ['resources', 'tags']

    def match(self, cfn):
        matches = []
        resources = cfn.get_resources()
        
        required_tags = ['Environment', 'Owner']
        
        for resource_name, resource in resources.items():
            tags = resource.get('Properties', {}).get('Tags', [])
            tag_keys = [tag.get('Key') for tag in tags]
            
            for required_tag in required_tags:
                if required_tag not in tag_keys:
                    message = f'Resource {resource_name} is missing required tag: {required_tag}'
                    matches.append(RuleMatch(['Resources', resource_name], message))
        
        return matches
EOF

# カスタムルールで検証
cfn-lint template.yaml --append-rules .cfnlint/rules/
```

### TaskCat によるテスト
```bash
# TaskCatのインストール
pip install taskcat

# 設定ファイルを作成
cat > .taskcat.yml << 'EOF'
project:
  name: my-cloudformation-project
  regions:
    - us-east-1
    - ap-northeast-1

tests:
  test-vpc:
    template: templates/vpc.yaml
    parameters:
      EnvironmentName: test
      VpcCIDR: 10.0.0.0/16
  
  test-application:
    template: templates/application.yaml
    parameters:
      InstanceType: t3.micro
EOF

# テストを実行
taskcat test run

# 特定のテストのみ実行
taskcat test run --tests test-vpc

# レポートを生成
taskcat test run --output-directory ./taskcat_outputs
```

## テンプレートの見積もり

### コスト見積もり
```bash
# テンプレートからコスト見積もりを生成
aws cloudformation estimate-template-cost \
  --template-body file://template.yaml \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t3.medium \
    ParameterKey=VolumeSize,ParameterValue=100

# 見積もりURLを取得
COST_URL=$(aws cloudformation estimate-template-cost \
  --template-body file://template.yaml \
  --parameters file://parameters.json \
  --query 'Url' \
  --output text)

echo "Cost estimate: $COST_URL"

# macOSでブラウザを開く
open "$COST_URL"
```

### リソース数の確認
```bash
# YAMLテンプレートのリソース数をカウント
yq eval '.Resources | length' template.yaml

# リソースタイプ別にカウント
yq eval '.Resources | to_entries | map(.value.Type) | group_by(.) | map({type: .[0], count: length})' template.yaml

# JSONテンプレートの場合
jq '.Resources | length' template.json
jq '.Resources | group_by(.Type) | map({type: .[0].Type, count: length})' template.json
```

### テンプレートサイズの確認
```bash
# テンプレートサイズを確認（制限: 51,200 bytes）
du -h template.yaml

# バイト数で確認
wc -c < template.yaml

# 制限チェックスクリプト
#!/bin/bash
TEMPLATE_FILE="$1"
MAX_SIZE=51200

SIZE=$(wc -c < "$TEMPLATE_FILE")

if [ $SIZE -gt $MAX_SIZE ]; then
  echo "❌ Template size ($SIZE bytes) exceeds limit ($MAX_SIZE bytes)"
  echo "Consider using nested stacks or S3 for the template"
  exit 1
else
  echo "✅ Template size OK: $SIZE bytes"
fi
```

## ベストプラクティス

### プリコミットフック
```bash
# .git/hooks/pre-commit を作成
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

echo "Validating CloudFormation templates..."

# 変更されたテンプレートファイルを取得
TEMPLATES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(yaml|yml|json)$' | grep -E '^(templates|cloudformation)/')

if [ -z "$TEMPLATES" ]; then
  echo "No template files to validate"
  exit 0
fi

ERROR=0

for TEMPLATE in $TEMPLATES; do
  echo "Validating: $TEMPLATE"
  
  # AWS CLIで検証
  if ! aws cloudformation validate-template --template-body file://$TEMPLATE &>/dev/null; then
    echo "❌ AWS validation failed: $TEMPLATE"
    ERROR=1
    continue
  fi
  
  # cfn-lintで検証
  if command -v cfn-lint &>/dev/null; then
    if ! cfn-lint $TEMPLATE; then
      echo "❌ cfn-lint failed: $TEMPLATE"
      ERROR=1
      continue
    fi
  fi
  
  echo "✅ Validation passed: $TEMPLATE"
done

if [ $ERROR -eq 1 ]; then
  echo ""
  echo "❌ Template validation failed. Please fix the errors before committing."
  exit 1
fi

echo ""
echo "✅ All templates validated successfully"
exit 0
EOF

chmod +x .git/hooks/pre-commit
```

### CI/CD パイプライン統合
```bash
#!/bin/bash
# validate-templates.sh

set -e

TEMPLATES_DIR="templates"
EXIT_CODE=0

echo "=== CloudFormation Template Validation ==="
echo ""

# すべてのテンプレートファイルを検索
TEMPLATES=$(find $TEMPLATES_DIR -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \))

for TEMPLATE in $TEMPLATES; do
  echo "Validating: $TEMPLATE"
  
  # AWS CLIで検証
  if aws cloudformation validate-template --template-body file://$TEMPLATE &>/dev/null; then
    echo "  ✅ AWS validation: PASSED"
  else
    echo "  ❌ AWS validation: FAILED"
    aws cloudformation validate-template --template-body file://$TEMPLATE 2>&1 | sed 's/^/    /'
    EXIT_CODE=1
  fi
  
  # cfn-lintで検証
  if command -v cfn-lint &>/dev/null; then
    if cfn-lint $TEMPLATE --format parseable; then
      echo "  ✅ cfn-lint: PASSED"
    else
      echo "  ❌ cfn-lint: FAILED"
      EXIT_CODE=1
    fi
  fi
  
  echo ""
done

if [ $EXIT_CODE -eq 0 ]; then
  echo "=== All templates validated successfully ==="
else
  echo "=== Validation failed for one or more templates ==="
fi

exit $EXIT_CODE
```

### GitHub Actions ワークフロー
```yaml
# .github/workflows/validate-cfn.yml
name: Validate CloudFormation Templates

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Install cfn-lint
      run: |
        pip install cfn-lint
        cfn-lint --version
    
    - name: Validate with AWS CLI
      run: |
        for template in templates/*.yaml; do
          echo "Validating $template with AWS CLI"
          aws cloudformation validate-template --template-body file://$template
        done
    
    - name: Validate with cfn-lint
      run: |
        cfn-lint templates/*.yaml
    
    - name: Check template size
      run: |
        for template in templates/*.yaml; do
          size=$(wc -c < $template)
          if [ $size -gt 51200 ]; then
            echo "❌ $template exceeds size limit: $size bytes"
            exit 1
          fi
          echo "✅ $template size OK: $size bytes"
        done
```

## 実践的な例

### 包括的検証スクリプト
```bash
#!/bin/bash
# comprehensive-validate.sh

TEMPLATE_FILE="$1"

if [ -z "$TEMPLATE_FILE" ]; then
  echo "Usage: $0 <template-file>"
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "❌ File not found: $TEMPLATE_FILE"
  exit 1
fi

echo "=== Comprehensive Template Validation ==="
echo "Template: $TEMPLATE_FILE"
echo ""

ERRORS=0

# 1. ファイルサイズチェック
echo "1. Checking file size..."
SIZE=$(wc -c < "$TEMPLATE_FILE")
MAX_SIZE=51200

if [ $SIZE -gt $MAX_SIZE ]; then
  echo "   ❌ Template size ($SIZE bytes) exceeds limit ($MAX_SIZE bytes)"
  ERRORS=$((ERRORS + 1))
else
  echo "   ✅ Size OK: $SIZE bytes"
fi

# 2. YAML/JSON構文チェック
echo ""
echo "2. Checking syntax..."
if [[ "$TEMPLATE_FILE" =~ \.(yaml|yml)$ ]]; then
  if yq eval . "$TEMPLATE_FILE" > /dev/null 2>&1; then
    echo "   ✅ YAML syntax valid"
  else
    echo "   ❌ YAML syntax error"
    ERRORS=$((ERRORS + 1))
  fi
elif [[ "$TEMPLATE_FILE" =~ \.json$ ]]; then
  if jq . "$TEMPLATE_FILE" > /dev/null 2>&1; then
    echo "   ✅ JSON syntax valid"
  else
    echo "   ❌ JSON syntax error"
    ERRORS=$((ERRORS + 1))
  fi
fi

# 3. AWS CLI検証
echo ""
echo "3. AWS CloudFormation validation..."
if aws cloudformation validate-template --template-body file://$TEMPLATE_FILE > /dev/null 2>&1; then
  echo "   ✅ AWS validation passed"
  
  # パラメータ情報を表示
  PARAMS=$(aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --query 'length(Parameters)' \
    --output text)
  echo "   ℹ️  Parameters: $PARAMS"
  
  # Capabilities情報を表示
  CAPS=$(aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --query 'Capabilities' \
    --output text)
  if [ -n "$CAPS" ]; then
    echo "   ℹ️  Required capabilities: $CAPS"
  fi
else
  echo "   ❌ AWS validation failed"
  aws cloudformation validate-template --template-body file://$TEMPLATE_FILE 2>&1 | sed 's/^/      /'
  ERRORS=$((ERRORS + 1))
fi

# 4. cfn-lint検証
echo ""
echo "4. cfn-lint validation..."
if command -v cfn-lint &>/dev/null; then
  if cfn-lint "$TEMPLATE_FILE"; then
    echo "   ✅ cfn-lint passed"
  else
    echo "   ❌ cfn-lint found issues"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "   ⚠️  cfn-lint not installed (pip install cfn-lint)"
fi

# 5. セキュリティチェック
echo ""
echo "5. Security checks..."
# ハードコードされたシークレットをチェック
if grep -iE '(password|secret|key|token).*(=|:).*["\047][a-zA-Z0-9]{8,}["\047]' "$TEMPLATE_FILE" > /dev/null; then
  echo "   ⚠️  Potential hardcoded secrets detected"
  echo "   Consider using Secrets Manager or Parameter Store"
fi

# パブリックアクセスをチェック
if grep -i 'PublicAccess.*true\|0.0.0.0/0' "$TEMPLATE_FILE" > /dev/null; then
  echo "   ⚠️  Public access configuration detected"
fi

# 6. リソース数チェック
echo ""
echo "6. Resource analysis..."
if [[ "$TEMPLATE_FILE" =~ \.(yaml|yml)$ ]]; then
  RESOURCE_COUNT=$(yq eval '.Resources | length' "$TEMPLATE_FILE")
  echo "   ℹ️  Resources: $RESOURCE_COUNT"
  
  if [ $RESOURCE_COUNT -gt 200 ]; then
    echo "   ⚠️  High resource count ($RESOURCE_COUNT). Consider nested stacks."
  fi
elif [[ "$TEMPLATE_FILE" =~ \.json$ ]]; then
  RESOURCE_COUNT=$(jq '.Resources | length' "$TEMPLATE_FILE")
  echo "   ℹ️  Resources: $RESOURCE_COUNT"
fi

# 結果サマリー
echo ""
echo "==================================="
if [ $ERRORS -eq 0 ]; then
  echo "✅ Validation completed successfully"
  exit 0
else
  echo "❌ Validation failed with $ERRORS error(s)"
  exit 1
fi
```

### バッチ検証スクリプト
```bash
#!/bin/bash
# batch-validate.sh - 複数テンプレートを一括検証

TEMPLATES_DIR="${1:-.}"
REPORT_FILE="validation-report.html"

echo "Validating templates in: $TEMPLATES_DIR"

# HTMLレポートヘッダー
cat > $REPORT_FILE << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>CloudFormation Validation Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    .pass { color: green; }
    .fail { color: red; }
    .warn { color: orange; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #4CAF50; color: white; }
  </style>
</head>
<body>
  <h1>CloudFormation Template Validation Report</h1>
  <table>
    <tr>
      <th>Template</th>
      <th>AWS Validation</th>
      <th>cfn-lint</th>
      <th>Size</th>
      <th>Resources</th>
    </tr>
EOF

# テンプレートを検索して検証
find "$TEMPLATES_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) | while read TEMPLATE; do
  echo "Validating: $TEMPLATE"
  
  TEMPLATE_NAME=$(basename "$TEMPLATE")
  
  # AWS検証
  if aws cloudformation validate-template --template-body file://$TEMPLATE &>/dev/null; then
    AWS_STATUS="<span class='pass'>✅ PASS</span>"
  else
    AWS_STATUS="<span class='fail'>❌ FAIL</span>"
  fi
  
  # cfn-lint
  if command -v cfn-lint &>/dev/null; then
    if cfn-lint $TEMPLATE &>/dev/null; then
      LINT_STATUS="<span class='pass'>✅ PASS</span>"
    else
      LINT_STATUS="<span class='fail'>❌ FAIL</span>"
    fi
  else
    LINT_STATUS="<span class='warn'>⚠️ N/A</span>"
  fi
  
  # サイズ
  SIZE=$(wc -c < $TEMPLATE)
  if [ $SIZE -gt 51200 ]; then
    SIZE_STATUS="<span class='fail'>$SIZE bytes</span>"
  else
    SIZE_STATUS="<span class='pass'>$SIZE bytes</span>"
  fi
  
  # リソース数
  RESOURCES=$(yq eval '.Resources | length' $TEMPLATE 2>/dev/null || echo "N/A")
  
  # HTMLに追加
  cat >> $REPORT_FILE << EOF
    <tr>
      <td>$TEMPLATE_NAME</td>
      <td>$AWS_STATUS</td>
      <td>$LINT_STATUS</td>
      <td>$SIZE_STATUS</td>
      <td>$RESOURCES</td>
    </tr>
EOF
done

# HTMLレポートフッター
cat >> $REPORT_FILE << 'EOF'
  </table>
  <p><small>Generated: $(date)</small></p>
</body>
</html>
EOF

echo ""
echo "Validation report generated: $REPORT_FILE"
open $REPORT_FILE  # macOS
```

このドキュメントでは、CloudFormationテンプレートの検証方法を包括的に説明しました。本番環境へのデプロイ前に、必ずこれらの検証手法を活用してください。
