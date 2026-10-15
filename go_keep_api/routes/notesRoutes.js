const express = require('express');
const notesController = require('../controllers/notesController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');
const {
  createNoteValidation,
  updateNoteValidation,
  getNotesValidation
} = require('../middleware/notesValidation');

const router = express.Router();

// Seluruh endpoint notes dilindungi oleh authMiddleware (JWT)
router.use(authMiddleware);

// GET /api/notes?status=active|archived|trash&q=&label_id=
router.get('/', getNotesValidation, validate, notesController.getNotes);

// POST /api/notes
router.post('/', createNoteValidation, validate, notesController.createNote);

// DELETE /api/notes/trash/empty
// PENTING: Dideklarasikan SEBELUM /:id agar kata "trash" tidak terbaca sebagai parameter :id
router.delete('/trash/empty', notesController.emptyTrash);

// GET /api/notes/:id
router.get('/:id', notesController.getNoteById);

// PUT /api/notes/:id
router.put('/:id', updateNoteValidation, validate, notesController.updateNote);

// PATCH /api/notes/:id/pin (toggle pin)
router.patch('/:id/pin', notesController.togglePin);

// PATCH /api/notes/:id/archive (toggle arsip)
router.patch('/:id/archive', notesController.toggleArchive);

// PATCH /api/notes/:id/trash (pindah ke tempat sampah)
router.patch('/:id/trash', notesController.moveToTrash);

// PATCH /api/notes/:id/restore (pulihkan dari tempat sampah)
router.patch('/:id/restore', notesController.restoreFromTrash);

// POST /api/notes/:id/labels/:labelId (tautkan label ke catatan)
router.post('/:id/labels/:labelId', notesController.addLabelToNote);

// DELETE /api/notes/:id/labels/:labelId (lepas label dari catatan)
router.delete('/:id/labels/:labelId', notesController.removeLabelFromNote);

// DELETE /api/notes/:id (hapus permanen jika sudah di tempat sampah)
router.delete('/:id', notesController.deleteNote);

module.exports = router;

