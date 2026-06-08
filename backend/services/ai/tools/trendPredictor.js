const logger = require('../../../utils/logger');
const { postToMlService } = require('./mlServiceClient');

async function trendPredictor(args, context) {
    const payload = {
        product_name: args.product_name || null,
        period_days: args.period_days || 30,
        min_data_points: args.min_data_points || 5,
        scope_mode: context.mode,
        requester_user_id: context.user_id,
        target_user_id: context.target_user_id || null
    };

    try {
        logger.info('Trend tool execution started', {
            contextMode: context.mode,
            targetUserId: context.target_user_id || null,
            productName: payload.product_name,
            periodDays: payload.period_days,
            minDataPoints: payload.min_data_points
        });
        const parsed = await postToMlService('/api/v1/tools/trend_predict', payload);
        logger.info('Trend tool execution completed', {
            contextMode: context.mode,
            targetUserId: context.target_user_id || null,
            predictionCount: Array.isArray(parsed?.predictions)
                ? parsed.predictions.length
                : null
        });
        return {
            success: true,
            data: parsed
        };
    } catch (error) {
        logger.error('Trend tool execution failed', {
            contextMode: context.mode,
            targetUserId: context.target_user_id || null,
            message: error.message
        });
        return {
            success: false,
            error: error.message
        };
    }
}

const geminiDeclaration = {
    name: 'trend_predictor',
    description: 'Gecmis satis hareketinden yola cikarak gelecek donem satis miktari tahmini uretir. Arac yalnizca aktif analiz kapsamina ait veriyi kullanir.',
    parameters: {
        type: 'OBJECT',
        properties: {
            product_name: {
                type: 'STRING',
                description: 'Tahmin yapilacak urun adi. Bos birakilirsa mevcut kapsamin genel satis egilimi tahmin edilir.'
            },
            period_days: {
                type: 'NUMBER',
                description: 'Kac gunluk tahmin yapilacagi. Varsayilan 30.'
            },
            min_data_points: {
                type: 'NUMBER',
                description: 'Tahmin icin gerekli minimum tarihsel veri noktasi. Varsayilan 5.'
            }
        }
    }
};

module.exports = {
    execute: trendPredictor,
    declaration: geminiDeclaration
};
