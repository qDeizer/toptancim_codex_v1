class AIInterface {
    /**
     * Initializes the AI Provider
     */
    constructor() {
        if (new.target === AIInterface) {
            throw new TypeError("Cannot construct AIInterface instances directly");
        }
    }

    /**
     * Sends a chat message to the LLM and processes its response
     * @param {Array<Object>} messages - Array of message objects {role: 'user'|'model'|'system', content: string}
     * @param {Object} context - Context object (e.g., user_id, role)
     * @returns {Promise<{text: string, trace: Array<Object>, meta?: Object}>}
     */
    async chat(messages, context) {
        throw new Error("Method 'chat()' must be implemented.");
    }
}

module.exports = AIInterface;
