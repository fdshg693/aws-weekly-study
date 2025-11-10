# CloudFront Distribution with OAC (Origin Access Control)

# ローカル変数
locals {
  # CachingOptimizedポリシーIDを直接指定（データソースの動的読み込みを回避）
  caching_optimized_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

# CloudFrontのOrigin Access Control (OAC)
# OACはS3がOriginの場合専用の仕組みで、Lambdaなどの場合には使用しません。
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.distribution_name}-oac"
  description                       = "OAC for ${var.distribution_name}"
  # s3 - S3バケットをオリジンとする場合（最も一般的）
  # mediastore・mediapackagev2 ->  AWS Elemental MediaStoreを・AWS Elemental MediaPackage V2をオリジンとする場合
  # lambda -> Lambda関数URLをオリジンとする場合
  origin_access_control_origin_type = "s3"
  # CloudFrontがオリジンへのリクエストに署名を付与する際の動作を制御します。
  # always - すべてのリクエストに署名を付与（推奨）
  # never  - 署名を付与しない
  # no-override - オリジンリクエストポリシーで指定されたヘッダーを上書きしない
  # 通常は**always**を使用します。これにより、CloudFrontからオリジンへのすべてのリクエストがAWS署名v4で署名され、S3側で認証できます。
  signing_behavior                  = "always"
  # 署名に使用するプロトコルのバージョンを指定します。
  # 現時点ではsigv4のみが利用可能です。これはAWSの最新の署名方式で、セキュリティが強化されています。
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
# CloudFrontディストリビューションはCDN（Content Delivery Network）を提供するリソースです。
# 世界中のエッジロケーションにコンテンツをキャッシュし、ユーザーに高速にコンテンツを配信します。
resource "aws_cloudfront_distribution" "s3_distribution" {
  # ディストリビューションの有効化状態を制御します。
  # true - ディストリビューションを有効化し、コンテンツ配信を開始します
  # false - ディストリビューションを無効化します（デプロイされますが、リクエストを受け付けません）
  enabled = var.enabled

  # IPv6のサポートを有効にするかどうかを指定します。
  # true - IPv6アドレスからのアクセスを許可（推奨：より広範なユーザーにリーチできます）
  # false - IPv4のみをサポート
  is_ipv6_enabled = var.enable_ipv6

  # ディストリビューションの説明文です。
  # 管理コンソールやAPIで表示され、ディストリビューションの用途を識別するのに役立ちます。
  comment = var.comment

  # ルートURL（例: https://example.com/）にアクセスした際に返すデフォルトのオブジェクトを指定します。
  # 通常は "index.html" を指定します。これにより、ディレクトリへのアクセス時に自動的にindex.htmlが表示されます。
  default_root_object = var.default_root_object

  # CloudFrontの料金クラスを指定します。これにより使用するエッジロケーションの範囲が決まります。
  # PriceClass_All - すべてのエッジロケーションを使用（最高のパフォーマンス、最高コスト）
  # PriceClass_200 - 北米、ヨーロッパ、アジア、中東、アフリカのエッジロケーションを使用
  # PriceClass_100 - 北米とヨーロッパのエッジロケーションのみを使用（最低コスト）
  price_class = var.price_class

  # カスタムドメイン名（CNAME）のリストです。
  # CloudFrontのデフォルトドメイン（xxx.cloudfront.net）の代わりに使用するカスタムドメインを指定します。
  # 例: ["example.com", "www.example.com"]
  # 使用する場合は、対応するSSL証明書（ACM）とDNS設定（Route53など）が必要です。
  aliases = var.aliases

  # S3オリジン設定
  # オリジンはCloudFrontがコンテンツを取得する元となるソース（この場合はS3バケット）を定義します。
  origin {
    # S3バケットのリージョナルドメイン名を指定します。
    # 形式: bucket-name.s3.region.amazonaws.com
    # 注意: S3ウェブサイトエンドポイント（bucket-name.s3-website-region.amazonaws.com）ではなく、
    # リージョナルエンドポイントを使用することで、OACによるセキュアなアクセスが可能になります。
    domain_name = var.s3_bucket_regional_domain_name

    # このオリジンを識別するための一意のID文字列です。
    # cache_behaviorのtarget_origin_idで参照され、どのオリジンを使用するかを指定します。
    # 複数のオリジンを使用する場合、それぞれ異なるIDを設定します。
    origin_id = var.origin_id

    # Origin Access Control (OAC)のIDを指定します。
    # OACを使用することで、CloudFrontからのみS3バケットへのアクセスを許可し、
    # 直接的なS3バケットへのアクセスをブロックできます。これによりセキュリティが向上します。
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # デフォルトキャッシュビヘイビア
  # キャッシュビヘイビアは、特定のパスパターンに対するCloudFrontの動作を定義します。
  # default_cache_behaviorは、他のキャッシュビヘイビアにマッチしないすべてのリクエストに適用されます。
  default_cache_behavior {
    # CloudFrontが受け付けるHTTPメソッドのリストです。
    # GET, HEAD - 読み取り専用の静的コンテンツ配信の場合
    # GET, HEAD, OPTIONS - CORSを含む読み取り専用の場合
    # GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE - 完全なRESTful APIの場合
    allowed_methods = var.allowed_methods

    # CloudFrontがキャッシュするHTTPメソッドのリストです。
    # 通常は ["GET", "HEAD"] または ["GET", "HEAD", "OPTIONS"] を指定します。
    # POST/PUT/DELETEなどの変更系メソッドはキャッシュしないのが一般的です。
    cached_methods = var.cached_methods

    # このキャッシュビヘイビアが使用するオリジンのIDを指定します。
    # origin ブロックで定義した origin_id と一致させる必要があります。
    target_origin_id = var.origin_id

    # ビューワー（エンドユーザー）とCloudFront間の通信プロトコルを制御します。
    # allow-all - HTTPとHTTPSの両方を許可
    # redirect-to-https - HTTPリクエストを自動的にHTTPSにリダイレクト（推奨）
    # https-only - HTTPSのみを許可、HTTPリクエストは拒否
    # セキュリティのため、通常は redirect-to-https を使用します。
    viewer_protocol_policy = var.viewer_protocol_policy

    # CloudFrontが自動的にファイルを圧縮するかどうかを指定します。
    # true - text/html, text/css, application/javascriptなどの対象ファイルを自動的にgzip圧縮
    # false - 圧縮を行わない
    # 圧縮により転送量が減り、ページ読み込み速度が向上します。
    compress = var.compress

    # キャッシュポリシーのIDを指定します。
    # キャッシュポリシーは、TTL（Time To Live）、キャッシュキー（クエリ文字列、ヘッダー、Cookie）を定義します。
    # カスタムポリシーIDが指定されていない場合は、AWSマネージドポリシー「CachingOptimized」を使用します。
    # CachingOptimizedは、クエリ文字列やヘッダーをキャッシュキーに含めない、シンプルなキャッシュ戦略です。
    cache_policy_id = var.cache_policy_id != "" ? var.cache_policy_id : local.caching_optimized_policy_id

    # オリジンリクエストポリシーのIDを指定します（オプション）。
    # オリジンリクエストポリシーは、CloudFrontからオリジンへのリクエストに含めるヘッダー、
    # クエリ文字列、Cookieを定義します。キャッシュポリシーとは別に設定できます。
    # 例: ユーザーエージェントやリファラーをオリジンに渡したいが、キャッシュキーには含めたくない場合に使用します。
    origin_request_policy_id = var.origin_request_policy_id
  }

  # カスタムエラーレスポンス
  # オリジンからエラーレスポンス（4xx, 5xx）が返された場合の動作をカスタマイズします。
  # 例: 404エラー時にカスタムエラーページを表示したり、エラーをキャッシュする時間を制御できます。
  # dynamic ブロックを使用して、変数で定義された複数のエラーレスポンス設定を動的に生成します。
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      # オリジンから返されるHTTPエラーコードを指定します（例: 403, 404, 500など）。
      error_code = custom_error_response.value.error_code

      # ビューワーに返すHTTPステータスコードを指定します。
      # 例: オリジンの404を200に変換してカスタムエラーページを正常なレスポンスとして返すことができます。
      response_code = custom_error_response.value.response_code

      # エラー発生時にビューワーに返すカスタムページのパスを指定します（例: "/error.html"）。
      # このパスはオリジン（S3バケット）内のオブジェクトを指します。
      response_page_path = custom_error_response.value.response_page_path

      # エラーレスポンスをCloudFrontがキャッシュする最小時間（秒）を指定します。
      # 0 - エラーをキャッシュしない（オリジンの状態をすぐに反映）
      # 300 - 5分間キャッシュ（オリジンへの負荷を軽減）
      # 一時的なエラーの場合は短く、恒久的なエラーの場合は長く設定します。
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # 地理的制限（Geo Restriction）
  # 特定の国や地域からのアクセスを制限または許可する機能です。
  # コンテンツの配信地域を制御したい場合や、ライセンス契約で特定地域への配信が制限されている場合に使用します。
  restrictions {
    geo_restriction {
      # 制限のタイプを指定します。
      # none - 地理的制限を適用しない（すべての国からのアクセスを許可）
      # whitelist - 指定した国のみアクセスを許可（それ以外は拒否）
      # blacklist - 指定した国からのアクセスを拒否（それ以外は許可）
      restriction_type = var.geo_restriction_type

      # 制限または許可する国のISO 3166-1 alpha-2国コードのリストです（例: ["US", "JP", "GB"]）。
      # restriction_type が "none" の場合は、このリストは無視されます。
      # whitelist の場合: ここに記載された国のみがアクセス可能
      # blacklist の場合: ここに記載された国はアクセス不可
      locations = var.geo_restriction_locations
    }
  }

  # SSL/TLS証明書設定
  # ビューワー（エンドユーザー）とCloudFront間のHTTPS通信に使用する証明書を設定します。
  viewer_certificate {
    # CloudFrontのデフォルト証明書（*.cloudfront.net）を使用するかどうかを指定します。
    # true - デフォルト証明書を使用（カスタムドメインを使用しない場合）
    # false - カスタムドメイン用のACM証明書を使用
    # カスタムドメイン（aliases）を使用する場合は、必ずfalseにしてacm_certificate_arnを指定します。
    cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : false

    # AWS Certificate Manager（ACM）で発行された証明書のARNを指定します。
    # カスタムドメイン（例: www.example.com）でHTTPSを使用する場合に必要です。
    # 注意: CloudFront用の証明書は必ず us-east-1 リージョンで作成する必要があります。
    acm_certificate_arn = var.acm_certificate_arn

    # SSL証明書の配信方法を指定します。
    # sni-only - Server Name Indication (SNI)を使用（推奨、追加料金なし）
    # vip - 専用IPアドレスを使用（非推奨、月額600ドル以上のコスト）
    # SNIは、ほとんどの最新ブラウザでサポートされており、コスト効率が良いためsni-onlyを使用します。
    ssl_support_method = var.acm_certificate_arn != "" ? "sni-only" : null

    # ビューワーとの通信で許可する最小TLSプロトコルバージョンを指定します。
    # TLSv1.2_2021 - TLS 1.2以上を要求（推奨、セキュリティと互換性のバランスが良い）
    # TLSv1.2_2019 - TLS 1.2以上（古い設定）
    # TLSv1.2_2018 - TLS 1.2以上（さらに古い設定）
    # TLSv1 - TLS 1.0以上（非推奨、セキュリティリスクあり）
    # セキュリティのため、少なくともTLSv1.2_2021以上を使用することを推奨します。
    minimum_protocol_version = var.minimum_protocol_version
  }

  # ロギング設定（オプション）
  # CloudFrontへのすべてのリクエストを記録し、指定したS3バケットにログファイルを保存します。
  # アクセス解析、セキュリティ監査、トラブルシューティングに使用できます。
  # dynamic ブロックを使用して、ロギングバケットが指定されている場合のみこの設定を有効にします。
  dynamic "logging_config" {
    for_each = var.logging_bucket != "" ? [1] : []
    content {
      # ログファイルを保存するS3バケットのドメイン名を指定します。
      # 形式: bucket-name.s3.amazonaws.com
      # 注意: ログ用のバケットは、CloudFrontディストリビューションとは別に作成し、
      # 適切なバケットポリシーでCloudFrontからの書き込みを許可する必要があります。
      bucket = var.logging_bucket

      # ログファイルの保存先プレフィックス（ディレクトリパス）を指定します。
      # 例: "cloudfront-logs/" とすると、バケット内の cloudfront-logs/ ディレクトリ配下にログが保存されます。
      # 複数のディストリビューションのログを同じバケットに保存する場合、プレフィックスで区別できます。
      prefix = var.logging_prefix

      # ログにCookie情報を含めるかどうかを指定します。
      # true - Cookieを含める（詳細な分析が可能だが、ログファイルサイズが大きくなる）
      # false - Cookieを含めない（推奨、プライバシー保護とストレージコスト削減）
      # 個人情報を含む可能性があるため、通常はfalseを推奨します。
      include_cookies = var.logging_include_cookies
    }
  }

  # タグ設定
  # AWSリソースに付与するメタデータタグです。
  # コスト配分、リソース管理、自動化などに使用できます。
  # merge関数を使用して、変数で定義されたタグとNameタグを結合します。
  tags = merge(
    var.tags,
    {
      Name = var.distribution_name
    }
  )
}

# データソースは使用しないが、参照用にコメントアウト
# デフォルトのマネージドキャッシュポリシー（CachingOptimized）
# AWSが提供する事前定義されたキャッシュポリシーを参照するデータソースです。
# CachingOptimizedは以下の特徴を持つ汎用的なキャッシュポリシーです：
# - クエリ文字列、ヘッダー、Cookieをキャッシュキーに含めない（シンプルなキャッシュ）
# - TTL: 最小0秒、デフォルト86400秒（1日）、最大31536000秒（1年）
# - gzip/brotli圧縮をサポート
# 静的コンテンツ（HTML、CSS、JS、画像など）の配信に適しています。
# data "aws_cloudfront_cache_policy" "caching_optimized" {
#   name = "Managed-CachingOptimized"
# }
