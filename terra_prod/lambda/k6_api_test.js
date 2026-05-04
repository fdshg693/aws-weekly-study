import http from 'k6/http';
import exec from 'k6/execution';
import { check, sleep } from 'k6';
import { Counter, Rate } from 'k6/metrics';

// k6 実行時に `-e API_URL=...` のように渡す環境変数を読み込む。
// API_URL は必須で、負荷試験対象の API Gateway / Lambda エンドポイントを指す。
const API_URL = __ENV.API_URL;
// 認証付き API のため x-api-key は必須。
const API_KEY = __ENV.API_KEY;
// Bedrock に渡すプロンプトの雛形。
const PROMPT = __ENV.PROMPT || 'AWS Lambda と Amazon Bedrock の関係を一文で説明してください';
// 各リクエストの後に待機する秒数。0 の場合は待機せず、最大限に負荷をかける。
const SLEEP_SECONDS = Number(__ENV.SLEEP_SECONDS || '0');
// 429 の詳細ログを見たいときだけ有効化する。大量出力を避けるため先頭数件だけ出す。
const LOG_THROTTLED_RESPONSES = __ENV.LOG_THROTTLED_RESPONSES === 'true';
// Makefile から共通で渡せるステージ数とステージ時間。
const DEFAULT_STAGE_COUNT = 3;
const DEFAULT_STAGE_DURATION = '30s';
const DEFAULT_GET_STAGE_TARGETS = [2, 4, 6];
const DEFAULT_POST_STAGE_TARGETS = [2, 4, 6];
// 429 は「API がダウンした失敗」ではなく「スロットリングされた応答」として別管理する。
const THROTTLED_RATE_THRESHOLD = Number(__ENV.THROTTLED_RATE_THRESHOLD || '0.40');
const UNEXPECTED_FAILURE_RATE_THRESHOLD = Number(__ENV.UNEXPECTED_FAILURE_RATE_THRESHOLD || '0.05');

const expectedResponseStatuses = http.expectedStatuses(200, 429);
const throttledResponses = new Rate('http_req_throttled');
const unexpectedResponses = new Rate('http_req_unexpected');
const throttledResponseCount = new Counter('http_req_throttled_count');

let throttledLogCount = 0;
const MAX_THROTTLED_LOGS = 5;

if (!API_URL) {
  throw new Error('API_URL is required. Example: k6 run -e API_URL=https://xxxx.execute-api.ap-northeast-1.amazonaws.com/ k6_api_test.js');
}

if (!API_KEY) {
  throw new Error('API_KEY is required. Example: k6 run -e API_URL=https://xxxx.execute-api.ap-northeast-1.amazonaws.com/ -e API_KEY=xxxx k6_api_test.js');
}

http.setResponseCallback(expectedResponseStatuses);

function parseNonNegativeInteger(value, fallbackValue, envName) {
  if (value === undefined || value === null || value === '') {
    return fallbackValue;
  }

  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`${envName} must be a non-negative integer. Received: ${value}`);
  }

  return parsed;
}

function parsePositiveInteger(value, fallbackValue, envName) {
  const parsed = parseNonNegativeInteger(value, fallbackValue, envName);
  if (parsed <= 0) {
    throw new Error(`${envName} must be greater than 0. Received: ${value}`);
  }

  return parsed;
}

function getStageCount(prefix, fallbackCount) {
  return parsePositiveInteger(
    __ENV[`${prefix}_STAGE_COUNT`] || __ENV.STAGE_COUNT,
    fallbackCount,
    `${prefix}_STAGE_COUNT or STAGE_COUNT`,
  );
}

function getStageDuration(prefix, stageNumber) {
  return __ENV[`${prefix}_STAGE${stageNumber}_DURATION`]
    || __ENV[`${prefix}_STAGE_DURATION`]
    || __ENV.STAGE_DURATION
    || DEFAULT_STAGE_DURATION;
}

function buildStages(prefix, defaultTargets) {
  const stageCount = getStageCount(prefix, DEFAULT_STAGE_COUNT);

  return Array.from({ length: stageCount }, (_, index) => {
    const stageNumber = index + 1;
    const fallbackTarget = defaultTargets[Math.min(index, defaultTargets.length - 1)];

    return {
      target: parseNonNegativeInteger(
        __ENV[`${prefix}_STAGE${stageNumber}_TARGET`],
        fallbackTarget,
        `${prefix}_STAGE${stageNumber}_TARGET`,
      ),
      duration: getStageDuration(prefix, stageNumber),
    };
  });
}

const getStages = buildStages('GET', DEFAULT_GET_STAGE_TARGETS);
const postStages = buildStages('POST', DEFAULT_POST_STAGE_TARGETS);

// k6 の実行オプション。
// scenarios で「どの関数を」「どんなペースで」実行するかを定義し、
// thresholds で「どの程度の失敗率・応答時間まで許容するか」を宣言する。
export const options = {
  scenarios: {
    // GET 系の読み取りリクエスト用シナリオ。
    // post_requests シナリオとは独立しており、k6 実行中は POST と並列で動く。
    // そのため、GET が 50 req/s・POST が 50 req/s に到達する設定なら、合計で最大 100 req/s を狙う構成になる。
    get_requests: {
      // ramping-arrival-rate は「同時実行数」ではなく「単位時間あたりの到着リクエスト数」を制御する executor。
      // 例: target=20, timeUnit='1s' なら 1 秒あたり 20 リクエストを開始しようとする。
      executor: 'ramping-arrival-rate',
      // このシナリオで呼び出す exported function 名。
      exec: 'getScenario',
      // テスト開始直後の到着レート。ここでは 1 秒あたり何件から始めるかを指定。
      startRate: Number(__ENV.GET_START_RATE || '1'),
      // startRate / stages[].target の単位時間。
      // '1s' のため、target=5 は「毎秒 5 リクエスト開始」を意味する。
      timeUnit: '1s',
      // 事前確保する VU (Virtual Users) 数。
      // 到着レートを安定して捌くために先に確保しておく worker 数で、少なすぎると目標レートに届かないことがある。
      preAllocatedVUs: Number(__ENV.GET_PRE_ALLOCATED_VUS || '10'),
      // 必要に応じて自動拡張できる VU の上限。
      // 負荷が高まり preAllocatedVUs だけでは足りない場合、この数まで増える。
      maxVUs: Number(__ENV.GET_MAX_VUS || '100'),
      // 負荷の段階的な変化を定義する。
      // 各 stage は「duration の間に target まで到着レートを増減させる」設定。
      // 例: 5 -> 20 -> 50 req/s と段階的に上げて、スケーリングや耐性を確認する。
      stages: getStages,
      // k6 のメトリクスに付与するタグ。
      // 結果分析時に GET リクエスト由来のメトリクスを絞り込みやすくなる。
      tags: { method: 'GET' },
    },
    // POST 系の書き込みリクエスト用シナリオ。
    // get_requests シナリオと同時に実行されるため、POST 単体の到着レートだけでなく
    // システム全体では GET 側の負荷も合算して評価する必要がある。
    post_requests: {
      executor: 'ramping-arrival-rate',
      exec: 'postScenario',
      startRate: Number(__ENV.POST_START_RATE || '1'),
      timeUnit: '1s',
      preAllocatedVUs: Number(__ENV.POST_PRE_ALLOCATED_VUS || '10'),
      maxVUs: Number(__ENV.POST_MAX_VUS || '100'),
      stages: postStages,
      tags: { method: 'POST' },
    },
  },
  thresholds: {
    // `http_req_failed` は k6 上の「想定外レスポンス / 通信失敗」の率。
    // 429 は response callback で expected 扱いにしているため、ここには含めない。
    http_req_failed: [`rate<${UNEXPECTED_FAILURE_RATE_THRESHOLD}`],
    // スロットリング(429)は専用メトリクスで管理する。
    // 元の `http_req_failed<0.20` が意図していた「429 を含む劣化の監視」を、意味が分かりやすい名前へ分離した。
    http_req_throttled: [`rate<${THROTTLED_RATE_THRESHOLD}`],
    // 200/429 以外の HTTP ステータスや、JSON 以前の異常系を専用メトリクスでも監視する。
    http_req_unexpected: [`rate<${UNEXPECTED_FAILURE_RATE_THRESHOLD}`],
    // HTTP 応答時間。
    // `p(95)<3000` は 95 パーセンタイルが 3 秒未満、つまり大半のリクエストは 3 秒以内で返ることを期待する。
    http_req_duration: ['p(95)<3000'],
    // check() の成功率をシナリオ単位で検証。
    // `checks{scenario:get_requests}` のようにタグ付きメトリクスを絞り込み、
    // GET / POST それぞれで 95% 超のチェック成功率を要求している。
    'checks{scenario:get_requests}': ['rate>0.95'],
    'checks{scenario:post_requests}': ['rate>0.95'],
  },
};

// k6 の JS 実行環境では URLSearchParams が使えないため、
// クエリ文字列は encodeURIComponent を使って手動で組み立てる。
function buildQueryString(params) {
  return Object.entries(params)
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
    .join('&');
}

function buildPayload(index) {
  return JSON.stringify({
    prompt: `${PROMPT} [k6-request:${index}]`,
    source: 'k6',
  });
}

function buildRequestParams(requestType) {
  return {
    headers: {
      'x-api-key': API_KEY,
      'Content-Type': 'application/json',
    },
    tags: { request_type: requestType },
  };
}

// API 応答の基本妥当性を検証する。
function validateResponse(res, expectedMethod) {
  const isThrottled = res.status === 429;
  const isUnexpected = !(res.status === 200 || isThrottled);
  const metricTags = {
    method: expectedMethod,
    scenario: exec.scenario.name,
    status: String(res.status),
  };

  throttledResponses.add(isThrottled, metricTags);
  unexpectedResponses.add(isUnexpected, metricTags);
  if (isThrottled) {
    throttledResponseCount.add(1, metricTags);
  }

  if (LOG_THROTTLED_RESPONSES && isThrottled && throttledLogCount < MAX_THROTTLED_LOGS) {
    throttledLogCount += 1;
    console.warn(
      `[${expectedMethod}] throttled with 429: scenario=${exec.scenario.name} status=${res.status} url=${res.url}`,
    );
  }

  let body;
  try {
    body = JSON.parse(res.body);
  } catch (_) {
    body = null;
  }

  return check(res, {
    [`${expectedMethod}: status is 200 or 429`]: (r) => r.status === 200 || r.status === 429,
    [`${expectedMethod}: body is JSON when 200`]: (r) => r.status === 429 || body !== null,
    [`${expectedMethod}: model_id exists when 200`]: (r) => r.status === 429 || Boolean(body?.model_id),
    [`${expectedMethod}: health or output exists when 200`]: (r) => {
      if (r.status === 429) {
        return true;
      }

      if (expectedMethod === 'GET') {
        return body?.status === 'ok';
      }

      return Boolean(body?.output_text);
    },
  });
}

// GET シナリオ本体。
// ramping-arrival-rate executor により、この関数が設定レートに従って繰り返し呼ばれる。
export function getScenario() {
  const res = http.get(API_URL, buildRequestParams('read'));

  validateResponse(res, 'GET');

  // 少し間を空けたい場合だけ待機。
  // arrival-rate executor では到着レート基準で新規 iteration が開始されるため、
  // sleep を入れると 1 iteration あたりの占有時間が伸び、必要 VU 数に影響する。
  if (SLEEP_SECONDS > 0) {
    sleep(SLEEP_SECONDS);
  }
}

// POST シナリオ本体。
export function postScenario() {
  const requestIndex = `${__VU}-${__ITER}`;
  const res = http.post(API_URL, buildPayload(requestIndex), buildRequestParams('write'));

  validateResponse(res, 'POST');

  if (SLEEP_SECONDS > 0) {
    sleep(SLEEP_SECONDS);
  }
}
