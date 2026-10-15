const jwt = require('jsonwebtoken');

/**
 * Middleware untuk memvalidasi JWT (JSON Web Token)
 * Memeriksa header Authorization: Bearer <token>
 * Menambahkan data pengguna yang terdekode ke req.user
 */
const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;

  // Cek apakah header Authorization disertakan dan berformat Bearer
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      message: 'Akses ditolak. Token otentikasi tidak ditemukan.'
    });
  }

  const token = authHeader.split(' ')[1];

  try {
    const secret = process.env.JWT_SECRET || 'aplikasi_replika_google_keep';
    const decoded = jwt.verify(token, secret);
    req.user = decoded; // { id, email, ... }
    next();
  } catch (error) {
    return res.status(401).json({
      message: 'Token tidak valid atau telah kedaluwarsa.'
    });
  }
};

module.exports = authMiddleware;

