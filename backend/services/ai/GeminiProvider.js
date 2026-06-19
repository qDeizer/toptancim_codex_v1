const { GoogleGenerativeAI } = require('@google/generative-ai');

const AIInterface = require('./AIInterface');
const toolsDispatcher = require('./tools');
const { formatContextForPrompt } = require('./analysisContext');
const logger = require('../../utils/logger');
const {
    createTraceStep,
    sanitizeTextPreview,
    summarizeToolResult
} = require('./traceUtils');

function getFunctionCalls(response) {
    if (!response) {
        return [];
    }

    if (typeof response.functionCalls === 'function') {
        return response.functionCalls() || [];
    }

    return response.functionCalls || [];
}

const SYSTEM_INSTRUCTION = `
Sen Toptancim isimli B2B platformunun analiz asistanisin.
Her zaman Turkce cevap ver.
Sana verilen analiz kapsami disina cikma.
Gerekli oldugunda sql_query_executor, knn_analyzer veya trend_predictor araclarini cagir.
Ayni turda birden fazla araci ardisik olarak cagirabilirsin.
SQL araci yalnizca ml_sales_view tablosunu okur ve kapsam otomatik uygulanir.
KNN araci benzer musteri egilimlerini bulur.
Trend araci gelecek satis tahmini verir.
Ham JSON veya tool ciktilarini oldugu gibi yapistirma; ozetle, yorumla ve maddeler halinde acikla.
Eger araclar veri yetersizligi raporladiysa bunu acikca soyle ve tahmini net veri gibi sunma.
Dusunce zinciri ve ic muhakemeni yazma; sadece kullaniciya gosterilecek nihai cevabi yaz.
`.trim();

class GeminiProvider extends AIInterface {
    constructor(options = {}) {
        super();

        this.apiKey = options.apiKey || process.env.GEMINI_API_KEY;
        this.label = options.label || 'gemini';
        this.modelName = options.modelName || process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';

        if (!this.apiKey) {
            throw new Error('GEMINI_API_KEY tanimli degil.');
        }

        this.genAI = new GoogleGenerativeAI(this.apiKey);
        this.maxToolIterations = 4;
    }

    async chat(messages, context) {
        const trace = [];

        try {
            logger.info('GeminiProvider chat started', {
                provider: this.label,
                model: this.modelName,
                endpoint: `https://generativelanguage.googleapis.com/v1beta/models/${this.modelName}:generateContent`,
                messageCount: messages.length,
                contextMode: context.mode,
                targetUserId: context.target_user_id || null
            });

            const history = messages.slice(0, -1).map((message) => ({
                role: message.role === 'user' ? 'user' : 'model',
                parts: [{ text: message.content }]
            }));

            const lastMessage = messages[messages.length - 1]?.content || '';
            const scopedContextText = formatContextForPrompt(context);

            const model = this.genAI.getGenerativeModel({
                model: this.modelName,
                tools: toolsDispatcher.getGeminiTools(),
                systemInstruction: SYSTEM_INSTRUCTION
            });

            const chat = model.startChat({ history });
            let result = await chat.sendMessage(
                [
                    'Analiz kapsami ve mevcut ozet veri:',
                    scopedContextText,
                    '',
                    'Kullanici sorusu:',
                    lastMessage
                ].join('\n')
            );

            let toolIteration = 0;
            let functionCalls = getFunctionCalls(result.response);
            const usedTools = [];

            logger.debug('GeminiProvider initial response received', {
                provider: this.label,
                functionCallCount: functionCalls.length
            });

            while (functionCalls.length > 0 && toolIteration < this.maxToolIterations) {
                const functionResponses = [];
                logger.info('GeminiProvider tool iteration', {
                    provider: this.label,
                    iteration: toolIteration + 1,
                    functionCalls: functionCalls.map((call) => call.name)
                });

                for (const call of functionCalls) {
                    let toolResult;
                    try {
                        toolResult = await toolsDispatcher.executeTool(
                            call.name,
                            call.args || {},
                            context
                        );
                        functionResponses.push({
                            functionResponse: {
                                name: call.name,
                                response: toolResult
                            }
                        });
                    } catch (error) {
                        logger.error(`GeminiProvider tool execution error [${call.name}]`, {
                            message: error.message
                        });
                        toolResult = {
                            success: false,
                            error: error.message
                        };
                        functionResponses.push({
                            functionResponse: {
                                name: call.name,
                                response: toolResult
                            }
                        });
                    }

                    usedTools.push(call.name);
                    trace.push(createTraceStep({
                        stage: 'tool_call',
                        status: toolResult?.success === false ? 'failed' : 'completed',
                        title: `${call.name} calistirildi`,
                        summary: summarizeToolResult(call.name, toolResult),
                        details: sanitizeTextPreview(JSON.stringify(call.args || {})),
                        meta: {
                            toolName: call.name,
                            args: call.args || {}
                        }
                    }));
                }

                result = await chat.sendMessage(functionResponses);
                functionCalls = getFunctionCalls(result.response);
                toolIteration += 1;
                logger.debug('GeminiProvider post-tool response received', {
                    provider: this.label,
                    iteration: toolIteration,
                    functionCallCount: functionCalls.length
                });
            }

            const finalText = result.response?.text?.();
            if (!finalText || !finalText.trim()) {
                logger.warn('GeminiProvider returned empty text', {
                    provider: this.label,
                    model: this.modelName
                });
                return {
                    text: 'Bu soru icin anlamli bir AI cevabi uretilemedi.',
                    trace,
                    meta: {
                        providerType: 'GEMINI',
                        label: this.label,
                        model: this.modelName
                    }
                };
            }

            trace.push(createTraceStep({
                stage: 'final_llm',
                title: 'Son yanit olusturuldu',
                summary: usedTools.length > 0
                    ? `${usedTools.length} arac cagrisi yorumlanarak yanit yazildi.`
                    : 'Arac kullanmadan dogrudan yanit yazildi.',
                details: sanitizeTextPreview(finalText)
            }));

            logger.info('GeminiProvider chat completed', {
                provider: this.label,
                model: this.modelName,
                responseLength: finalText.length,
                toolCount: usedTools.length
            });
            return {
                text: finalText,
                trace,
                meta: {
                    providerType: 'GEMINI',
                    label: this.label,
                    model: this.modelName,
                    toolCount: usedTools.length
                }
            };
        } catch (error) {
            error.trace = trace;
            throw error;
        }
    }
}

module.exports = GeminiProvider;
