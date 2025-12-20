aws kendraのseed_urlsを指定してterraformでKendraを作成したが、作られたINDEXのdocument countが0

---

最も可能性が高い原因：Data Source Syncが未実行
TerraformでData Sourceを作成しても、自動的にクロールは開始されません。 Terraformはリソースの「定義」を作成するだけで、実際のSync（クロールジョブ）は別途トリガーする必要があります。

---

```bash
aws kendra list-data-source-sync-jobs \
  --index-id <your-index-id> \
  --id <your-data-source-id>
```
を実行したところ、以下が返ってきたため、Syncジョブがまだ実行されていないことが確認できました。

```json
{
    "History": []
}
```

そこで、以下のコマンドでData Source Syncジョブを手動で開始した。
```bash
aws kendra start-data-source-sync-job \
  --index-id <your-index-id> \
  --id <your-data-source-id>
```
または代わりに置換コマンドを使用してもよい。
直前のコマンド
```bash
^list-data-source-sync-jobs^start-data-source-sync-job
```
３つ前のコマンド
```bash
!-3:s/list-data-source-sync-jobs/start-data-source-sync-job/:p
``` 