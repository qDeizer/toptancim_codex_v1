const aiFactory = require('../services/ai');
const { resolveAnalysisContext } = require('../services/ai/analysisContext');
const logger = require('../utils/logger');

const chat = async (req, res) => {
    const { messages, targetUserId } = req.body;

    if (!messages || !Array.isArray(messages)) {
        logger.warn('AI chat request rejected', {
            requesterId: req.user?.id || null,
            reason: 'messages_missing_or_invalid'
        });
        return res.status(400).json({ error: 'messages dizisi gereklidir.' });
    }

    try {
        logger.info('AI chat request received', {
            requesterId: req.user?.id || null,
            messageCount: messages.length,
            targetUserId: targetUserId || null
        });
        const provider = aiFactory.getProvider();
        const context = await resolveAnalysisContext(req.user.id, targetUserId || null);
        logger.debug('AI chat context resolved', {
            requesterId: req.user.id,
            contextMode: context.mode,
            targetUserId: context.target_user_id || null
        });
        const aiResult = await provider.chat(messages, context);
        const responseText = aiResult?.text || '';

        logger.info('AI chat request completed', {
            requesterId: req.user.id,
            contextMode: context.mode,
            targetUserId: context.target_user_id || null,
            responseLength: responseText.length,
            traceCount: Array.isArray(aiResult?.trace) ? aiResult.trace.length : 0
        });
        res.json({
            response: responseText,
            trace: Array.isArray(aiResult?.trace) ? aiResult.trace : [],
            meta: aiResult?.meta || {}
        });
    } catch (error) {
        logger.error('AI chat request failed', {
            requesterId: req.user?.id || null,
            targetUserId: targetUserId || null,
            message: error.message,
            details: error.details || null,
            traceCount: Array.isArray(error.trace) ? error.trace.length : 0
        });
        res.status(error.statusCode || 500).json({
            error: 'AI yanit uretirken bir hata olustu: ' + error.message,
            trace: Array.isArray(error.trace) ? error.trace : []
        });
    }
};

const getSettings = async (req, res) => {
    try {
        logger.info('AI settings read requested', {
            requesterId: req.user?.id || null
        });
        const settings = aiFactory.loadSettings();
        logger.info('AI settings read completed', {
            requesterId: req.user?.id || null,
            providerCount: settings.providers.length,
            strategy: settings.strategy
        });
        res.json(settings);
    } catch (error) {
        logger.error('AI settings read failed', {
            requesterId: req.user?.id || null,
            message: error.message
        });
        res.status(500).json({
            error: 'AI ayarlari okunurken bir hata olustu: ' + error.message
        });
    }
};

const updateSettings = async (req, res) => {
    try {
        logger.info('AI settings update requested', {
            requesterId: req.user?.id || null,
            strategy: req.body?.strategy || null,
            providerCount: Array.isArray(req.body?.providers) ? req.body.providers.length : 0
        });
        const nextSettings = aiFactory.saveSettings(req.body || {});
        logger.info('AI settings update completed', {
            requesterId: req.user?.id || null,
            strategy: nextSettings.strategy,
            providerCount: nextSettings.providers.length
        });
        res.json(nextSettings);
    } catch (error) {
        logger.error('AI settings update failed', {
            requesterId: req.user?.id || null,
            message: error.message
        });
        res.status(500).json({
            error: 'AI ayarlari kaydedilirken bir hata olustu: ' + error.message
        });
    }
};

module.exports = {
    chat,
    getSettings,
    updateSettings
};
