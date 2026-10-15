require('dotenv').config();
const express = require('express');
const cors = require('cors');
const apiRoutes = require('./routes');
const errorHandler = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware global
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rute dasar untuk cek status server
app.get('/', (req, res) => {
  res.json({
    name: 'Go-Keep API',
    version: '1.0.0',
    status: 'running'
  });
});

// Routing utama API dengan prefix /api
app.use('/api', apiRoutes);

// Handler untuk rute yang tidak ditemukan (404)
app.use((req, res) => {
  res.status(404).json({
    message: 'Endpoint tidak ditemukan.'
  });
});

// Handler error global (500 atau custom error)
app.use(errorHandler);

// Menjalankan server
app.listen(PORT, () => {
  console.log(`[Server] Go-Keep API berjalan di http://localhost:${PORT}`);
  console.log(`[Server] Prefix endpoint API: http://localhost:${PORT}/api`);
});

module.exports = app;

