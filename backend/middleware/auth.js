const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

const auth = (req, res, next) => {
    const authHeader = req.header('Authorization');

    if (!authHeader) {
        logger.warn('Auth middleware rejected request', {
            path: req.originalUrl,
            reason: 'missing_authorization_header'
        });
        return res.status(401).json({ message: 'No token, authorization denied' });
    }

    try {
        const token = authHeader.split(' ')[1]; // "Bearer TOKEN" formatından token'ı ayır
        if (!token) {
            logger.warn('Auth middleware rejected request', {
                path: req.originalUrl,
                reason: 'invalid_bearer_format'
            });
            return res.status(401).json({ message: 'Token format is invalid' });
        }
        
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded.user;
        logger.debug('Auth middleware accepted request', {
            path: req.originalUrl,
            userId: req.user?.id || null
        });
        next();
    } catch (err) {
        logger.warn('Auth middleware rejected request', {
            path: req.originalUrl,
            reason: 'token_verification_failed',
            message: err.message
        });
        res.status(401).json({ message: 'Token is not valid' });
    }
};

module.exports = auth;
