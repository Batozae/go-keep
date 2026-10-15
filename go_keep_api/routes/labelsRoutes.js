const express = require('express');
const labelsController = require('../controllers/labelsController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');
const { labelValidation } = require('../middleware/labelsValidation');

const router = express.Router();

// Semua rute labels dilindungi oleh token JWT
router.use(authMiddleware);

// GET /api/labels - Daftar seluruh label beserta notes_count
router.get('/', labelsController.getLabels);

// POST /api/labels - Buat label baru
router.post('/', labelValidation, validate, labelsController.createLabel);

// PUT /api/labels/:id - Ubah nama label
router.put('/:id', labelValidation, validate, labelsController.updateLabel);

// DELETE /api/labels/:id - Hapus label (cascade ke note_labels)
router.delete('/:id', labelsController.deleteLabel);

module.exports = router;

