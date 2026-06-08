const logger = require('../../../utils/logger');
const { postToMlService } = require('./mlServiceClient');

async function knnAnalyzer(args, context) {
    const payload = {
        customer_role: args.customer_role || null,
        query_text: args.query || '',
        k_neighbors: args.k_neighbors || 5,
        max_recommendations: args.max_recommendations || 8,
        scope_mode: context.mode,
        requester_user_id: context.user_id,
        target_user_id: context.target_user_id || null
    };

    try {
        logger.info('KNN tool execution started', {
            contextMode: context.mode,
            targetUserId: context.target_user_id || null,
            customerRole: payload.customer_role,
            hasQuery: Boolean(payload.query_text),
            kNeighbors: payload.k_neighbors
        });
        const parsed = await postToMlService('/api/v1/tools/knn_analysis', payload);
        logger.info('KNN tool execution completed', {
            contextMode: context.mode,
            targetUserId: context.target_user_id || null,
            recommendationCount: Array.isArray(parsed?.recommended_products)
                ? parsed.recommended_products.length
                : null
        });
        return {
            success: true,
            data: parsed
        };
    } catch (error) {
        logger.error('KNN tool execution failed', {
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
    name: 'knn_analyzer',
    description: 'Benzer musteri davranislarini ve bolgesel egilimleri analiz eder. Arac, aktif kapsam icindeki satis verisinde en yakin musteri komsularini bularak oneri listesi uretir.',
    parameters: {
        type: 'OBJECT',
        properties: {
            customer_role: {
                type: 'STRING',
                description: 'Aranacak musteri rolu veya tipi. Bilinmiyorsa bos birakilabilir.'
            },
            k_neighbors: {
                type: 'NUMBER',
                description: 'Analizde kac komsu dikkate alinacak. Varsayilan 5.'
            },
            max_recommendations: {
                type: 'NUMBER',
                description: 'En fazla kac urun onerisi donulecek. Varsayilan 8.'
            },
            query: {
                type: 'STRING',
                description: 'Analizin odagi hakkinda serbest metin.'
            }
        },
        required: []
    }
};

module.exports = {
    execute: knnAnalyzer,
    declaration: geminiDeclaration
};
