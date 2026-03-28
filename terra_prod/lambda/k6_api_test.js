import http from 'k6/http';
import { check, sleep } from 'k6';

const API_URL = __ENV.API_URL;
const REQUEST_NAME = __ENV.REQUEST_NAME || 'k6';
const REQUEST_MESSAGE = __ENV.REQUEST_MESSAGE || 'Hello from k6';
const SLEEP_SECONDS = Number(__ENV.SLEEP_SECONDS || '0');

if (!API_URL) {
  throw new Error('API_URL is required. Example: k6 run -e API_URL=https://xxxx.execute-api.ap-northeast-1.amazonaws.com/ k6_api_test.js');
}

export const options = {
  scenarios: {
    get_requests: {
      executor: 'ramping-arrival-rate',
      exec: 'getScenario',
      startRate: Number(__ENV.GET_START_RATE || '1'),
      timeUnit: '1s',
      preAllocatedVUs: Number(__ENV.GET_PRE_ALLOCATED_VUS || '10'),
      maxVUs: Number(__ENV.GET_MAX_VUS || '100'),
      stages: [
        { target: Number(__ENV.GET_STAGE1_TARGET || '5'), duration: __ENV.GET_STAGE1_DURATION || '30s' },
        { target: Number(__ENV.GET_STAGE2_TARGET || '20'), duration: __ENV.GET_STAGE2_DURATION || '30s' },
        { target: Number(__ENV.GET_STAGE3_TARGET || '50'), duration: __ENV.GET_STAGE3_DURATION || '30s' },
      ],
      tags: { method: 'GET' },
    },
    post_requests: {
      executor: 'ramping-arrival-rate',
      exec: 'postScenario',
      startRate: Number(__ENV.POST_START_RATE || '1'),
      timeUnit: '1s',
      preAllocatedVUs: Number(__ENV.POST_PRE_ALLOCATED_VUS || '10'),
      maxVUs: Number(__ENV.POST_MAX_VUS || '100'),
      stages: [
        { target: Number(__ENV.POST_STAGE1_TARGET || '5'), duration: __ENV.POST_STAGE1_DURATION || '30s' },
        { target: Number(__ENV.POST_STAGE2_TARGET || '20'), duration: __ENV.POST_STAGE2_DURATION || '30s' },
        { target: Number(__ENV.POST_STAGE3_TARGET || '50'), duration: __ENV.POST_STAGE3_DURATION || '30s' },
      ],
      tags: { method: 'POST' },
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.20'],
    http_req_duration: ['p(95)<3000'],
    'checks{scenario:get_requests}': ['rate>0.95'],
    'checks{scenario:post_requests}': ['rate>0.95'],
  },
};

function buildQuery(index) {
  const params = new URLSearchParams({
    name: `${REQUEST_NAME}-get-${index}`,
    message: REQUEST_MESSAGE,
  });

  return `${API_URL}?${params.toString()}`;
}

function buildPayload(index) {
  return JSON.stringify({
    name: `${REQUEST_NAME}-post-${index}`,
    message: REQUEST_MESSAGE,
    source: 'k6',
  });
}

function validateResponse(res, expectedMethod) {
  let body;
  try {
    body = JSON.parse(res.body);
  } catch (_) {
    body = null;
  }

  return check(res, {
    [`${expectedMethod}: status is 200 or 429`]: (r) => r.status === 200 || r.status === 429,
    [`${expectedMethod}: body is JSON when 200`]: (r) => r.status === 429 || body !== null,
    [`${expectedMethod}: greeting exists when 200`]: (r) => r.status === 429 || Boolean(body?.greeting),
  });
}

export function getScenario() {
  const requestIndex = `${__VU}-${__ITER}`;
  const res = http.get(buildQuery(requestIndex), {
    tags: { request_type: 'read' },
  });

  validateResponse(res, 'GET');

  if (SLEEP_SECONDS > 0) {
    sleep(SLEEP_SECONDS);
  }
}

export function postScenario() {
  const requestIndex = `${__VU}-${__ITER}`;
  const res = http.post(API_URL, buildPayload(requestIndex), {
    headers: {
      'Content-Type': 'application/json',
    },
    tags: { request_type: 'write' },
  });

  validateResponse(res, 'POST');

  if (SLEEP_SECONDS > 0) {
    sleep(SLEEP_SECONDS);
  }
}
