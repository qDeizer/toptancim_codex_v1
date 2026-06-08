const fs = require('fs');
const path = require('path');

const logLevels = {
    INFO: 'INFO',
    WARN: 'WARN',
    ERROR: 'ERROR',
    DEBUG: 'DEBUG'
};

const log = (level, message, data = null) => {
    const timestamp = new Date().toISOString();
    let logMessage = `[${timestamp}] [${level}] ${message}`;

    if (data) {
        if (data instanceof Error) {
            logMessage += `\nStack: ${data.stack}`;
        } else {
            try {
                logMessage += `\nData: ${JSON.stringify(data, null, 2)}`;
            } catch (e) {
                logMessage += `\nData: [Circular or Non-Serializable]`;
            }
        }
    }

    console.log(logMessage);

    // Optional: Write to file
    // fs.appendFileSync(path.join(__dirname, '../app.log'), logMessage + '\n');
};

module.exports = {
    info: (msg, data) => log(logLevels.INFO, msg, data),
    warn: (msg, data) => log(logLevels.WARN, msg, data),
    error: (msg, data) => log(logLevels.ERROR, msg, data),
    debug: (msg, data) => log(logLevels.DEBUG, msg, data),
};
