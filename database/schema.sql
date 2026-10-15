-- ============================================================================
-- Skema Database: Go-Keep (Klon Google Keep)
-- Charset: utf8mb4, Collation: utf8mb4_unicode_ci, Engine: InnoDB
-- ============================================================================

CREATE DATABASE IF NOT EXISTS gokeep CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gokeep;

-- Nonaktifkan pengecekan foreign key sementara saat reset tabel
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS note_labels;
DROP TABLE IF EXISTS checklist_items;
DROP TABLE IF EXISTS notes;
DROP TABLE IF EXISTS labels;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------------------
-- Tabel: users
-- Menyimpan informasi kredensial akun pengguna
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Tabel: notes
-- Menyimpan data catatan teks dan checklist
-- Status catatan ditentukan oleh kolom:
--   - Aktif:   is_archived = 0 AND deleted_at IS NULL
--   - Arsip:   is_archived = 1 AND deleted_at IS NULL
--   - Sampah:  deleted_at IS NOT NULL
-- ----------------------------------------------------------------------------
CREATE TABLE notes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(255) NOT NULL DEFAULT '',
    content TEXT NULL,
    type ENUM('text', 'checklist') NOT NULL DEFAULT 'text',
    color VARCHAR(20) NOT NULL DEFAULT 'default',
    is_pinned TINYINT(1) NOT NULL DEFAULT 0,
    is_archived TINYINT(1) NOT NULL DEFAULT 0,
    deleted_at DATETIME NULL DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_notes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Tabel: checklist_items
-- Item daftar tugas / to-do untuk catatan bertipe 'checklist'
-- ----------------------------------------------------------------------------
CREATE TABLE checklist_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    note_id INT NOT NULL,
    text TEXT NOT NULL,
    is_checked TINYINT(1) NOT NULL DEFAULT 0,
    position INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_checklist_note FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Tabel: labels
-- Label / tag kategori yang dibuat pengguna (unik per user)
-- ----------------------------------------------------------------------------
CREATE TABLE labels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT fk_labels_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT uq_user_label UNIQUE (user_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Tabel: note_labels
-- Relasi many-to-many antara catatan dan label
-- ----------------------------------------------------------------------------
CREATE TABLE note_labels (
    note_id INT NOT NULL,
    label_id INT NOT NULL,
    PRIMARY KEY (note_id, label_id),
    CONSTRAINT fk_note_labels_note FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
    CONSTRAINT fk_note_labels_label FOREIGN KEY (label_id) REFERENCES labels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Data Seed Contoh
-- Password demo: password123 (bcrypt hash)
-- ============================================================================

-- 1. Pengguna demo
INSERT INTO users (id, name, email, password_hash, created_at) VALUES
(1, 'User Demo', 'demo@gokeep.com', '$2b$10$0Zb5rs.IJUmg0Zt/fztJiu0rboPRUHQJ1RmJ1EvUtcojpJmbw8uq6', NOW());

-- 2. Label demo
INSERT INTO labels (id, user_id, name) VALUES
(1, 1, 'Pribadi'),
(2, 1, 'Pekerjaan');

-- 3. Catatan demo (berbagai warna dan status)
INSERT INTO notes (id, user_id, title, content, type, color, is_pinned, is_archived, deleted_at, created_at, updated_at) VALUES
(1, 1, 'Rencana Belajar Flutter & Express', 'Pelajari Provider dan Dio di Flutter serta Express REST API untuk Go-Keep.', 'text', 'default', 1, 0, NULL, NOW(), NOW()),
(2, 1, 'Ide Fitur Go-Keep', 'Desain kartu bergaya Material Design dengan grid masonry menyerupai Google Keep.', 'text', 'red', 0, 0, NULL, NOW(), NOW()),
(3, 1, 'Belanja Mingguan', '', 'checklist', 'yellow', 0, 0, NULL, NOW(), NOW()),
(4, 1, 'Catatan Arsip Proyek', 'Dokumentasi sprint sebelumnya yang sudah selesai dikerjakan.', 'text', 'blue', 0, 1, NULL, NOW(), NOW()),
(5, 1, 'Catatan di Tempat Sampah', 'Catatan ini berada di sampah dan dapat dikembalikan (restore).', 'text', 'default', 0, 0, NOW(), NOW(), NOW());

-- 4. Item checklist untuk catatan Belanja Mingguan (note_id = 3)
INSERT INTO checklist_items (id, note_id, text, is_checked, position) VALUES
(1, 3, 'Susu UHT 1 Liter', 1, 0),
(2, 3, 'Roti Gandum Utuh', 0, 1),
(3, 3, 'Kopi Bubuk Espresso', 0, 2);

-- 5. Relasi label pada catatan
INSERT INTO note_labels (note_id, label_id) VALUES
(1, 1), -- Rencana Belajar -> Pribadi
(2, 2); -- Ide Fitur -> Pekerjaan
