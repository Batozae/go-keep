const { body } = require('express-validator');

// Validasi input untuk label: nama wajib, di-trim, maksimal 100 karakter
const labelValidation = [
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Nama label wajib diisi.')
    .isLength({ max: 100 })
    .withMessage('Nama label maksimal terdiri dari 100 karakter.')
];

module.exports = {
  labelValidation
};

