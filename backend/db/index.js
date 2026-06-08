const { Pool } = require('pg');
require('dotenv').config();

const dbName = process.env.DB_NAME || process.env.DB_DATABASE || 'toptancimdb';
const dbPassword = process.env.DB_PASS || process.env.DB_PASSWORD || 'postgres';
const dbUser = process.env.DB_USER || 'postgres';
const dbHost = process.env.DB_HOST || 'localhost';
const dbPort = process.env.DB_PORT || 5432;
const dbSslEnv = process.env.DB_SSL;
const useSsl =
  typeof dbSslEnv === 'string'
    ? dbSslEnv.toLowerCase() === 'true'
    : process.env.NODE_ENV !== 'development';

const pool = new Pool({
  user: dbUser,
  host: dbHost,
  database: dbName,
  password: dbPassword,
  port: dbPort,
  ssl: useSsl ? { rejectUnauthorized: false } : false
});

module.exports = {
  // Tekil sorgular için
  query: (text, params) => pool.query(text, params),
  
  // Transaction (BEGIN/COMMIT) işlemleri için client alma fonksiyonu
  connect: () => pool.connect(),
  
  // Havuzun kendisi
  pool,
};
