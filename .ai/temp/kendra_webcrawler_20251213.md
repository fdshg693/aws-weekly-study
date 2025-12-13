# Amazon Kendra Web Crawler (Public Websites) — Docs Excerpts & References (2025-12-13)

## Core Web Crawler behavior & versions

Source: https://docs.aws.amazon.com/kendra/latest/dg/data-source-web-crawler.html

- Kendra Web Crawler crawls and indexes web pages.
- Only supports crawling public-facing sites or internal sites over **HTTPS**; internal sites can be reached via a **public-facing web proxy**.
- Two connector versions:
  - **Web Crawler v1.0** (`WebCrawlerConfiguration` API): web proxy + include/exclude filters.
  - **Web Crawler v2.0** (`TemplateConfiguration` API): adds field mappings, full/incremental sync, more auth types, VPC.
- Important: **Web Crawler v2.0 connector creation is not supported by CloudFormation**.

Source: https://docs.aws.amazon.com/kendra/latest/dg/data-source-v2-web-crawler.html

- v2.0 uses Selenium + Chromium driver; AWS updates these automatically.
- Note: v2.0 does **not** support crawling website lists from **KMS-encrypted S3 buckets**; supports only S3-managed keys (SSE-S3).

## robots.txt

Source: https://docs.aws.amazon.com/kendra/latest/dg/stop-web-crawler.html

- User-agent is `amazon-kendra`.
- Respects standard `Allow` / `Disallow` directives.

## Web crawler configuration limits and fields (API)

Source: https://docs.aws.amazon.com/kendra/latest/dg/API_WebCrawlerConfiguration.html

Key fields and limits:
- `Urls`: up to **100 seed URLs** and up to **3 sitemap URLs**; **HTTPS only**.
- `CrawlDepth`: 0–10.
- `MaxContentSizePerPageInMegaBytes`: 1e-6–50 (default 50MB).
- `MaxLinksPerPage`: 1–1000 (default 100).
- `MaxUrlsPerMinuteCrawlRate`: 1–300 (default 300).
- `UrlInclusionPatterns` / `UrlExclusionPatterns`: arrays of regex strings; if both match, **exclusion wins**.

Source: https://docs.aws.amazon.com/kendra/latest/dg/API_Urls.html

- `Urls` supports either `SeedUrlConfiguration` or `SiteMapsConfiguration`.

Source: https://docs.aws.amazon.com/kendra/latest/dg/API_SeedUrlConfiguration.html

- `SeedUrls`: max 100.
- `WebCrawlerMode`: `HOST_ONLY` (default), `SUBDOMAINS`, `EVERYTHING`.

Source: https://docs.aws.amazon.com/kendra/latest/dg/API_SiteMapsConfiguration.html

- `SiteMaps`: max 3.

CloudFormation reference (v1 fields; useful mapping to Terraform)
- https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-properties-kendra-datasource-webcrawlerconfiguration.html

## IAM roles (index role + web crawler data source role)

Index role needs CloudWatch permissions
- https://docs.aws.amazon.com/kendra/latest/dg/iam-roles.html
- https://docs.aws.amazon.com/kendra/latest/dg/create-index.html

Troubleshooting note about CloudWatch logs
- https://docs.aws.amazon.com/kendra/latest/dg/troubleshooting-data-sources.html

Web Crawler data source role requirements
- https://docs.aws.amazon.com/kendra/latest/dg/iam-roles.html

Excerpt (paraphrased): For Web Crawler, the role needs:
- `secretsmanager:GetSecretValue` (if using Secrets Manager for website/proxy creds)
- `kms:Decrypt` (if the secret uses a customer-managed KMS key)
- `kendra:BatchPutDocument` and `kendra:BatchDeleteDocument` to update the index
- `s3:GetObject` (only if seed URLs/sitemaps list is stored in S3)

Trust policy
- Service principal: `kendra.amazonaws.com` (role assumed by Kendra)

## Regions & quotas

Source: https://docs.aws.amazon.com/general/latest/gr/kendra.html

- Lists supported region endpoints.
- Notes: **GenAI Enterprise Edition indices** are only available in: us-east-1, us-west-2, eu-west-1, ap-southeast-2.
- Example quotas shown include max query text length and max data sources per index (Developer: 5; Enterprise: 50, adjustable).

## Querying an index

Source: https://docs.aws.amazon.com/kendra/latest/dg/index-searching.html

- Use `Retrieve` API for RAG-style passage retrieval.
- Use `Query` API for ranked-document search results.

## Pricing

Source: https://docs.aws.amazon.com/kendra/latest/dg/what-is-kendra.html

- Free trial note (first 30 days / 750 hours for eligible indices).
- Connector usage does not qualify for free usage.
- After trial: charged for provisioned indices even if empty; additional charges for scanning/syncing.
- Pricing link (official): https://aws.amazon.com/kendra/pricing/
