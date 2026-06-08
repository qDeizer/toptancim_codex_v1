const crypto = require('crypto');

const generateId = (prefix = '', length = 10) => {
  const randomPart = crypto.randomBytes(Math.ceil(length / 2))
    .toString('hex')
    .slice(0, length);
    
  return `${prefix}${randomPart}`;
};

module.exports = generateId;