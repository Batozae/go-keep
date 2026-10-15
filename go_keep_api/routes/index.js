const express = require('express');
const authRoutes = require('./authRoutes');
const notesRoutes = require('./notesRoutes');
const labelsRoutes = require('./labelsRoutes');

const router = express.Router();

// Mounting rute auth di /api/auth
router.use('/auth', authRoutes);

// Mounting rute notes di /api/notes
router.use('/notes', notesRoutes);

// Mounting rute labels di /api/labels
router.use('/labels', labelsRoutes);

module.exports = router;
