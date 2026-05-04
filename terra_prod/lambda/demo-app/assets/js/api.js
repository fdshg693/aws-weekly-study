(function attachApi(globalScope) {
  function normalizeUrl(url) {
    return String(url || '').trim();
  }

  function normalizeApiKey(apiKey) {
    return String(apiKey || '').trim();
  }

  async function parseResponseBody(response) {
    var text = await response.text();
    var contentType = response.headers.get('content-type') || '';

    if (contentType.includes('application/json')) {
      try {
        return {
          rawText: text,
          data: JSON.parse(text),
        };
      } catch (error) {
        return {
          rawText: text,
          data: {
            parseError: 'JSON の解析に失敗しました。',
            rawText: text,
          },
        };
      }
    }

    return {
      rawText: text,
      data: text,
    };
  }

  async function request(options) {
    var requestOptions = options || {};
    var url = normalizeUrl(requestOptions.url);
    var method = String(requestOptions.method || 'GET').toUpperCase();
    var apiKey = normalizeApiKey(requestOptions.apiKey);
    var body = requestOptions.body;

    if (!url) {
      throw new Error('API URL を入力してください。');
    }

    if (!apiKey) {
      throw new Error('API Key を入力してください。');
    }

    var headers = {
      'x-api-key': apiKey,
    };

    var fetchOptions = {
      method: method,
      headers: headers,
    };

    if (body !== undefined) {
      headers['Content-Type'] = 'application/json';
      fetchOptions.body = JSON.stringify(body);
    }

    var startedAt = globalScope.performance.now();
    var response;

    try {
      response = await globalScope.fetch(url, fetchOptions);
    } catch (networkError) {
      networkError.isNetworkError = true;
      throw networkError;
    }

    var parsedBody = await parseResponseBody(response);
    var durationMs = Math.round(globalScope.performance.now() - startedAt);

    return {
      ok: response.ok,
      status: response.status,
      statusText: response.statusText,
      durationMs: durationMs,
      url: response.url,
      headers: Object.fromEntries(response.headers.entries()),
      data: parsedBody.data,
      rawText: parsedBody.rawText,
    };
  }

  function healthCheck(config) {
    return request({
      method: 'GET',
      url: config.apiUrl,
      apiKey: config.apiKey,
    });
  }

  function invokePrompt(config) {
    return request({
      method: 'POST',
      url: config.apiUrl,
      apiKey: config.apiKey,
      body: {
        prompt: config.prompt,
      },
    });
  }

  globalScope.DemoAppApi = {
    request: request,
    healthCheck: healthCheck,
    invokePrompt: invokePrompt,
  };
})(window);
