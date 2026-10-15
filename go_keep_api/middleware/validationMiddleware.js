const { validationResult } = require('express-validator');

/**
 * Middleware untuk mengecek hasil validasi express-validator.
 * Mengembalikan format error konsisten: { "message": "..." } dengan status 400.
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    // Ambil pesan error pertama untuk ditampilkan ke klien
    return res.status(400).json({
      message: errors.array()[0].msg
    });
  }
  next();
};

module.exports = validate;

