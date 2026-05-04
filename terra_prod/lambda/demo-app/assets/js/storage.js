(function attachStorage(globalScope) {
  var STORAGE_KEY = 'lambda-demo-app-config';

  function safeParse(value) {
    if (!value) {
      return null;
    }

    try {
      return JSON.parse(value);
    } catch (error) {
      console.warn('Failed to parse saved config from localStorage.', error);
      return null;
    }
  }

  function normalizeConfig(config) {
    var source = config && typeof config === 'object' ? config : {};

    return {
      apiUrl: typeof source.apiUrl === 'string' ? source.apiUrl.trim() : '',
      apiKey: typeof source.apiKey === 'string' ? source.apiKey.trim() : '',
      prompt: typeof source.prompt === 'string' ? source.prompt : '',
      rememberSettings: source.rememberSettings !== false,
    };
  }

  function load() {
    var parsed = safeParse(globalScope.localStorage.getItem(STORAGE_KEY));
    return normalizeConfig(parsed);
  }

  function save(config) {
    var normalized = normalizeConfig(config);
    globalScope.localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized));
    return normalized;
  }

  function clear() {
    globalScope.localStorage.removeItem(STORAGE_KEY);
  }

  globalScope.DemoAppStorage = {
    load: load,
    save: save,
    clear: clear,
    normalizeConfig: normalizeConfig,
  };
})(window);
