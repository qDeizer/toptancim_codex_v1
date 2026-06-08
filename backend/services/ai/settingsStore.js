const fs = require('fs');
const path = require('path');
const logger = require('../../utils/logger');

const settingsPath = path.join(__dirname, '../../config/ai-settings.local.json');

const defaultSettings = {
    strategy: 'AUTO',
    geminiModel: 'gemini-2.5-flash',
    fallbackToLocal: true,
    chatResetSeconds: 15,
    chatRequestTimeoutMs: 95000,
    providers: [],
    mlService: {
        enabled: true,
        baseUrl: 'http://127.0.0.1:8000',
        timeoutMs: 120000
    },
    localProvider: {
        enabled: true,
        baseUrl: 'http://localhost:20128/v1',
        model: 'gh/gpt-4o-mini',
        timeoutMs: 60000,
        apiToken: '',
        requiresAuth: false
    }
};

function ensureSettingsFile() {
    const directory = path.dirname(settingsPath);
    if (!fs.existsSync(directory)) {
        fs.mkdirSync(directory, { recursive: true });
    }

    if (!fs.existsSync(settingsPath)) {
        fs.writeFileSync(settingsPath, JSON.stringify(defaultSettings, null, 2), 'utf8');
    }
}

function normalizeProvider(provider, index) {
    return {
        id: provider.id || `provider_${index + 1}`,
        label: provider.label || provider.id || `Provider ${index + 1}`,
        type: provider.type || 'GEMINI',
        enabled: provider.enabled !== false,
        apiKey: provider.apiKey || ''
    };
}

function normalizeLocalProvider(localProvider = {}) {
    return {
        enabled: localProvider.enabled !== false,
        baseUrl: localProvider.baseUrl || 'http://localhost:20128/v1',
        model: localProvider.model || 'gh/gpt-4o-mini',
        timeoutMs: Number(localProvider.timeoutMs) > 0
            ? Number(localProvider.timeoutMs)
            : 60000,
        apiToken: localProvider.apiToken || '',
        requiresAuth: localProvider.requiresAuth === true
    };
}

function normalizeMlService(mlService = {}) {
    return {
        enabled: mlService.enabled !== false,
        baseUrl: mlService.baseUrl || 'http://127.0.0.1:8000',
        timeoutMs: Number(mlService.timeoutMs) > 0
            ? Number(mlService.timeoutMs)
            : 120000
    };
}

function normalizeSettings(settings = {}) {
    const providers = Array.isArray(settings.providers)
        ? settings.providers.map(normalizeProvider)
        : [];

    return {
        strategy: settings.strategy || 'AUTO',
        geminiModel: settings.geminiModel || 'gemini-2.5-flash',
        fallbackToLocal: settings.fallbackToLocal !== false,
        chatResetSeconds: Number(settings.chatResetSeconds) > 0
            ? Number(settings.chatResetSeconds)
            : 15,
        chatRequestTimeoutMs: Number(settings.chatRequestTimeoutMs) > 0
            ? Number(settings.chatRequestTimeoutMs)
            : 95000,
        providers,
        mlService: normalizeMlService(settings.mlService),
        localProvider: normalizeLocalProvider(settings.localProvider)
    };
}

function loadSettings() {
    ensureSettingsFile();
    const raw = fs.readFileSync(settingsPath, 'utf8');
    const parsed = JSON.parse(raw);
    const normalized = normalizeSettings(parsed);
    logger.debug('AI settings loaded', {
        strategy: normalized.strategy,
        geminiModel: normalized.geminiModel,
        chatResetSeconds: normalized.chatResetSeconds,
        chatRequestTimeoutMs: normalized.chatRequestTimeoutMs,
        providerCount: normalized.providers.length,
        enabledProviders: normalized.providers.filter((provider) => provider.enabled).map((provider) => provider.id),
        mlServiceEnabled: normalized.mlService.enabled,
        mlServiceBaseUrl: normalized.mlService.baseUrl,
        mlServiceTimeoutMs: normalized.mlService.timeoutMs,
        localEnabled: normalized.localProvider.enabled,
        localBaseUrl: normalized.localProvider.baseUrl,
        localModel: normalized.localProvider.model,
        localTimeoutMs: normalized.localProvider.timeoutMs,
        localRequiresAuth: normalized.localProvider.requiresAuth
    });
    return normalized;
}

function saveSettings(nextSettings) {
    const normalized = normalizeSettings(nextSettings);
    fs.writeFileSync(settingsPath, JSON.stringify(normalized, null, 2), 'utf8');
    logger.info('AI settings saved', {
        strategy: normalized.strategy,
        geminiModel: normalized.geminiModel,
        chatResetSeconds: normalized.chatResetSeconds,
        chatRequestTimeoutMs: normalized.chatRequestTimeoutMs,
        providerCount: normalized.providers.length,
        enabledProviders: normalized.providers.filter((provider) => provider.enabled).map((provider) => provider.id),
        mlServiceEnabled: normalized.mlService.enabled,
        mlServiceBaseUrl: normalized.mlService.baseUrl,
        mlServiceTimeoutMs: normalized.mlService.timeoutMs,
        localEnabled: normalized.localProvider.enabled,
        localBaseUrl: normalized.localProvider.baseUrl,
        localModel: normalized.localProvider.model,
        localTimeoutMs: normalized.localProvider.timeoutMs,
        localRequiresAuth: normalized.localProvider.requiresAuth
    });
    return normalized;
}

module.exports = {
    loadSettings,
    saveSettings
};
