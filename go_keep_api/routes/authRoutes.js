const express = require('express');
const { body } = require('express-validator');
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');

const router = express.Router();

// Validasi input untuk registrasi pengguna
const registerValidation = [
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Nama wajib diisi.'),
  body('email')
    .trim()
    .isEmail()
    .withMessage('Format email tidak valid.')
    .normalizeEmail(),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Password minimal terdiri dari 6 karakter.')
];

// Validasi input untuk login pengguna
const loginValidation = [
  body('email')
    .trim()
    .isEmail()
    .withMessage('Format email tidak valid.')
    .normalizeEmail(),
  body('password')
    .notEmpty()
    .withMessage('Password wajib diisi.')
];

// Rute Autentikasi
// POST /api/auth/register
router.post('/register', registerValidation, validate, authController.register);

// POST /api/auth/login
router.post('/login', loginValidation, validate, authController.login);

// GET /api/auth/me (Memerlukan token JWT)
router.get('/me', authMiddleware, authController.getMe);

module.exports = router;

