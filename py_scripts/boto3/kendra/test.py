import boto3

kendra = boto3.client('kendra')

# インデックス一覧
indices = kendra.list_indices()

for index in indices.get('IndexConfigurationSummaryItems', []):
    print(f"Index Name: {index['Name']}, Index ID: {index['Id']}")

# 特定インデックスの詳細設定
index_detail = kendra.describe_index(Id='your-index-id')

# データソース一覧
data_sources = kendra.list_data_sources(IndexId='your-index-id')

# データソースの同期履歴
sync_jobs = kendra.list_data_source_sync_jobs(
    Id='data-source-id',
    IndexId='your-index-id'
)

# ドキュメントのステータス確認
doc_status = kendra.batch_get_document_status(
    IndexId='your-index-id',
    DocumentInfoList=[{'DocumentId': 'doc-1'}, {'DocumentId': 'doc-2'}]
)

# クエリ実行（どんなデータがあるか確認）
results = kendra.query(
    IndexId='your-index-id',
    QueryText='*'  # 全件取得的なクエリ
)