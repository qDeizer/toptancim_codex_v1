const db = require('../../../db');
const { buildSalesScopeClause } = require('../analysisContext');
const logger = require('../../../utils/logger');

const FORBIDDEN_KEYWORDS = /\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|CREATE|GRANT|REVOKE|COPY|CALL|EXEC|DO|WITH|UNION)\b/i;

function buildScopedQuery(sqlQuery, context) {
    const trimmedQuery = sqlQuery.trim();

    if (!/^SELECT\b/i.test(trimmedQuery)) {
        throw new Error('Yalnizca SELECT sorgularina izin verilir.');
    }

    if (trimmedQuery.includes(';')) {
        throw new Error('Tek sorgu calistirilabilir; noktali virgule izin verilmez.');
    }

    if (FORBIDDEN_KEYWORDS.test(trimmedQuery)) {
        throw new Error('Bu SQL yapisi izin verilen kapsam disinda.');
    }

    const joinCount = (trimmedQuery.match(/\bJOIN\b/gi) || []).length;
    const fromCount = (trimmedQuery.match(/\bFROM\b/gi) || []).length;
    if (joinCount > 0 || fromCount !== 1) {
        throw new Error('Sorgu yalnizca ml_sales_view tablosu uzerinde tek kaynakla calismalidir.');
    }

    const fromMatch = trimmedQuery.match(
        /\bFROM\s+ml_sales_view(?:\s+(?:AS\s+)?([a-zA-Z_][a-zA-Z0-9_]*))?(?=\s+(?:WHERE|GROUP|ORDER|HAVING|LIMIT|OFFSET|$))/i
    );
    if (!fromMatch) {
        throw new Error('Sorgu dogrudan ml_sales_view tablosunu kullanmalidir.');
    }

    const alias = fromMatch[1] || 'ml_sales_view';
    const scope = buildSalesScopeClause(context, '');
    const replacement = `FROM (SELECT * FROM ml_sales_view WHERE ${scope.clause}) AS ${alias}`;
    let scopedQuery = trimmedQuery.replace(fromMatch[0], replacement);

    if (!/\bLIMIT\b/i.test(scopedQuery)) {
        scopedQuery = `${scopedQuery} LIMIT 200`;
    }

    return {
        sql: scopedQuery,
        params: scope.params
    };
}

async function sqlQueryExecutor(args, context) {
    const { sql_query } = args;

    if (!sql_query || typeof sql_query !== 'string') {
        logger.warn('SQL tool rejected request', {
            contextMode: context.mode,
            reason: 'missing_sql_query'
        });
        return {
            success: false,
            error: 'sql_query parametresi gereklidir.'
        };
    }

    try {
        logger.info('SQL tool execution started', {
            contextMode: context.mode,
            targetUserId: context.target_user_id || null,
            queryPreview: sql_query.trim().slice(0, 180)
        });
        const scopedQuery = buildScopedQuery(sql_query, context);
        const result = await db.query(scopedQuery.sql, scopedQuery.params);

        logger.info('SQL tool execution completed', {
            contextMode: context.mode,
            targetUserId: context.target_user_id || null,
            rowCount: result.rowCount
        });
        return {
            success: true,
            rowCount: result.rowCount,
            applied_scope: context.mode,
            data: result.rows
        };
    } catch (error) {
        logger.warn('SQL tool execution failed', {
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
    name: 'sql_query_executor',
    description: 'Kesin satis istatistikleri icin ml_sales_view uzerinde PostgreSQL SELECT sorgusu calistirir. Sorgu otomatik olarak aktif analiz kapsamiyla sinirlanir; model ayrica kisi filtresi eklemek zorunda degildir.',
    parameters: {
        type: 'OBJECT',
        properties: {
            sql_query: {
                type: 'STRING',
                description: 'Tek bir SELECT sorgusu. Kaynak tablo yalnizca ml_sales_view olmalidir. Alanlar: product_name, product_id, variant_id, variant_name, category_name, shelf_location, cost_price, sold_price, quantity, total_amount, customer_role, customer_id, customer_lat, customer_lng, sale_date, order_status, current_stock, wholesaler_id, cart_id, line_total, customer_business_name, customer_first_name, customer_last_name, wholesaler_business_name.'
            }
        },
        required: ['sql_query']
    }
};

module.exports = {
    execute: sqlQueryExecutor,
    declaration: geminiDeclaration
};
