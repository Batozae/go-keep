const { body, query } = require('express-validator');

// Daftar warna catatan yang diizinkan sesuai spesifikasi Google Keep clone
const ALLOWED_COLORS = [
  'default', 'red', 'orange', 'yellow', 'green', 'teal',
  'blue', 'purple', 'pink', 'brown', 'gray'
];

// Daftar tipe catatan yang diizinkan
const ALLOWED_TYPES = ['text', 'checklist'];

// Validasi untuk pembuatan catatan baru (POST /notes)
const createNoteValidation = [
  body('type')
    .optional()
    .isIn(ALLOWED_TYPES)
    .withMessage("Tipe catatan hanya boleh 'text' atau 'checklist'."),
  body('color')
    .optional()
    .isIn(ALLOWED_COLORS)
    .withMessage(`Warna tidak valid. Pilihan warna: ${ALLOWED_COLORS.join(', ')}.`),
  body('checklist_items')
    .optional()
    .isArray()
    .withMessage('Item checklist harus berupa array.'),
  body('label_ids')
    .optional()
    .isArray()
    .withMessage('label_ids harus berupa array ID label.'),
  body('label_ids.*')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Setiap ID label dalam label_ids harus berupa bilangan bulat positif.'),
  body().custom((value, { req }) => {
    const title = req.body.title !== undefined ? String(req.body.title).trim() : '';
    const content = req.body.content !== undefined ? String(req.body.content).trim() : '';
    const items = req.body.checklist_items;
    const hasItems = Array.isArray(items) && items.length > 0;

    // Judul dan isi tidak boleh kosong keduanya kecuali memiliki item checklist
    if (!title && !content && !hasItems) {
      throw new Error('Judul dan isi catatan tidak boleh kosong keduanya kecuali memiliki item checklist.');
    }
    return true;
  })
];

// Validasi untuk pembaruan catatan (PUT /notes/:id)
const updateNoteValidation = [
  body('type')
    .optional()
    .isIn(ALLOWED_TYPES)
    .withMessage("Tipe catatan hanya boleh 'text' atau 'checklist'."),
  body('color')
    .optional()
    .isIn(ALLOWED_COLORS)
    .withMessage(`Warna tidak valid. Pilihan warna: ${ALLOWED_COLORS.join(', ')}.`),
  body('checklist_items')
    .optional()
    .isArray()
    .withMessage('Item checklist harus berupa array.'),
  body('label_ids')
    .optional()
    .isArray()
    .withMessage('label_ids harus berupa array ID label.'),
  body('label_ids.*')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Setiap ID label dalam label_ids harus berupa bilangan bulat positif.')
];

// Validasi query parameter untuk daftar catatan (GET /notes)
const getNotesValidation = [
  query('status')
    .optional()
    .isIn(['active', 'archived', 'trash'])
    .withMessage("Parameter status tidak valid. Gunakan 'active', 'archived', atau 'trash'."),
  query('label_id')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Parameter label_id harus berupa bilangan bulat positif.')
];

module.exports = {
  ALLOWED_COLORS,
  ALLOWED_TYPES,
  createNoteValidation,
  updateNoteValidation,
  getNotesValidation
};

