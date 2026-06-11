-- Media arşiv tablosu
CREATE TABLE IF NOT EXISTS media (
  media_id VARCHAR(50) PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  filename VARCHAR(255) NOT NULL,
  url TEXT NOT NULL,
  type VARCHAR(20) NOT NULL DEFAULT 'image',
  is_favorite BOOLEAN DEFAULT false,
  prompt TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Var olan tabloya prompt kolonu ekle (AI üretimlerinde kullanılan prompt saklanır)
ALTER TABLE media ADD COLUMN IF NOT EXISTS prompt TEXT;

CREATE INDEX IF NOT EXISTS idx_media_user_id ON media(user_id);
CREATE INDEX IF NOT EXISTS idx_media_created_at ON media(created_at DESC);
