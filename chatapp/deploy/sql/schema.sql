-- Ajetaan jokaisessa deployssa; IF NOT EXISTS tekee siitä turvallisen toistaa.
CREATE TABLE IF NOT EXISTS messages (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    session_id  VARCHAR(64) NOT NULL,
    role        ENUM('user', 'assistant') NOT NULL,
    content     MEDIUMTEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_session (session_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;