const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

/**
 * Controller Autentikasi Pengguna
 * Mengelola proses registrasi, login, dan pengambilan profil pengguna terotentikasi.
 */

// POST /api/auth/register - Registrasi pengguna baru
const register = async (req, res, next) => {
  try {
    const { name, email, password } = req.body;

    // 1. Cek apakah email sudah terdaftar menggunakan prepared statement
    const [existingUsers] = await pool.execute(
      'SELECT id FROM users WHERE email = ? LIMIT 1',
      [email]
    );

    if (existingUsers.length > 0) {
      return res.status(409).json({
        message: 'Email sudah terdaftar.'
      });
    }

    // 2. Hash password menggunakan bcryptjs (salt rounds = 10)
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // 3. Simpan pengguna baru ke database dengan query berparameter
    const [insertResult] = await pool.execute(
      'INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)',
      [name, email, passwordHash]
    );

    const userId = insertResult.insertId;

    // 4. Generate token JWT untuk sesi pengguna
    const secret = process.env.JWT_SECRET || 'aplikasi_replika_google_keep';
    const token = jwt.sign(
      { id: userId, email },
      secret,
      { expiresIn: '7d' }
    );

    // Ambil data user yang baru dibuat
    const [newUsers] = await pool.execute(
      'SELECT id, name, email, created_at FROM users WHERE id = ?',
      [userId]
    );

    return res.status(201).json({
      message: 'Registrasi berhasil.',
      token,
      user: newUsers[0]
    });
  } catch (error) {
    next(error);
  }
};

// POST /api/auth/login - Login pengguna dan menghasilkan token JWT
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // 1. Cari pengguna berdasarkan email dengan prepared statement
    const [users] = await pool.execute(
      'SELECT id, name, email, password_hash, created_at FROM users WHERE email = ? LIMIT 1',
      [email]
    );

    if (users.length === 0) {
      return res.status(401).json({
        message: 'Email atau password salah.'
      });
    }

    const user = users[0];

    // 2. Verifikasi kesesuaian password dengan hash di database
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({
        message: 'Email atau password salah.'
      });
    }

    // 3. Buat JSON Web Token (JWT)
    const secret = process.env.JWT_SECRET || 'aplikasi_replika_google_keep';
    const token = jwt.sign(
      { id: user.id, email: user.email },
      secret,
      { expiresIn: '7d' }
    );

    // 4. Kembalikan token dan objek user (tanpa password_hash)
    return res.status(200).json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        created_at: user.created_at
      }
    });
  } catch (error) {
    next(error);
  }
};

// GET /api/auth/me - Mendapatkan profil pengguna yang sedang login
const getMe = async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Query informasi pengguna terotentikasi berdasarkan id dari JWT
    const [users] = await pool.execute(
      'SELECT id, name, email, created_at FROM users WHERE id = ? LIMIT 1',
      [userId]
    );

    if (users.length === 0) {
      return res.status(404).json({
        message: 'Pengguna tidak ditemukan.'
      });
    }

    return res.status(200).json({
      user: users[0]
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  getMe
};

