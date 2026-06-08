const db = require('../../db');
const logger = require('../../utils/logger');

async function getInternalUser(userId) {
    logger.debug('Analysis context internal user lookup started', {
        userId
    });
    const result = await db.query(
        `SELECT
            u.user_id AS id,
            u.user_name,
            u.isletme_ismi,
            u.ad,
            u.soyad,
            u.role,
            u.email,
            u.tel_no,
            a.address_title,
            a.address,
            a.detailed_address,
            a.latitude,
            a.longitude
         FROM users u
         LEFT JOIN address_info a ON a.user_id = u.user_id
         WHERE u.user_id = $1`,
        [userId]
    );

    if (result.rowCount === 0) {
        logger.warn('Analysis context internal user not found', {
            userId
        });
        return null;
    }

    logger.debug('Analysis context internal user lookup completed', {
        userId,
        rowCount: result.rowCount
    });
    return {
        ...result.rows[0],
        scope: 'internal'
    };
}

async function getExternalUser(externalUserId) {
    logger.debug('Analysis context external user lookup started', {
        externalUserId
    });
    const result = await db.query(
        `SELECT
            external_user_id AS id,
            creator_id,
            isletme_ismi,
            ad,
            soyad,
            email,
            tel_no,
            address_title,
            address,
            detailed_address,
            latitude,
            longitude
         FROM external_users
         WHERE external_user_id = $1`,
        [externalUserId]
    );

    if (result.rowCount === 0) {
        logger.warn('Analysis context external user not found', {
            externalUserId
        });
        return null;
    }

    logger.debug('Analysis context external user lookup completed', {
        externalUserId,
        rowCount: result.rowCount
    });
    return {
        ...result.rows[0],
        role: 'external',
        scope: 'external'
    };
}

function buildSalesScopeClause(context, alias = 'ml_sales_view', startIndex = 1) {
    const prefix = alias ? `${alias}.` : '';

    if (context.mode === 'pair' && context.target_user_id) {
        return {
            clause: `((${prefix}wholesaler_id = $${startIndex} AND ${prefix}customer_id = $${startIndex + 1}) OR (${prefix}wholesaler_id = $${startIndex + 1} AND ${prefix}customer_id = $${startIndex}))`,
            params: [context.user_id, context.target_user_id]
        };
    }

    return {
        clause: `(${prefix}wholesaler_id = $${startIndex} OR ${prefix}customer_id = $${startIndex})`,
        params: [context.user_id]
    };
}

function buildFinanceScopeClause(context, alias = 'ft', startIndex = 1) {
    const prefix = alias ? `${alias}.` : '';

    if (context.mode === 'pair' && context.target_user_id) {
        return {
            clause: `((${prefix}from_id = $${startIndex} AND ${prefix}to_id = $${startIndex + 1}) OR (${prefix}from_id = $${startIndex + 1} AND ${prefix}to_id = $${startIndex}))`,
            params: [context.user_id, context.target_user_id]
        };
    }

    return {
        clause: `(${prefix}creator_id = $${startIndex} OR ${prefix}from_id = $${startIndex} OR ${prefix}to_id = $${startIndex})`,
        params: [context.user_id]
    };
}

async function getRelationTags(requesterId, targetUserId) {
    logger.debug('Analysis context relation tag lookup started', {
        requesterId,
        targetUserId
    });
    const relationIdsResult = await db.query(
        `SELECT relation_id
         FROM relations
         WHERE (wholesaler_id = $1 AND customer_id = $2)
            OR (wholesaler_id = $2 AND customer_id = $1)`,
        [requesterId, targetUserId]
    );

    const relationIds = relationIdsResult.rows.map((row) => row.relation_id);
    if (relationIds.length === 0) {
        logger.debug('Analysis context relation tag lookup skipped', {
            requesterId,
            targetUserId,
            relationCount: 0
        });
        return [];
    }

    const tagsResult = await db.query(
        `SELECT DISTINCT t.name
         FROM tags t
         JOIN tag_assignments ta ON ta.tag_id = t.tag_id
         WHERE ta.relation_id = ANY($1::text[])
           AND ta.assigner_id = $2
         ORDER BY t.name ASC`,
        [relationIds, requesterId]
    );

    const tags = tagsResult.rows.map((row) => row.name);
    logger.debug('Analysis context relation tag lookup completed', {
        requesterId,
        targetUserId,
        relationCount: relationIds.length,
        tagCount: tags.length
    });
    return tags;
}

async function getSalesOverview(context) {
    logger.debug('Analysis context sales overview started', {
        mode: context.mode,
        requesterId: context.user_id,
        targetUserId: context.target_user_id || null
    });
    const { clause, params } = buildSalesScopeClause(context, 'v');
    const summaryResult = await db.query(
        `SELECT
            COUNT(*)::int AS line_count,
            COUNT(DISTINCT v.cart_id)::int AS cart_count,
            COUNT(DISTINCT v.customer_id)::int AS customer_count,
            COUNT(DISTINCT v.product_id)::int AS product_count,
            COALESCE(SUM(v.quantity), 0)::int AS total_quantity,
            COALESCE(SUM(v.line_total), 0)::numeric AS total_revenue,
            MAX(v.sale_date) AS last_sale_date
         FROM ml_sales_view v
         WHERE ${clause}`,
        params
    );

    const topProductsResult = await db.query(
        `SELECT
            v.product_name,
            COALESCE(SUM(v.quantity), 0)::int AS total_quantity,
            COALESCE(SUM(v.line_total), 0)::numeric AS total_revenue
         FROM ml_sales_view v
         WHERE ${clause}
         GROUP BY v.product_name
         ORDER BY total_quantity DESC, total_revenue DESC
         LIMIT 5`,
        params
    );

    const salesOverview = {
        ...summaryResult.rows[0],
        top_products: topProductsResult.rows
    };
    logger.debug('Analysis context sales overview completed', {
        mode: context.mode,
        requesterId: context.user_id,
        targetUserId: context.target_user_id || null,
        cartCount: salesOverview.cart_count,
        productCount: salesOverview.product_count,
        totalQuantity: salesOverview.total_quantity
    });
    return salesOverview;
}

async function getFinanceOverview(context) {
    logger.debug('Analysis context finance overview started', {
        mode: context.mode,
        requesterId: context.user_id,
        targetUserId: context.target_user_id || null
    });
    const { clause, params } = buildFinanceScopeClause(context, 'ft');
    const result = await db.query(
        `SELECT
            COUNT(*)::int AS transaction_count,
            COUNT(*) FILTER (WHERE ft.approval_status = 'beklemede')::int AS pending_count,
            MAX(ft.transaction_date) AS last_transaction_date,
            COALESCE(SUM(CASE
                WHEN ft.transaction_type = 'Tahakkuk' AND ft.from_id = $1 THEN ft.amount
                ELSE 0
            END), 0)::numeric AS sales_total,
            COALESCE(SUM(CASE
                WHEN ft.transaction_type = 'Nakit Akışı' AND ft.to_id = $1 THEN ft.amount
                ELSE 0
            END), 0)::numeric AS collections_total,
            COALESCE(SUM(CASE
                WHEN ft.transaction_type = 'Tahakkuk' AND ft.to_id = $1 THEN ft.amount
                ELSE 0
            END), 0)::numeric AS purchases_total,
            COALESCE(SUM(CASE
                WHEN ft.transaction_type = 'Nakit Akışı' AND ft.from_id = $1 THEN ft.amount
                ELSE 0
            END), 0)::numeric AS payments_total
         FROM financial_transactions ft
         WHERE ${clause}`,
        params
    );

    const overview = result.rows[0];
    const salesTotal = Number(overview.sales_total || 0);
    const collectionsTotal = Number(overview.collections_total || 0);
    const purchasesTotal = Number(overview.purchases_total || 0);
    const paymentsTotal = Number(overview.payments_total || 0);

    const financeOverview = {
        ...overview,
        balance_estimate: salesTotal - collectionsTotal - purchasesTotal + paymentsTotal
    };
    logger.debug('Analysis context finance overview completed', {
        mode: context.mode,
        requesterId: context.user_id,
        targetUserId: context.target_user_id || null,
        transactionCount: financeOverview.transaction_count,
        pendingCount: financeOverview.pending_count,
        balanceEstimate: financeOverview.balance_estimate
    });
    return financeOverview;
}

async function resolveTargetContext(requesterId, targetUserId) {
    logger.info('Analysis context pair scope resolution started', {
        requesterId,
        targetUserId
    });
    const relationResult = await db.query(
        `SELECT
            relation_id,
            wholesaler_id,
            customer_id,
            is_wholesaler_internal,
            is_customer_internal,
            wholesaler_approval,
            customer_approval
         FROM relations
         WHERE (wholesaler_id = $1 AND customer_id = $2)
            OR (wholesaler_id = $2 AND customer_id = $1)
         LIMIT 1`,
        [requesterId, targetUserId]
    );

    if (relationResult.rowCount === 0) {
        logger.warn('Analysis context pair scope unauthorized', {
            requesterId,
            targetUserId
        });
        const error = new Error('Secilen kisi ile analiz yapma yetkiniz yok.');
        error.statusCode = 403;
        throw error;
    }

    const relation = relationResult.rows[0];
    const targetIsInternal =
        relation.wholesaler_id === requesterId
            ? relation.is_customer_internal
            : relation.is_wholesaler_internal;

    const target = targetIsInternal
        ? await getInternalUser(targetUserId)
        : await getExternalUser(targetUserId);

    if (!target) {
        logger.warn('Analysis context pair target missing', {
            requesterId,
            targetUserId,
            targetIsInternal
        });
        const error = new Error('Hedef kisi bulunamadi.');
        error.statusCode = 404;
        throw error;
    }

    const relationTags = await getRelationTags(requesterId, targetUserId);
    logger.info('Analysis context pair scope resolved', {
        requesterId,
        targetUserId,
        targetScope: target.scope,
        relationId: relation.relation_id,
        relationTagCount: relationTags.length
    });
    return {
        relation,
        target,
        relation_tags: relationTags
    };
}

async function resolveAnalysisContext(requesterId, targetUserId) {
    logger.info('Analysis context resolution started', {
        requesterId,
        targetUserId: targetUserId || null
    });
    const requester = await getInternalUser(requesterId);
    if (!requester) {
        logger.warn('Analysis context requester missing', {
            requesterId
        });
        const error = new Error('Kullanici bulunamadi.');
        error.statusCode = 404;
        throw error;
    }

    const context = {
        user_id: requesterId,
        role: requester.role,
        mode: 'self',
        target_user_id: null,
        requester,
        target: null,
        relation: null,
        relation_tags: []
    };

    if (targetUserId && targetUserId !== requesterId) {
        const targetContext = await resolveTargetContext(requesterId, targetUserId);
        context.mode = 'pair';
        context.target_user_id = targetUserId;
        context.target = targetContext.target;
        context.relation = targetContext.relation;
        context.relation_tags = targetContext.relation_tags;
    }

    const [salesOverview, financeOverview] = await Promise.all([
        getSalesOverview(context),
        getFinanceOverview(context)
    ]);

    context.summaries = {
        sales: salesOverview,
        finance: financeOverview
    };

    logger.info('Analysis context resolution completed', {
        requesterId,
        mode: context.mode,
        targetUserId: context.target_user_id || null,
        salesLineCount: context.summaries.sales?.line_count || 0,
        financeTransactionCount: context.summaries.finance?.transaction_count || 0
    });
    return context;
}

function compactPerson(person) {
    if (!person) {
        return null;
    }

    return {
        id: person.id,
        isletme_ismi: person.isletme_ismi || null,
        ad: person.ad || null,
        soyad: person.soyad || null,
        role: person.role || null,
        scope: person.scope || null,
        address: person.address || null,
        latitude: person.latitude || null,
        longitude: person.longitude || null
    };
}

function formatContextForPrompt(context) {
    return JSON.stringify(
        {
            kapsam: context.mode === 'pair' ? 'ben_ve_secili_kisi' : 'sadece_ben',
            ben: compactPerson(context.requester),
            hedef_kisi: compactPerson(context.target),
            iliski_etiketleri: context.relation_tags,
            satis_ozeti: context.summaries?.sales || null,
            finans_ozeti: context.summaries?.finance || null
        },
        null,
        2
    );
}

module.exports = {
    buildFinanceScopeClause,
    buildSalesScopeClause,
    formatContextForPrompt,
    resolveAnalysisContext
};
