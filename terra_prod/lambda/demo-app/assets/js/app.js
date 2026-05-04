(function bootstrapDemoApp(globalScope) {
  var storage = globalScope.DemoAppStorage;
  var api = globalScope.DemoAppApi;
  var SAMPLE_PROMPT = 'AWS Lambda と Amazon Bedrock の関係を初心者向けに 3 行で説明してください。';
  var state = {
    busy: false,
    latestResponse: null,
  };
  var elements = {};

  globalScope.addEventListener('DOMContentLoaded', init);

  function init() {
    cacheElements();
    bindEvents();
    hydrateForm();
    renderIdleState();
  }

  function cacheElements() {
    elements.settingsForm = document.getElementById('settings-form');
    elements.promptForm = document.getElementById('prompt-form');
    elements.apiUrl = document.getElementById('api-url');
    elements.apiKey = document.getElementById('api-key');
    elements.rememberSettings = document.getElementById('remember-settings');
    elements.promptInput = document.getElementById('prompt-input');
    elements.toggleApiKey = document.getElementById('toggle-api-key');
    elements.saveSettings = document.getElementById('save-settings');
    elements.healthCheck = document.getElementById('health-check');
    elements.clearSettings = document.getElementById('clear-settings');
    elements.loadSample = document.getElementById('load-sample');
    elements.resetPrompt = document.getElementById('reset-prompt');
    elements.copyJson = document.getElementById('copy-json');
    elements.statusBadge = document.getElementById('status-badge');
    elements.httpStatus = document.getElementById('http-status');
    elements.latency = document.getElementById('latency');
    elements.summaryList = document.getElementById('summary-list');
    elements.outputText = document.getElementById('output-text');
    elements.rawJson = document.getElementById('raw-json');
    elements.submitPrompt = document.getElementById('submit-prompt');
  }

  function bindEvents() {
    elements.settingsForm.addEventListener('submit', handleSaveSettings);
    elements.promptForm.addEventListener('submit', handleSubmitPrompt);
    elements.healthCheck.addEventListener('click', handleHealthCheck);
    elements.clearSettings.addEventListener('click', handleClearSettings);
    elements.toggleApiKey.addEventListener('click', toggleApiKeyVisibility);
    elements.loadSample.addEventListener('click', function loadSamplePrompt() {
      elements.promptInput.value = SAMPLE_PROMPT;
      maybePersistSettings();
    });
    elements.resetPrompt.addEventListener('click', function resetPrompt() {
      elements.promptInput.value = '';
      elements.promptInput.focus();
      maybePersistSettings();
    });
    elements.copyJson.addEventListener('click', handleCopyJson);
    elements.apiUrl.addEventListener('blur', maybePersistSettings);
    elements.apiKey.addEventListener('blur', maybePersistSettings);
    elements.promptInput.addEventListener('blur', maybePersistSettings);
    elements.rememberSettings.addEventListener('change', maybePersistSettings);
  }

  function hydrateForm() {
    var savedConfig = storage.load();
    var queryConfig = readQueryConfig();
    var merged = storage.normalizeConfig({
      apiUrl: queryConfig.apiUrl || savedConfig.apiUrl,
      apiKey: savedConfig.apiKey,
      prompt: queryConfig.prompt || savedConfig.prompt || SAMPLE_PROMPT,
      rememberSettings: savedConfig.rememberSettings,
    });

    elements.apiUrl.value = merged.apiUrl;
    elements.apiKey.value = merged.apiKey;
    elements.promptInput.value = merged.prompt;
    elements.rememberSettings.checked = merged.rememberSettings;
  }

  function readQueryConfig() {
    var params = new URLSearchParams(globalScope.location.search);

    return {
      apiUrl: params.get('apiUrl') || '',
      prompt: params.get('prompt') || '',
    };
  }

  function getFormConfig() {
    return storage.normalizeConfig({
      apiUrl: elements.apiUrl.value,
      apiKey: elements.apiKey.value,
      prompt: elements.promptInput.value,
      rememberSettings: elements.rememberSettings.checked,
    });
  }

  function maybePersistSettings() {
    var config = getFormConfig();
    var options = arguments[0] || {};

    if (config.rememberSettings) {
      storage.save(config);
      if (!options.silent) {
        setStatus('設定をローカル保存しました', 'success');
      }
      return;
    }

    storage.clear();
    if (!options.silent) {
      setStatus('ローカル保存は無効です', 'neutral');
    }
  }

  function handleSaveSettings(event) {
    event.preventDefault();

    try {
      validateBaseConfig();
      maybePersistSettings();
    } catch (error) {
      renderErrorState(error);
    }
  }

  async function handleHealthCheck() {
    var config;

    try {
      config = validateBaseConfig();
    } catch (error) {
      renderErrorState(error);
      return;
    }

    await executeRequest('GET / health check を実行中…', function runHealthCheck() {
      return api.healthCheck(config);
    });
  }

  async function handleSubmitPrompt(event) {
    event.preventDefault();

    var config;

    try {
      config = validatePromptConfig();
    } catch (error) {
      renderErrorState(error);
      return;
    }

    await executeRequest('POST / で Bedrock を呼び出し中…', function runPromptInvoke() {
      return api.invokePrompt(config);
    });
  }

  async function executeRequest(message, requestFactory) {
    if (state.busy) {
      return;
    }

    setBusy(true);
    setStatus(message, 'warning');

    try {
      maybePersistSettings({ silent: true });
      var response = await requestFactory();
      state.latestResponse = response;
      renderResponse(response);
    } catch (error) {
      renderErrorState(error);
    } finally {
      setBusy(false);
    }
  }

  function validateBaseConfig() {
    var config = getFormConfig();

    if (!config.apiUrl) {
      throw new Error('API URL を入力してください。');
    }

    if (!isLikelyUrl(config.apiUrl)) {
      throw new Error('API URL の形式が正しくありません。');
    }

    if (!config.apiKey) {
      throw new Error('API Key を入力してください。');
    }

    return config;
  }

  function validatePromptConfig() {
    var config = validateBaseConfig();

    if (!config.prompt.trim()) {
      throw new Error('Prompt を入力してください。');
    }

    return config;
  }

  function isLikelyUrl(value) {
    try {
      var url = new URL(value);
      return url.protocol === 'http:' || url.protocol === 'https:';
    } catch (error) {
      return false;
    }
  }

  function renderIdleState() {
    elements.httpStatus.textContent = '-';
    elements.latency.textContent = '- ms';
    renderSummary([
      ['状態', 'まだ実行していません'],
      ['ヒント', 'まずは GET / を確認すると接続確認が楽です'],
    ]);
    elements.outputText.textContent = 'POST / を実行すると、Bedrock の応答テキストをここに表示します。';
    elements.outputText.classList.add('muted');
    elements.rawJson.textContent = JSON.stringify({ message: 'まだレスポンスがありません' }, null, 2);
    setStatus('待機中', 'neutral');
  }

  function renderResponse(response) {
    var data = response.data;
    var isSuccess = response.ok;
    var statusText = response.status + (response.statusText ? ' ' + response.statusText : '');
    var summaryItems = buildSummaryItems(data, response);

    elements.httpStatus.textContent = statusText;
    elements.latency.textContent = response.durationMs + ' ms';
    renderSummary(summaryItems);

    var outputText = typeof data === 'object' && data !== null ? String(data.output_text || '') : '';
    if (outputText) {
      elements.outputText.textContent = outputText;
      elements.outputText.classList.remove('muted');
    } else {
      elements.outputText.textContent = isSuccess
        ? 'このレスポンスには output_text がありません（GET / の可能性があります）。'
        : 'エラーの詳細は Raw JSON を確認してください。';
      elements.outputText.classList.toggle('muted', true);
    }

    elements.rawJson.textContent = stringifyJson(data);
    setStatus(isSuccess ? 'リクエスト成功' : 'リクエスト失敗', isSuccess ? 'success' : 'error');
  }

  function buildSummaryItems(data, response) {
    if (typeof data !== 'object' || data === null) {
      return [
        ['HTTP status', String(response.status)],
        ['レスポンス', typeof data === 'string' ? data : 'JSON ではないレスポンス'],
      ];
    }

    var items = [
      ['HTTP status', String(response.status)],
      ['environment', fallbackValue(data.environment)],
      ['app_name', fallbackValue(data.app_name)],
      ['model_id', fallbackValue(data.model_id)],
      ['request_id', fallbackValue(data.request_id)],
      ['timestamp', fallbackValue(data.timestamp)],
    ];

    if (data.status) {
      items.unshift(['status', String(data.status)]);
    }

    if (data.retry_count !== undefined) {
      items.push(['retry_count', String(data.retry_count)]);
    }

    if (data.stop_reason) {
      items.push(['stop_reason', String(data.stop_reason)]);
    }

    if (data.bedrock_error_code) {
      items.push(['bedrock_error_code', String(data.bedrock_error_code)]);
    }

    if (data.upstream_status_code) {
      items.push(['upstream_status_code', String(data.upstream_status_code)]);
    }

    return items;
  }

  function fallbackValue(value) {
    if (value === undefined || value === null || value === '') {
      return '-';
    }

    return String(value);
  }

  function renderSummary(items) {
    elements.summaryList.innerHTML = '';

    items.forEach(function appendItem(pair) {
      var wrapper = document.createElement('div');
      var term = document.createElement('dt');
      var detail = document.createElement('dd');

      term.textContent = pair[0];
      detail.textContent = pair[1];
      wrapper.appendChild(term);
      wrapper.appendChild(detail);
      elements.summaryList.appendChild(wrapper);
    });
  }

  function renderErrorState(error) {
    state.latestResponse = null;
    elements.httpStatus.textContent = 'Error';
    elements.latency.textContent = '- ms';
    elements.outputText.textContent = error && error.message ? error.message : 'エラーが発生しました。';
    elements.outputText.classList.remove('muted');

    renderSummary([
      ['状態', 'エラー'],
      ['種別', error && error.isNetworkError ? 'network' : 'application'],
      ['メッセージ', error && error.message ? error.message : '不明なエラー'],
    ]);

    elements.rawJson.textContent = stringifyJson({
      message: error && error.message ? error.message : '不明なエラー',
      networkError: Boolean(error && error.isNetworkError),
    });

    setStatus('エラーが発生しました', 'error');
  }

  function stringifyJson(value) {
    if (typeof value === 'string') {
      return value;
    }

    try {
      return JSON.stringify(value, null, 2);
    } catch (error) {
      return String(value);
    }
  }

  function toggleApiKeyVisibility() {
    var isPassword = elements.apiKey.type === 'password';
    elements.apiKey.type = isPassword ? 'text' : 'password';
    elements.toggleApiKey.textContent = isPassword ? '隠す' : '表示';
  }

  async function handleCopyJson() {
    if (!elements.rawJson.textContent.trim()) {
      return;
    }

    try {
      await navigator.clipboard.writeText(elements.rawJson.textContent);
      setStatus('Raw JSON をコピーしました', 'success');
    } catch (error) {
      setStatus('JSON のコピーに失敗しました', 'error');
    }
  }

  function setBusy(isBusy) {
    state.busy = isBusy;

    [
      elements.saveSettings,
      elements.healthCheck,
      elements.submitPrompt,
      elements.clearSettings,
      elements.toggleApiKey,
      elements.loadSample,
      elements.resetPrompt,
      elements.copyJson,
    ].forEach(function toggleButton(button) {
      if (button) {
        button.disabled = isBusy;
      }
    });

    elements.rememberSettings.disabled = isBusy;
  }

  function setStatus(message, tone) {
    elements.statusBadge.textContent = message;
    elements.statusBadge.className = 'status-badge ' + (tone || 'neutral');
  }

  function handleClearSettings() {
    storage.clear();
    elements.apiUrl.value = '';
    elements.apiKey.value = '';
    elements.rememberSettings.checked = false;
    setStatus('保存済み設定を削除しました', 'success');
  }
})(window);
