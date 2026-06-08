const AIInterface = require('./AIInterface');
const GeminiProvider = require('./GeminiProvider');
const LocalLLMProvider = require('./LocalLLMProvider');
const { loadSettings, saveSettings } = require('./settingsStore');
const logger = require('../../utils/logger');
const { createTraceStep, sanitizeTextPreview } = require('./traceUtils');

function buildProviderEntries(settings) {
    const entries = [];

    if (settings.strategy !== 'LOCAL_ONLY') {
        for (const provider of settings.providers) {
            if (!provider.enabled || !provider.apiKey) {
                continue;
            }

            entries.push({
                id: provider.id,
                label: provider.label,
                type: 'GEMINI',
                instance: new GeminiProvider({
                    apiKey: provider.apiKey,
                    modelName: settings.geminiModel,
                    label: provider.label
                })
            });
        }
    }

    const canUseLocal =
        settings.localProvider &&
        settings.localProvider.enabled &&
        (
            settings.strategy === 'LOCAL_ONLY' ||
            (settings.strategy === 'AUTO' && settings.fallbackToLocal)
        );

    if (canUseLocal) {
        entries.push({
            id: 'local_lm_studio',
            label: 'LM Studio',
            type: 'LOCAL',
            instance: new LocalLLMProvider({
                baseUrl: settings.localProvider.baseUrl,
                modelName: settings.localProvider.model,
                timeoutMs: settings.localProvider.timeoutMs,
                apiToken: settings.localProvider.apiToken,
                requiresAuth: settings.localProvider.requiresAuth
            })
        });
    }

    logger.info('AI provider entries built', {
        strategy: settings.strategy,
        fallbackToLocal: settings.fallbackToLocal,
        order: entries.map((entry) => ({
            id: entry.id,
            label: entry.label,
            type: entry.type
        }))
    });

    return entries;
}

function classifyProviderError(provider, message) {
    const normalized = (message || '').toLowerCase();

    if (normalized.includes('api key expired') || normalized.includes('api_key_invalid')) {
        return `${provider.label}: API anahtari suresi dolmus veya gecersiz`;
    }

    if (normalized.includes('429') || normalized.includes('quota') || normalized.includes('rate limit')) {
        return `${provider.label}: kota dolu`;
    }

    if (normalized.includes('api key') || normalized.includes('401') || normalized.includes('403') || normalized.includes('unauthorized')) {
        return `${provider.label}: kimlik dogrulama hatasi`;
    }

    if (normalized.includes('404') || normalized.includes('not found')) {
        return `${provider.label}: model veya endpoint bulunamadi`;
    }

    if (normalized.includes('timeout') || normalized.includes('zaman asimi')) {
        return `${provider.label}: yanit zaman asimina ugradi`;
    }

    if (normalized.includes('fetch failed') || normalized.includes('econnrefused') || normalized.includes('baglanilamadi')) {
        return provider.type === 'LOCAL'
            ? `${provider.label}: yerel sunucuya baglanilamadi`
            : `${provider.label}: baglanti kurulamadi`;
    }

    return `${provider.label}: istek basarisiz oldu`;
}

function shouldShortCircuitSimilarProviders(provider, message) {
    const normalized = (message || '').toLowerCase();

    if (provider.type !== 'GEMINI') {
        return false;
    }

    return normalized.includes('503') ||
        normalized.includes('service unavailable') ||
        normalized.includes('high demand');
}

class ProviderChain extends AIInterface {
    constructor(settings) {
        super();
        this.settings = settings;
        this.providers = buildProviderEntries(settings);
    }

    async chat(messages, context) {
        if (this.providers.length === 0) {
            throw new Error('Kullanilabilir AI provider bulunamadi. Ayarlar ekranindan en az bir provider etkinlestirin.');
        }

        logger.info('AI provider chain started', {
            strategy: this.settings.strategy,
            messageCount: messages.length,
            contextMode: context.mode,
            targetUserId: context.target_user_id || null,
            providerCount: this.providers.length
        });

        const errors = [];
        const trace = [];

        for (let index = 0; index < this.providers.length; index += 1) {
            const provider = this.providers[index];
            try {
                logger.info('AI provider attempt started', {
                    provider: provider.label,
                    type: provider.type,
                    contextMode: context.mode,
                    targetUserId: context.target_user_id || null
                });
                const providerResult = await provider.instance.chat(messages, context);
                trace.push(createTraceStep({
                    stage: 'provider_attempt',
                    title: `${provider.label} kullanildi`,
                    summary: `${provider.type} saglayicisi yanit uretti.`,
                    details: sanitizeTextPreview(providerResult?.text || ''),
                    meta: {
                        providerId: provider.id,
                        providerLabel: provider.label,
                        providerType: provider.type
                    }
                }));

                return {
                    text: providerResult?.text || '',
                    trace: [...trace, ...(providerResult?.trace || [])],
                    meta: {
                        ...(providerResult?.meta || {}),
                        provider: {
                            id: provider.id,
                            label: provider.label,
                            type: provider.type
                        }
                    }
                };
            } catch (error) {
                const message = error?.message || String(error);
                const summary = classifyProviderError(provider, message);
                logger.warn('AI provider attempt failed', {
                    provider: provider.label,
                    type: provider.type,
                    summary,
                    messagePreview: message.slice(0, 400)
                });
                trace.push(createTraceStep({
                    stage: 'provider_attempt',
                    status: 'failed',
                    title: `${provider.label} basarisiz`,
                    summary,
                    details: sanitizeTextPreview(message),
                    meta: {
                        providerId: provider.id,
                        providerLabel: provider.label,
                        providerType: provider.type
                    }
                }));
                errors.push({
                    provider: provider.label,
                    type: provider.type,
                    raw: message,
                    summary
                });

                if (shouldShortCircuitSimilarProviders(provider, message)) {
                    logger.warn('AI provider chain short-circuiting similar providers', {
                        provider: provider.label,
                        type: provider.type,
                        reason: 'model_wide_unavailable'
                    });

                    while (
                        index + 1 < this.providers.length &&
                        this.providers[index + 1].type === provider.type
                    ) {
                        index += 1;
                        const skippedProvider = this.providers[index];
                        const skippedSummary = `${skippedProvider.label}: onceki benzer saglayici model genelinde gecici olarak kullanilamadi`;
                        errors.push({
                            provider: skippedProvider.label,
                            type: skippedProvider.type,
                            raw: message,
                            summary: skippedSummary
                        });
                        trace.push(createTraceStep({
                            stage: 'provider_attempt',
                            status: 'failed',
                            title: `${skippedProvider.label} atlandi`,
                            summary: skippedSummary,
                            details: 'Ayni tip saglayicilar model geneli gecici hatadan dolayi siradaki fallbacke birakildi.',
                            meta: {
                                providerId: skippedProvider.id,
                                providerLabel: skippedProvider.label,
                                providerType: skippedProvider.type
                            }
                        }));
                    }
                }
            }
        }

        const summaryText = errors.map((item) => item.summary).join(', ');
        const finalError = new Error(
            `Tum AI provider denemeleri basarisiz oldu. ${summaryText}. Ayarlar ekranindan aktif saglayicilari ve LM Studio sunucusunu kontrol edin.`
        );
        finalError.details = errors;
        finalError.trace = trace;
        logger.error('AI provider chain failed', {
            summary: summaryText,
            details: errors
        });
        throw finalError;
    }
}

const getProvider = () => {
    const settings = loadSettings();
    logger.debug('AI provider chain requested', {
        strategy: settings.strategy
    });
    return new ProviderChain(settings);
};

module.exports = {
    getProvider,
    loadSettings,
    saveSettings
};
