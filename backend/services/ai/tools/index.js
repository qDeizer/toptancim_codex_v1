const sqlQueryExecutor = require('./sqlQueryExecutor');
const knnAnalyzer = require('./knnAnalyzer');
const trendPredictor = require('./trendPredictor');
const logger = require('../../../utils/logger');

const toolsMap = {
    'sql_query_executor': sqlQueryExecutor,
    'knn_analyzer': knnAnalyzer,
    'trend_predictor': trendPredictor
};

function getGeminiTools() {
    return [{
        functionDeclarations: [
            sqlQueryExecutor.declaration,
            knnAnalyzer.declaration,
            trendPredictor.declaration
        ]
    }];
}

async function executeTool(toolName, args, context) {
    if (!toolsMap[toolName]) {
        logger.warn('AI tool dispatch failed', {
            toolName,
            reason: 'tool_not_found'
        });
        throw new Error(`Tool ${toolName} not found`);
    }

    logger.info('AI tool dispatch started', {
        toolName,
        contextMode: context.mode,
        targetUserId: context.target_user_id || null
    });
    const result = await toolsMap[toolName].execute(args, context);
    logger.info('AI tool dispatch completed', {
        toolName,
        contextMode: context.mode,
        targetUserId: context.target_user_id || null,
        success: result?.success !== false
    });
    return result;
}

module.exports = {
    getGeminiTools,
    executeTool
};
