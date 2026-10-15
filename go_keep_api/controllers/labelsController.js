const pool = require('../config/db');

/**
 * Controller Labels
 * Mengelola pembuatan, pembacaan, pengubahan nama, dan penghapusan label kategori.
 * Seluruh operasi memfilter berdasarkan user_id dari JWT.
 */

// GET /api/labels - Mendapatkan seluruh label milik pengguna beserta jumlah catatan aktif (notes_count)
const getLabels = async (req, res, next) => {
  try {
    const userId = req.user.id;

    // notes_count hanya menghitung catatan AKTIF (is_archived = 0 AND deleted_at IS NULL)
    // Diurutkan berdasarkan nama label (l.name ASC)
    const [rows] = await pool.execute(
      `SELECT l.id, l.name, COUNT(n.id) AS notes_count
       FROM labels l
       LEFT JOIN note_labels nl ON l.id = nl.label_id
       LEFT JOIN notes n ON nl.note_id = n.id AND n.is_archived = 0 AND n.deleted_at IS NULL
       WHERE l.user_id = ?
       GROUP BY l.id, l.name
       ORDER BY l.name ASC`,
      [userId]
    );

    const labels = rows.map(row => ({
      id: row.id,
      name: row.name,
      notes_count: parseInt(row.notes_count, 10) || 0
    }));

    return res.status(200).json(labels);
  } catch (error) {
    next(error);
  }
};

// POST /api/labels - Membuat label baru
const createLabel = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const trimmedName = req.body.name.trim();

    // Cek duplikasi (user_id, name)
    // Kolasi database utf8mb4_unicode_ci bersifat case-insensitive ('Kerja' == 'kerja')
    const [existing] = await pool.execute(
      'SELECT id FROM labels WHERE user_id = ? AND name = ? LIMIT 1',
      [userId, trimmedName]
    );

    if (existing.length > 0) {
      return res.status(409).json({
        message: 'Label dengan nama tersebut sudah ada.'
      });
    }

    const [result] = await pool.execute(
      'INSERT INTO labels (user_id, name) VALUES (?, ?)',
      [userId, trimmedName]
    );

    return res.status(201).json({
      id: result.insertId,
      name: trimmedName,
      notes_count: 0
    });
  } catch (error) {
    // Tangani kemungkinan error duplikat dari constraint DB (ER_DUP_ENTRY)
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        message: 'Label dengan nama tersebut sudah ada.'
      });
    }
    next(error);
  }
};

// PUT /api/labels/:id - Mengubah nama (rename) label
const updateLabel = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const labelId = req.params.id;
    const trimmedName = req.body.name.trim();

    // Verifikasi kepemilikan label (kembalikan 404 jika bukan milik user)
    const [existing] = await pool.execute(
      'SELECT id, name FROM labels WHERE id = ? AND user_id = ? LIMIT 1',
      [labelId, userId]
    );

    if (existing.length === 0) {
      return res.status(404).json({
        message: 'Label tidak ditemukan.'
      });
    }

    // Cek duplikasi nama dengan label lain milik pengguna yang sama (id != labelId)
    const [duplicates] = await pool.execute(
      'SELECT id FROM labels WHERE user_id = ? AND name = ? AND id != ? LIMIT 1',
      [userId, trimmedName, labelId]
    );

    if (duplicates.length > 0) {
      return res.status(409).json({
        message: 'Label dengan nama tersebut sudah ada.'
      });
    }

    await pool.execute(
      'UPDATE labels SET name = ? WHERE id = ? AND user_id = ?',
      [trimmedName, labelId, userId]
    );

    // Ambil data label terbaru beserta notes_count
    const [rows] = await pool.execute(
      `SELECT l.id, l.name, COUNT(n.id) AS notes_count
       FROM labels l
       LEFT JOIN note_labels nl ON l.id = nl.label_id
       LEFT JOIN notes n ON nl.note_id = n.id AND n.is_archived = 0 AND n.deleted_at IS NULL
       WHERE l.id = ? AND l.user_id = ?
       GROUP BY l.id, l.name`,
      [labelId, userId]
    );

    return res.status(200).json({
      id: rows[0].id,
      name: rows[0].name,
      notes_count: parseInt(rows[0].notes_count, 10) || 0
    });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        message: 'Label dengan nama tersebut sudah ada.'
      });
    }
    next(error);
  }
};

// DELETE /api/labels/:id - Menghapus label (relasi note_labels otomatis terhapus via CASCADE, catatan tidak terhapus)
const deleteLabel = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const labelId = req.params.id;

    // Verifikasi kepemilikan label
    const [existing] = await pool.execute(
      'SELECT id FROM labels WHERE id = ? AND user_id = ? LIMIT 1',
      [labelId, userId]
    );

    if (existing.length === 0) {
      return res.status(404).json({
        message: 'Label tidak ditemukan.'
      });
    }

    // Hapus label; relasi di note_labels akan terhapus otomatis oleh foreign key ON DELETE CASCADE
    await pool.execute(
      'DELETE FROM labels WHERE id = ? AND user_id = ?',
      [labelId, userId]
    );

    return res.status(200).json({
      message: 'Label berhasil dihapus.'
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getLabels,
  createLabel,
  updateLabel,
  deleteLabel
};

