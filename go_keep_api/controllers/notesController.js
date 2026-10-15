const pool = require('../config/db');

/**
 * Helper: Mengambil relasi checklist_items dan labels untuk sekumpulan catatan.
 * Mencegah masalah N+1 query dengan mengeksekusi batch query menggunakan operator IN (?).
 */
async function populateNotesRelations(notes, db = pool) {
  if (!notes || notes.length === 0) return [];

  const noteIds = notes.map(n => n.id);

  // 1. Ambil seluruh checklist items untuk seluruh catatan dalam daftar (1 query)
  const [items] = await db.query(
    'SELECT id, note_id, text, is_checked, position FROM checklist_items WHERE note_id IN (?) ORDER BY position ASC, id ASC',
    [noteIds]
  );

  // 2. Ambil seluruh labels untuk seluruh catatan dalam daftar (1 query)
  const [labels] = await db.query(
    `SELECT nl.note_id, l.id, l.name
     FROM note_labels nl
     JOIN labels l ON nl.label_id = l.id
     WHERE nl.note_id IN (?)
     ORDER BY l.name ASC`,
    [noteIds]
  );

  // Petakan checklist items ke masing-masing note_id
  const checklistMap = {};
  for (const item of items) {
    if (!checklistMap[item.note_id]) {
      checklistMap[item.note_id] = [];
    }
    checklistMap[item.note_id].push({
      id: item.id,
      note_id: item.note_id,
      text: item.text,
      is_checked: Boolean(item.is_checked),
      position: item.position
    });
  }

  // Petakan labels ke masing-masing note_id
  const labelsMap = {};
  for (const label of labels) {
    if (!labelsMap[label.note_id]) {
      labelsMap[label.note_id] = [];
    }
    labelsMap[label.note_id].push({
      id: label.id,
      name: label.name
    });
  }

  // Gabungkan ke objek catatan
  return notes.map(note => ({
    id: note.id,
    user_id: note.user_id,
    title: note.title,
    content: note.content,
    type: note.type,
    color: note.color,
    is_pinned: Boolean(note.is_pinned),
    is_archived: Boolean(note.is_archived),
    deleted_at: note.deleted_at,
    created_at: note.created_at,
    updated_at: note.updated_at,
    checklist_items: checklistMap[note.id] || [],
    labels: labelsMap[note.id] || []
  }));
}

/**
 * Helper: Mengambil satu catatan lengkap beserta checklist_items dan labels.
 */
async function getSingleNoteWithRelations(noteId, userId, db = pool) {
  const [notes] = await db.execute(
    'SELECT id, user_id, title, content, type, color, is_pinned, is_archived, deleted_at, created_at, updated_at FROM notes WHERE id = ? AND user_id = ? LIMIT 1',
    [noteId, userId]
  );
  if (notes.length === 0) return null;
  const populated = await populateNotesRelations(notes, db);
  return populated[0];
}

// GET /api/notes - Mendapatkan daftar catatan milik pengguna terotentikasi
const getNotes = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const status = req.query.status || 'active';
    const q = req.query.q ? req.query.q.trim() : '';
    const labelId = req.query.label_id ? parseInt(req.query.label_id, 10) : null;

    // Filter status:
    // - active:   is_archived = 0 AND deleted_at IS NULL
    // - archived: is_archived = 1 AND deleted_at IS NULL
    // - trash:    deleted_at IS NOT NULL
    let sql = `
      SELECT id, user_id, title, content, type, color, is_pinned, is_archived, deleted_at, created_at, updated_at
      FROM notes
      WHERE user_id = ?
    `;
    const params = [userId];

    if (status === 'active') {
      sql += ' AND is_archived = 0 AND deleted_at IS NULL';
    } else if (status === 'archived') {
      sql += ' AND is_archived = 1 AND deleted_at IS NULL';
    } else if (status === 'trash') {
      sql += ' AND deleted_at IS NOT NULL';
    }

    // Pencarian q berparameter pada title, content, dan teks checklist_items
    if (q) {
      sql += ` AND (
        title LIKE ? 
        OR content LIKE ? 
        OR id IN (SELECT note_id FROM checklist_items WHERE text LIKE ?)
      )`;
      const searchKeyword = `%${q}%`;
      params.push(searchKeyword, searchKeyword, searchKeyword);
    }

    // Filter opsional berdasarkan label_id jika disertakan
    if (labelId) {
      // Verifikasi bahwa label milik pengguna; jika bukan, kembalikan 404
      const [labelRows] = await pool.execute(
        'SELECT id FROM labels WHERE id = ? AND user_id = ? LIMIT 1',
        [labelId, userId]
      );
      if (labelRows.length === 0) {
        return res.status(404).json({ message: 'Label tidak ditemukan.' });
      }

      sql += ' AND id IN (SELECT note_id FROM note_labels WHERE label_id = ?)';
      params.push(labelId);
    }

    // Urutan: is_pinned DESC, lalu updated_at DESC
    sql += ' ORDER BY is_pinned DESC, updated_at DESC';

    const [notes] = await pool.execute(sql, params);
    const result = await populateNotesRelations(notes, pool);

    return res.status(200).json(result);
  } catch (error) {
    next(error);
  }
};

// GET /api/notes/:id - Mendapatkan detail satu catatan
const getNoteById = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;

    const note = await getSingleNoteWithRelations(noteId, userId, pool);
    if (!note) {
      return res.status(404).json({ message: 'Catatan tidak ditemukan.' });
    }

    return res.status(200).json(note);
  } catch (error) {
    next(error);
  }
};

// POST /api/notes - Membuat catatan baru dengan transaksi DB
const createNote = async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const userId = req.user.id;
    const {
      title = '',
      content = '',
      type,
      color = 'default',
      is_pinned = false,
      is_archived = false,
      checklist_items,
      label_ids
    } = req.body;

    await conn.beginTransaction();

    // Tentukan tipe catatan secara otomatis jika tidak ditentukan
    const resolvedType = type || (Array.isArray(checklist_items) && checklist_items.length > 0 ? 'checklist' : 'text');
    // Jika catatan diarsipkan, status pin otomatis dilepas
    const pinValue = is_archived ? 0 : (is_pinned ? 1 : 0);
    const archiveValue = is_archived ? 1 : 0;

    // Simpan data catatan utama
    const [insertResult] = await conn.execute(
      'INSERT INTO notes (user_id, title, content, type, color, is_pinned, is_archived) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [userId, title, content, resolvedType, color, pinValue, archiveValue]
    );
    const newNoteId = insertResult.insertId;

    // Simpan item checklist jika ada
    if (Array.isArray(checklist_items) && checklist_items.length > 0) {
      for (let i = 0; i < checklist_items.length; i++) {
        const item = checklist_items[i];
        const text = typeof item === 'string' ? item : (item.text || '');
        const isChecked = typeof item === 'object' && item.is_checked ? 1 : 0;
        const position = typeof item === 'object' && typeof item.position === 'number' ? item.position : i;

        await conn.execute(
          'INSERT INTO checklist_items (note_id, text, is_checked, position) VALUES (?, ?, ?, ?)',
          [newNoteId, text, isChecked, position]
        );
      }
    }

    // Hubungkan label jika ada (validasi seluruh ID harus milik pengguna)
    if (Array.isArray(label_ids) && label_ids.length > 0) {
      const [userLabels] = await conn.query(
        'SELECT id FROM labels WHERE user_id = ? AND id IN (?)',
        [userId, label_ids]
      );
      if (userLabels.length !== new Set(label_ids).size) {
        await conn.rollback();
        return res.status(404).json({
          message: 'Satu atau lebih label tidak ditemukan.'
        });
      }

      for (const lId of label_ids) {
        await conn.execute('INSERT IGNORE INTO note_labels (note_id, label_id) VALUES (?, ?)', [newNoteId, lId]);
      }
    }

    await conn.commit();

    const createdNote = await getSingleNoteWithRelations(newNoteId, userId, pool);
    return res.status(201).json(createdNote);
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
};

// PUT /api/notes/:id - Memperbarui catatan dan mengganti seluruh item checklist
const updateNote = async (req, res, next) => {
  const conn = await pool.getConnection();
  try {
    const userId = req.user.id;
    const noteId = req.params.id;
    const {
      title,
      content,
      type,
      color,
      is_pinned,
      is_archived,
      checklist_items,
      label_ids
    } = req.body;

    // Cek keberadaan catatan dan kepemilikan user
    const [existingNotes] = await pool.execute(
      'SELECT * FROM notes WHERE id = ? AND user_id = ? LIMIT 1',
      [noteId, userId]
    );

    if (existingNotes.length === 0) {
      return res.status(404).json({ message: 'Catatan tidak ditemukan.' });
    }

    const existingNote = existingNotes[0];
    if (existingNote.deleted_at !== null) {
      return res.status(400).json({ message: 'Catatan di tempat sampah tidak dapat diubah.' });
    }

    // Validasi konten: judul & isi tidak boleh keduanya kosong kecuali ada item checklist
    const finalTitle = title !== undefined ? String(title).trim() : existingNote.title.trim();
    const finalContent = content !== undefined ? String(content).trim() : (existingNote.content ? existingNote.content.trim() : '');

    let hasChecklistItems = false;
    if (checklist_items !== undefined) {
      hasChecklistItems = Array.isArray(checklist_items) && checklist_items.length > 0;
    } else {
      const [existingItems] = await pool.execute('SELECT id FROM checklist_items WHERE note_id = ? LIMIT 1', [noteId]);
      hasChecklistItems = existingItems.length > 0;
    }

    if (!finalTitle && !finalContent && !hasChecklistItems) {
      return res.status(400).json({
        message: 'Judul dan isi catatan tidak boleh kosong keduanya kecuali memiliki item checklist.'
      });
    }

    await conn.beginTransaction();

    const updatedTitle = title !== undefined ? title : existingNote.title;
    const updatedContent = content !== undefined ? content : existingNote.content;
    const updatedType = type !== undefined ? type : existingNote.type;
    const updatedColor = color !== undefined ? color : existingNote.color;

    let updatedPinned = existingNote.is_pinned;
    let updatedArchived = existingNote.is_archived;

    if (is_archived !== undefined) {
      updatedArchived = is_archived ? 1 : 0;
      if (updatedArchived === 1) updatedPinned = 0; // Arsip otomatis melepas pin
    }
    if (is_pinned !== undefined && !updatedArchived) {
      updatedPinned = is_pinned ? 1 : 0;
    }

    // Perbarui catatan dan updated_at
    await conn.execute(
      'UPDATE notes SET title = ?, content = ?, type = ?, color = ?, is_pinned = ?, is_archived = ?, updated_at = NOW() WHERE id = ? AND user_id = ?',
      [updatedTitle, updatedContent, updatedType, updatedColor, updatedPinned, updatedArchived, noteId, userId]
    );

    // Ganti seluruh checklist items jika diberikan
    if (checklist_items !== undefined && Array.isArray(checklist_items)) {
      await conn.execute('DELETE FROM checklist_items WHERE note_id = ?', [noteId]);
      for (let i = 0; i < checklist_items.length; i++) {
        const item = checklist_items[i];
        const text = typeof item === 'string' ? item : (item.text || '');
        const isChecked = typeof item === 'object' && item.is_checked ? 1 : 0;
        const position = typeof item === 'object' && typeof item.position === 'number' ? item.position : i;

        await conn.execute(
          'INSERT INTO checklist_items (note_id, text, is_checked, position) VALUES (?, ?, ?, ?)',
          [noteId, text, isChecked, position]
        );
      }
    }

    // Perbarui label jika field label_ids disertakan
    if (label_ids !== undefined && Array.isArray(label_ids)) {
      if (label_ids.length > 0) {
        const [userLabels] = await conn.query(
          'SELECT id FROM labels WHERE user_id = ? AND id IN (?)',
          [userId, label_ids]
        );
        if (userLabels.length !== new Set(label_ids).size) {
          await conn.rollback();
          return res.status(404).json({
            message: 'Satu atau lebih label tidak ditemukan.'
          });
        }
      }

      await conn.execute('DELETE FROM note_labels WHERE note_id = ?', [noteId]);
      for (const lId of label_ids) {
        await conn.execute('INSERT IGNORE INTO note_labels (note_id, label_id) VALUES (?, ?)', [noteId, lId]);
      }
    }

    await conn.commit();

    const updatedNote = await getSingleNoteWithRelations(noteId, userId, pool);
    return res.status(200).json(updatedNote);
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
};

// PATCH /api/notes/:id/pin - Toggle pin status
const togglePin = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;

    const [notes] = await pool.execute('SELECT * FROM notes WHERE id = ? AND user_id = ? LIMIT 1', [noteId, userId]);
    if (notes.length === 0) {
      return res.status(404).json({ message: 'Catatan tidak ditemukan.' });
    }

    const note = notes[0];
    if (note.deleted_at !== null) {
      return res.status(400).json({ message: 'Catatan di tempat sampah tidak dapat disematkan.' });
    }

    const newPinned = note.is_pinned ? 0 : 1;
    // Jika disematkan, batalkan status arsip jika sebelumnya berstatus arsip
    const newArchived = newPinned === 1 ? 0 : note.is_archived;

    await pool.execute(
      'UPDATE notes SET is_pinned = ?, is_archived = ?, updated_at = NOW() WHERE id = ? AND user_id = ?',
      [newPinned, newArchived, noteId, userId]
    );

    const updated = await getSingleNoteWithRelations(noteId, userId, pool);
    return res.status(200).json(updated);
  } catch (error) {
    next(error);
  }
};

// PATCH /api/notes/:id/archive - Toggle archive status (arsip otomatis melepas pin)
const toggleArchive = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;

    const [notes] = await pool.execute('SELECT * FROM notes WHERE id = ? AND user_id = ? LIMIT 1', [noteId, userId]);
    if (notes.length === 0) {
      return res.status(404).json({ message: 'Catatan tidak ditemukan.' });
    }

    const note = notes[0];
    if (note.deleted_at !== null) {
      return res.status(400).json({ message: 'Catatan di tempat sampah tidak dapat diarsipkan.' });
    }

    const newArchived = note.is_archived ? 0 : 1;
    // Jika diarsipkan, pin otomatis dilepas
    const newPinned = newArchived === 1 ? 0 : note.is_pinned;

    await pool.execute(
      'UPDATE notes SET is_archived = ?, is_pinned = ?, updated_at = NOW() WHERE id = ? AND user_id = ?',
      [newArchived, newPinned, noteId, userId]
    );

    const updated = await getSingleNoteWithRelations(noteId, userId, pool);
    return res.status(200).json(updated);
  } catch (error) {
    next(error);
  }
};

// PATCH /api/notes/:id/trash - Pindahkan catatan ke tempat sampah (melepas pin dan arsip)
const moveToTrash = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;

    const [notes] = await pool.execute('SELECT * FROM notes WHERE id = ? AND user_id = ? LIMIT 1', [noteId, userId]);
    if (notes.length === 0) {
      return res.status(404).json({ message: 'Catatan tidak ditemukan.' });
    }

    // Memindahkan ke sampah melepas pin dan arsip
    await pool.execute(
      'UPDATE notes SET deleted_at = NOW(), is_pinned = 0, is_archived = 0, updated_at = NOW() WHERE id = ? AND user_id = ?',
      [noteId, userId]
    );

    const updated = await getSingleNoteWithRelations(noteId, userId, pool);
    return res.status(200).json(updated);
  } catch (error) {
    next(error);
  }
};

// PATCH /api/notes/:id/restore - Mengembalikan catatan dari tempat sampah ke status aktif
const restoreFromTrash = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;

    const [notes] = await pool.execute('SELECT * FROM notes WHERE id = ? AND user_id = ? LIMIT 1', [noteId, userId]);
    if (notes.length === 0) {
      return res.status(404).json({ message: 'Catatan tidak ditemukan.' });
    }

    const note = notes[0];
    if (note.deleted_at === null) {
      return res.status(400).json({ message: 'Catatan tidak berada di tempat sampah.' });
    }

    // Mengembalikan ke status aktif (deleted_at = NULL, is_pinned = 0, is_archived = 0)
    await pool.execute(
      'UPDATE notes SET deleted_at = NULL, is_pinned = 0, is_archived = 0, updated_at = NOW() WHERE id = ? AND user_id = ?',
      [noteId, userId]
    );

    const updated = await getSingleNoteWithRelations(noteId, userId, pool);
    return res.status(200).json(updated);
  } catch (error) {
    next(error);
  }
};

// DELETE /api/notes/trash/empty - Menghapus permanen seluruh catatan di tempat sampah milik pengguna
const emptyTrash = async (req, res, next) => {
  try {
    const userId = req.user.id;

    await pool.execute(
      'DELETE FROM notes WHERE user_id = ? AND deleted_at IS NOT NULL',
      [userId]
    );

    return res.status(200).json({
      message: 'Semua catatan di tempat sampah berhasil dihapus.'
    });
  } catch (error) {
    next(error);
  }
};

// DELETE /api/notes/:id - Menghapus catatan permanen (hanya jika sudah di tempat sampah)
const deleteNote = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;

    const [notes] = await pool.execute(
      'SELECT id, deleted_at FROM notes WHERE id = ? AND user_id = ? LIMIT 1',
      [noteId, userId]
    );

    if (notes.length === 0) {
      return res.status(404).json({ message: 'Catatan tidak ditemukan.' });
    }

    const note = notes[0];

    // Hapus permanen hanya diizinkan jika catatan sudah di tempat sampah
    if (note.deleted_at === null) {
      return res.status(400).json({
        message: 'Catatan harus dipindahkan ke tempat sampah terlebih dahulu sebelum dihapus permanen.'
      });
    }

    await pool.execute('DELETE FROM notes WHERE id = ? AND user_id = ?', [noteId, userId]);

    return res.status(200).json({
      message: 'Catatan berhasil dihapus secara permanen.'
    });
  } catch (error) {
    next(error);
  }
};

// POST /api/notes/:id/labels/:labelId - Menautkan label ke catatan (idempoten)
const addLabelToNote = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;
    const labelId = req.params.labelId;

    // 1. Verifikasi catatan milik user
    const [notes] = await pool.execute(
      'SELECT id, deleted_at FROM notes WHERE id = ? AND user_id = ? LIMIT 1',
      [noteId, userId]
    );
    if (notes.length === 0) {
      return res.status(404).json({ message: 'Catatan tidak ditemukan.' });
    }

    if (notes[0].deleted_at !== null) {
      return res.status(400).json({ message: 'Catatan di tempat sampah tidak dapat diubah.' });
    }

    // 2. Verifikasi label milik user
    const [labels] = await pool.execute(
      'SELECT id FROM labels WHERE id = ? AND user_id = ? LIMIT 1',
      [labelId, userId]
    );
    if (labels.length === 0) {
      return res.status(404).json({ message: 'Label tidak ditemukan.' });
    }

    // 3. Tautkan label secara idempoten
    await pool.execute(
      'INSERT IGNORE INTO note_labels (note_id, label_id) VALUES (?, ?)',
      [noteId, labelId]
    );

    // Perbarui updated_at pada catatan
    await pool.execute('UPDATE notes SET updated_at = NOW() WHERE id = ?', [noteId]);

    const updatedNote = await getSingleNoteWithRelations(noteId, userId, pool);
    return res.status(200).json(updatedNote);
  } catch (error) {
    next(error);
  }
};

// DELETE /api/notes/:id/labels/:labelId - Melepas label dari catatan (idempoten)
const removeLabelFromNote = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const noteId = req.params.id;
    const labelId = req.params.labelId;

    // 1. Verifikasi catatan milik user
    const [notes] = await pool.execute(
      'SELECT id FROM notes WHERE id = ? AND user_id = ? LIMIT 1',
      [noteId, userId]
    );
    if (notes.length === 0) {
      return res.status(404).json({ message: 'Catatan tidak ditemukan.' });
    }

    // 2. Verifikasi label milik user
    const [labels] = await pool.execute(
      'SELECT id FROM labels WHERE id = ? AND user_id = ? LIMIT 1',
      [labelId, userId]
    );
    if (labels.length === 0) {
      return res.status(404).json({ message: 'Label tidak ditemukan.' });
    }

    // 3. Lepas tautan label secara idempoten
    await pool.execute(
      'DELETE FROM note_labels WHERE note_id = ? AND label_id = ?',
      [noteId, labelId]
    );

    // Perbarui updated_at pada catatan
    await pool.execute('UPDATE notes SET updated_at = NOW() WHERE id = ?', [noteId]);

    const updatedNote = await getSingleNoteWithRelations(noteId, userId, pool);
    return res.status(200).json(updatedNote);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getNotes,
  getNoteById,
  createNote,
  updateNote,
  togglePin,
  toggleArchive,
  moveToTrash,
  restoreFromTrash,
  emptyTrash,
  deleteNote,
  addLabelToNote,
  removeLabelFromNote
};

