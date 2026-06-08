const AIInterface = require('./AIInterface');
const toolsDispatcher = require('./tools');
const { formatContextForPrompt } = require('./analysisContext');
const logger = require('../../utils/logger');
const {
    createTraceStep,
    sanitizeTextPreview,
    summarizeToolResult
} = require('./traceUtils');

const SYSTEM_INSTRUCTION = `
Sen Toptancim isimli B2B platformunun yerel analiz asistanisin.
Her zaman Turkce cevap ver.
Yalnizca sana verilen kapsam dahilindeki veriyle konus.
Veri analizi icin sql_query_executor, knn_analyzer ve trend_predictor araclarini cagirabilirsin.
SQL araci sadece ml_sales_view tablosunu okur ve kapsam otomatik uygulanir.
Ham JSON yazma; arac ciktilarini ozetle ve maddeler halinde yorumla.
Dusunce zincirini, ic muhakemeni veya plani yazma; sadece kullaniciya gosterilecek nihai cevabi yaz.
Veri yetersizse bunu acikca soyle.
`.trim();

/**
 * Build the list of base URLs to attempt. Accepts URLs with or without `/v1`
 * suffix so users can paste either `http://localhost:20128`, `http://localhost:20128/v1`
 * or even the LM Studio variant.
 */
function buildCandidateBaseUrls(baseUrl) {
    const sanitized = (baseUrl || 'http://localhost:1234').replace(/\/+$/, '');
    const candidates = new Set([sanitized]);

    try {
        const url = new URL(sanitized);
        if (url.hostname === 'localhost') {
            url.hostname = '127.0.0.1';
            candidates.add(url.toString().replace(/\/+$/, ''));
        } else if (url.hostname === '127.0.0.1') {
            url.hostname = 'localhost';
            candidates.add(url.toString().replace(/\/+$/, ''));
        }
    } catch (error) {
        logger.warn('LocalLLMProvider invalid base URL', {
            baseUrl: sanitized,
            message: error.message
        });
    }

    return [...candidates];
}

/**
 * Convert Gemini-style tool declarations into OpenAI-compatible
 * function tool definitions (the format expected by LM Studio, 9router and any
 * OpenAI-compatible local server).
 */
function buildOpenAiTools() {
    const geminiTools = toolsDispatcher.getGeminiTools();
    if (!Array.isArray(geminiTools) || geminiTools.length === 0) {
        return [];
    }

    const declarations = geminiTools[0]?.functionDeclarations || [];

    return declarations.map((decl) => ({
        type: 'function',
        function: {
            name: decl.name,
            description: decl.description,
            parameters: convertGeminiParamsToJsonSchema(decl.parameters)
        }
    }));
}

function convertGeminiParamsToJsonSchema(schema) {
    if (!schema || typeof schema !== 'object') {
        return { type: 'object', properties: {} };
    }

    const typeMap = {
        OBJECT: 'object',
        STRING: 'string',
        NUMBER: 'number',
        INTEGER: 'integer',
        BOOLEAN: 'boolean',
        ARRAY: 'array'
    };

    const properties = {};
    if (schema.properties && typeof schema.properties === 'object') {
        for (const [propName, propSchema] of Object.entries(schema.properties)) {
            properties[propName] = {
                type: typeMap[propSchema.type] || (propSchema.type || 'string').toLowerCase(),
                description: propSchema.description || ''
            };
        }
    }

    return {
        type: typeMap[schema.type] || 'object',
        properties,
        required: Array.isArray(schema.required) ? schema.required : []
    };
}

function buildOpenAiMessages(history, lastUserMessage, scopedContextText) {
    const messages = [
        { role: 'system', content: SYSTEM_INSTRUCTION }
    ];

    messages.push({
        role: 'system',
        content: `Aktif analiz kapsami ve mevcut ozet veri:\n${scopedContextText}`
    });

    for (const item of history) {
        if (!item?.content) continue;
        messages.push({
            role: item.role === 'model' ? 'assistant' : item.role || 'user',
            content: String(item.content)
        });
    }

    messages.push({
        role: 'user',
        content: lastUserMessage
    });

    return messages;
}

class LocalLLMProvider extends AIInterface {
    constructor(options = {}) {
        super();
        this.baseUrl = options.baseUrl || process.env.LOCAL_LLM_URL || 'http://localhost:1234';
        this.modelName = options.modelName || process.env.LOCAL_LLM_MODEL || 'local-default';
        this.timeoutMs = Number(options.timeoutMs) > 0 ? Number(options.timeoutMs) : 60000;
        this.apiToken = options.apiToken || process.env.LOCAL_LLM_TOKEN || '';
        this.requiresAuth = options.requiresAuth === true && Boolean(this.apiToken);
        this.maxToolIterations = 4;
    }

    /**
     * Build candidate endpoints. For OpenAI-compatible servers the endpoint is
     * `/v1/chat/completions`. We accept both base URLs that already include
     * `/v1` and ones that don't.
     */
    buildEndpoints() {
        const candidates = buildCandidateBaseUrls(this.baseUrl);
        const endpoints = [];

        for (const base of candidates) {
            const normalized = base.replace(/\/+$/, '');
            if (/\/v1$/i.test(normalized)) {
                endpoints.push(`${normalized}/chat/completions`);
            } else {
                endpoints.push(`${normalized}/v1/chat/completions`);
            }
        }

        return [...new Set(endpoints)];
    }

    buildHeaders() {
        const headers = {
            'Content-Type': 'application/json',
            Accept: 'application/json'
        };
        if (this.requiresAuth && this.apiToken) {
            headers.Authorization = `Bearer ${this.apiToken}`;
        }
        return headers;
    }

    async postChat(messages, tools) {
        const endpoints = this.buildEndpoints();
        const headers = this.buildHeaders();
        const requestBody = {
            model: this.modelName,
            messages,
            temperature: 0.4,
            stream: false
        };
        if (Array.isArray(tools) && tools.length > 0) {
            requestBody.tools = tools;
            requestBody.tool_choice = 'auto';
        }

        const serializedBody = JSON.stringify(requestBody);
        const transportErrors = [];

        for (const endpoint of endpoints) {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), this.timeoutMs);

            try {
                logger.debug('LocalLLMProvider endpoint attempt started', {
                    endpoint,
                    model: this.modelName,
                    timeoutMs: this.timeoutMs,
                    requiresAuth: this.requiresAuth,
                    messageCount: messages.length,
                    toolCount: requestBody.tools ? requestBody.tools.length : 0
                });

                let response;
                try {
                    response = await fetch(endpoint, {
                        method: 'POST',
                        headers,
                        body: serializedBody,
                        signal: controller.signal
                    });
                } catch (transportError) {
                    // Real connection failure (server down, abort, DNS, etc.).
                    // Record and try the next candidate base URL.
                    const message = transportError?.name === 'AbortError'
                        ? `Yerel AI sunucusu zaman asimina ugradi (${this.timeoutMs} ms).`
                        : (transportError?.message || String(transportError));
                    transportErrors.push({ endpoint, message });
                    logger.warn('LocalLLMProvider transport failure', {
                        endpoint,
                        model: this.modelName,
                        message
                    });
                    continue;
                }

                const rawBody = await response.text();
                let payload = {};
                if (rawBody) {
                    try {
                        payload = JSON.parse(rawBody);
                    } catch (parseError) {
                        logger.warn('LocalLLMProvider response not JSON', {
                            endpoint,
                            status: response.status,
                            preview: rawBody.slice(0, 200)
                        });
                    }
                }

                logger.debug('LocalLLMProvider response received', {
                    endpoint,
                    model: this.modelName,
                    status: response.status,
                    ok: response.ok
                });

                if (!response.ok) {
                    // Server reachable but returned an HTTP error (404 invalid model,
                    // 401 auth, 429 rate limit, 500 internal, ...). This is not a
                    // transport issue, so we surface it directly and skip retrying
                    // the alternate base URL.
                    const details =
                        payload?.error?.message ||
                        payload?.error ||
                        payload?.message ||
                        response.statusText ||
                        'unknown error';
                    const detailsText = typeof details === 'string' ? details : JSON.stringify(details);
                    const httpError = new Error(
                        `Yerel AI sunucusu hata dondu [${response.status}]: ${detailsText}`
                    );
                    httpError.statusCode = response.status;
                    httpError.endpoint = endpoint;
                    logger.warn('LocalLLMProvider HTTP error response', {
                        endpoint,
                        model: this.modelName,
                        status: response.status,
                        detailsPreview: detailsText.slice(0, 200)
                    });
                    throw httpError;
                }

                return { payload, endpoint };
            } finally {
                clearTimeout(timeoutId);
            }
        }

        logger.error('LocalLLMProvider all endpoint attempts failed', {
            baseUrl: this.baseUrl,
            model: this.modelName,
            transportErrors
        });
        throw new Error(
            `Yerel AI sunucusuna baglanilamadi. Denenen adresler: ${transportErrors.map((item) => item.endpoint).join(', ')}. Detay: ${transportErrors.map((item) => item.message).join(' | ')}`
        );
    }

    extractText(message) {
        if (!message) return '';
        if (typeof message.content === 'string') {
            return message.content;
        }
        if (Array.isArray(message.content)) {
            return message.content
                .map((part) => {
                    if (typeof part === 'string') return part;
                    if (part?.type === 'text' && typeof part.text === 'string') return part.text;
                    if (typeof part?.text === 'string') return part.text;
                    return '';
                })
                .filter(Boolean)
                .join('\n');
        }
        return '';
    }

    parseToolCalls(message) {
        if (!message) return [];
        const calls = Array.isArray(message.tool_calls) ? message.tool_calls : [];
        return calls
            .filter((call) => call?.type === 'function' && call?.function?.name)
            .map((call) => {
                let args = {};
                const rawArgs = call.function.arguments;
                if (typeof rawArgs === 'string' && rawArgs.trim().length > 0) {
                    try {
                        args = JSON.parse(rawArgs);
                    } catch (error) {
                        logger.warn('LocalLLMProvider tool args parse failed', {
                            name: call.function.name,
                            preview: rawArgs.slice(0, 200)
                        });
                    }
                } else if (rawArgs && typeof rawArgs === 'object') {
                    args = rawArgs;
                }
                return {
                    id: call.id || `${call.function.name}_${Math.random().toString(36).slice(2, 8)}`,
                    name: call.function.name,
                    arguments: args,
                    rawArguments: typeof rawArgs === 'string' ? rawArgs : JSON.stringify(rawArgs || {})
                };
            });
    }

    async chat(messages, context) {
        const trace = [];

        try {
            const scopedContextText = formatContextForPrompt(context);
            const lastMessage = messages[messages.length - 1]?.content || '';
            const history = messages.slice(0, -1);

            logger.info('LocalLLMProvider request started', {
                baseUrl: this.baseUrl,
                model: this.modelName,
                messageCount: messages.length,
                contextMode: context.mode,
                requiresAuth: this.requiresAuth,
                timeoutMs: this.timeoutMs
            });

            const conversation = buildOpenAiMessages(history, lastMessage, scopedContextText);
            const tools = buildOpenAiTools();
            const usedTools = [];
            let lastEndpoint = null;

            for (let iteration = 0; iteration <= this.maxToolIterations; iteration += 1) {
                const { payload, endpoint } = await this.postChat(conversation, tools);
                lastEndpoint = endpoint;
                const choice = payload?.choices?.[0];
                const message = choice?.message || {};
                const toolCalls = this.parseToolCalls(message);

                if (toolCalls.length === 0) {
                    const finalText = this.extractText(message);
                    if (!finalText || !finalText.trim()) {
                        logger.warn('LocalLLMProvider returned empty text', {
                            endpoint,
                            model: this.modelName
                        });
                        throw new Error('Yerel model bos yanit dondurdu.');
                    }

                    trace.push(createTraceStep({
                        stage: 'final_llm',
                        title: 'Son yanit olusturuldu',
                        summary: usedTools.length > 0
                            ? `${usedTools.length} arac cagrisi yorumlanarak yanit yazildi.`
                            : 'Arac kullanmadan dogrudan yanit yazildi.',
                        details: sanitizeTextPreview(finalText),
                        meta: { endpoint }
                    }));

                    logger.info('LocalLLMProvider request completed', {
                        endpoint,
                        model: this.modelName,
                        responseLength: finalText.length,
                        toolCount: usedTools.length
                    });

                    return {
                        text: finalText,
                        trace,
                        meta: {
                            providerType: 'LOCAL',
                            model: this.modelName,
                            endpoint,
                            toolCount: usedTools.length
                        }
                    };
                }

                // Tool calls present — push assistant message and tool responses
                conversation.push({
                    role: 'assistant',
                    content: this.extractText(message) || '',
                    tool_calls: toolCalls.map((call) => ({
                        id: call.id,
                        type: 'function',
                        function: {
                            name: call.name,
                            arguments: call.rawArguments || JSON.stringify(call.arguments || {})
                        }
                    }))
                });

                for (const call of toolCalls) {
                    let toolResult;
                    try {
                        toolResult = await toolsDispatcher.executeTool(
                            call.name,
                            call.arguments || {},
                            context
                        );
                    } catch (error) {
                        logger.error(`LocalLLMProvider tool execution error [${call.name}]`, {
                            message: error.message
                        });
                        toolResult = { success: false, error: error.message };
                    }

                    usedTools.push(call.name);
                    trace.push(createTraceStep({
                        stage: 'tool_call',
                        status: toolResult?.success === false ? 'failed' : 'completed',
                        title: `${call.name} calistirildi`,
                        summary: summarizeToolResult(call.name, toolResult),
                        details: sanitizeTextPreview(JSON.stringify(call.arguments || {})),
                        meta: {
                            toolName: call.name,
                            args: call.arguments || {}
                        }
                    }));

                    conversation.push({
                        role: 'tool',
                        tool_call_id: call.id,
                        name: call.name,
                        content: JSON.stringify(toolResult || {})
                    });
                }
            }

            logger.warn('LocalLLMProvider exceeded tool iteration budget', {
                endpoint: lastEndpoint,
                model: this.modelName,
                iterations: this.maxToolIterations
            });
            throw new Error('Yerel model tool dongusunde takildi.');
        } catch (error) {
            error.trace = trace;
            throw error;
        }
    }
}

module.exports = LocalLLMProvider;
