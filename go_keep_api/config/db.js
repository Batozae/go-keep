const mysql = require('mysql2/promise');
require('dotenv').config();

// Konfigurasi pool koneksi database MySQL
// Menggunakan pool agar koneksi dapat digunakan kembali secara efisien
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'gokeep',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0
});

// Fungsi pengujian koneksi database saat startup
async function testConnection() {
  try {
    const connection = await pool.getConnection();
    console.log('[DB] Terhubung ke MySQL database:', process.env.DB_NAME || 'gokeep');
    connection.release();
  } catch (error) {
    console.error('[DB Error] Gagal terhubung ke MySQL:', error.message);
  }
}

testConnection();

module.exports = pool;

