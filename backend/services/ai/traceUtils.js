function nowIso() {
    return new Date().toISOString();
}

function createTraceStep({
    stage,
    status = 'completed',
    title,
    summary,
    details = null,
    meta = null
}) {
    return {
        id: `${stage}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
        stage,
        status,
        title,
        summary,
        details,
        meta,
        timestamp: nowIso()
    };
}

function stripMarkdownCodeFence(text) {
    const raw = (text || '').trim();
    if (!raw.startsWith('```')) {
        return raw;
    }

    return raw
        .replace(/^```(?:json)?/i, '')
        .replace(/```$/i, '')
        .trim();
}

function safeJsonParse(text, fallbackValue) {
    const normalized = stripMarkdownCodeFence(text);

    try {
        return JSON.parse(normalized);
    } catch (error) {
        return fallbackValue;
    }
}

function summarizeToolResult(toolName, result) {
    if (!result || result.success === false) {
        return result?.error || 'Arac cagrisi basarisiz oldu.';
    }

    if (toolName === 'sql_query_executor') {
        return `${result.rowCount || 0} satir okundu.`;
    }

    if (toolName === 'knn_analyzer') {
        const count = Array.isArray(result?.data?.recommended_products)
            ? result.data.recommended_products.length
            : 0;
        return `${count} urun onerisi uretildi.`;
    }

    if (toolName === 'trend_predictor') {
        const total = result?.data?.total_predicted_quantity;
        if (typeof total === 'number') {
            return `${total} adetlik tahmin uretildi.`;
        }

        const count = Array.isArray(result?.data?.predictions)
            ? result.data.predictions.length
            : 0;
        return `${count} tahmin noktasi uretildi.`;
    }

    return 'Arac cagrisi tamamlandi.';
}

function summarizeFilterPlan(filterPlan) {
    const tools = Array.isArray(filterPlan?.recommended_tools)
        ? filterPlan.recommended_tools
        : [];

    return tools.length > 0
        ? `Sorgu daraltildi. Onerilen araclar: ${tools.join(', ')}`
        : 'Sorgu daraltildi. Dogrudan cevap veya esnek arac secimi bekleniyor.';
}

function sanitizeTextPreview(text, maxLength = 240) {
    const value = (text || '').replace(/\s+/g, ' ').trim();
    if (value.length <= maxLength) {
        return value;
    }

    return `${value.slice(0, maxLength)}...`;
}

module.exports = {
    createTraceStep,
    safeJsonParse,
    sanitizeTextPreview,
    summarizeFilterPlan,
    summarizeToolResult
};
