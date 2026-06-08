const socketIo = require('socket.io');
const jwt = require('jsonwebtoken');
const logger = require('./utils/logger');

let io;

module.exports = {
    init: (httpServer) => {
        io = socketIo(httpServer, {
            cors: {
                origin: "*", // Allow all origins for now, or match index.js cors settings
                methods: ["GET", "POST"]
            }
        });

        logger.info('Socket.IO initialized');

        // Middleware for authentication
        io.use((socket, next) => {
            const token = socket.handshake.auth.token || socket.handshake.query.token;
            if (!token) {
                logger.warn('Socket connection attempt without token', { socketId: socket.id });
                return next(new Error('Authentication error'));
            }

            try {
                // Verify token (assuming secret is in process.env.JWT_SECRET)
                const decoded = jwt.verify(token, process.env.JWT_SECRET);
                socket.decoded_token = decoded;
                logger.debug('Socket authenticated successfully', { userId: decoded.id, socketId: socket.id });
                next();
            } catch (err) {
                logger.error('Socket token verification failed', err);
                next(new Error('Authentication error'));
            }
        });

        io.on('connection', (socket) => {
            const userId = socket.decoded_token.id;
            logger.info('Client connected', { socketId: socket.id, userId });

            // Automatic Join on connection
            const roomName = `user_${userId}`;
            socket.join(roomName);
            logger.debug(`Socket ${socket.id} automatically joined room ${roomName}`);

            // Explicit Join Event for client-side re-checks
            socket.on('join_room', (room) => {
                if (room === roomName) {
                    if (!socket.rooms.has(room)) {
                        socket.join(room);
                        logger.debug(`Socket ${socket.id} manually joined room ${room}`);
                    } else {
                        logger.debug(`Socket ${socket.id} already in room ${room}`);
                    }
                } else {
                    logger.warn(`Socket ${socket.id} (User: ${userId}) tried to join unauthorized room ${room}`);
                }
            });

            socket.on('disconnect', (reason) => {
                logger.info('Client disconnected', { socketId: socket.id, reason });
            });
        });

        return io;
    },
    getIO: () => {
        if (!io) {
            throw new Error('Socket.io not initialized!');
        }
        return io;
    }
};
