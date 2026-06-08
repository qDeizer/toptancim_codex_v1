const logger = require('../../../utils/logger');
const { loadSettings } = require('../settingsStore');

function buildCandidateBaseUrls(baseUrl) {
    const sanitized = (baseUrl || 'http://127.0.0.1:8000').replace(/\/$/, '');
    const candidates = [sanitized];

    try {
        const url = new URL(sanitized);
        if (url.hostname === 'localhost') {
            url.hostname = '127.0.0.1';
            candidates.push(url.toString().replace(/\/$/, ''));
        } else if (url.hostname === '127.0.0.1') {
            url.hostname = 'localhost';
            candidates.push(url.toString().replace(/\/$/, ''));
        }
    } catch (error) {
        logger.warn('ML service client invalid base URL', {
            baseUrl: sanitized,
            message: error.message
        });
    }

    return [...new Set(candidates)];
}

async function postToMlService(path, payload) {
    const settings = loadSettings();
    const mlService = settings.mlService || {
        enabled: true,
        baseUrl: 'http://127.0.0.1:8000',
        timeoutMs: 120000
    };

    if (mlService.enabled === false) {
        throw new Error('ML servisi ayarlardan devre disi birakilmis.');
    }

    const candidateBaseUrls = buildCandidateBaseUrls(mlService.baseUrl);
    const errors = [];

    logger.info('ML service request started', {
        path,
        baseUrl: mlService.baseUrl,
        candidateBaseUrls,
        timeoutMs: mlService.timeoutMs
    });

    for (const baseUrl of candidateBaseUrls) {
        const endpoint = `${baseUrl}${path}`;

        try {
            logger.debug('ML service endpoint attempt started', {
                endpoint,
                path
            });
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload),
                signal: AbortSignal.timeout(mlService.timeoutMs)
            });

            const responsePayload = await response.json().catch(() => ({}));
            logger.debug('ML service endpoint attempt received response', {
                endpoint,
                status: response.status,
                ok: response.ok
            });

            if (!response.ok) {
                const detail = responsePayload.detail || responsePayload.error || response.statusText;
                logger.warn('ML service endpoint returned application error', {
                    endpoint,
                    path,
                    status: response.status,
                    detail
                });
                throw new Error(`ML service hatasi [${response.status}]: ${detail}`);
            }

            logger.info('ML service request completed', {
                endpoint,
                path
            });
            return responsePayload;
        } catch (error) {
            const message = error?.message || String(error);
            if (message.startsWith('ML service hatasi [')) {
                throw error;
            }
            errors.push({
                endpoint,
                message
            });
            logger.warn('ML service endpoint attempt failed', {
                endpoint,
                path,
                message
            });
        }
    }

    logger.error('ML service request failed for all endpoints', {
        path,
        baseUrl: mlService.baseUrl,
        candidateBaseUrls,
        errors
    });
    throw new Error(
        `ML servisine ulasilamadi. Denenen endpointler: ${errors.map((item) => item.endpoint).join(', ')}`
    );
}

module.exports = {
    postToMlService
};
