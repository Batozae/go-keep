const express = require('express');
const authRoutes = require('./authRoutes');

const router = express.Router();

// Mounting rute auth di /api/auth
router.use('/auth', authRoutes);

module.exports = router;

