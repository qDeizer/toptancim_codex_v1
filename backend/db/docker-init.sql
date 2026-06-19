-- Docker-uyumlu veritabanı başlatma betiği
-- Orijinal init.sql dosyasından \gexec ve \c komutları kaldırılmıştır.
-- Veritabanı, docker-compose.yml'deki POSTGRES_DB env değişkeniyle oluşturulur.

-- 'users' tablosunu, belirtilen veri modeline uygun olarak oluşturur.
CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    user_name TEXT UNIQUE NOT NULL,
    isletme_ismi TEXT NOT NULL,
    ad TEXT NOT NULL,
    soyad TEXT NOT NULL,
    tel_no TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    hakkinda TEXT,
    profil_fotografi TEXT,
    password_hash TEXT NOT NULL,
    toptanci_uyelik BOOLEAN DEFAULT FALSE,
    role TEXT DEFAULT 'user',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Kullanıcı hesap hareketleri tablosu
CREATE TABLE IF NOT EXISTS account_movements (
    movement_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE UNIQUE,
    creation_date TIMESTAMPTZ NOT NULL,
    last_login TIMESTAMPTZ,
    last_failed_login TIMESTAMPTZ,
    last_update TIMESTAMPTZ NOT NULL,
    login_count INTEGER DEFAULT 0,
    failed_login_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Kullanıcı adres bilgileri tablosu
CREATE TABLE IF NOT EXISTS address_info (
    address_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE UNIQUE,
    address_title TEXT,
    address TEXT,
    detailed_address TEXT,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7)
);

-- Harici (uygulamayı kullanmayan) kullanıcıları saklamak için tablo
CREATE TABLE IF NOT EXISTS external_users (
    external_user_id TEXT PRIMARY KEY,
    creator_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    isletme_ismi TEXT,
    ad TEXT,
    soyad TEXT,
    tel_no TEXT,
    email TEXT,
    adres TEXT,
    profil_fotografi TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Kullanıcılar arası ilişkileri (müşteri/toptancı) saklamak için tablo
CREATE TABLE IF NOT EXISTS relations (
    relation_id TEXT PRIMARY KEY,
    wholesaler_id TEXT NOT NULL,
    customer_id TEXT NOT NULL,
    is_wholesaler_internal BOOLEAN NOT NULL,
    is_customer_internal BOOLEAN NOT NULL,
    relation_start_date TIMESTAMPTZ DEFAULT NOW()
);

-- Ürün kategorilerini saklamak için tablo
CREATE TABLE IF NOT EXISTS categories (
    category_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    creator_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(name, creator_id)
);

-- Etiketleri saklamak için tablo
CREATE TABLE IF NOT EXISTS tags (
    tag_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    note TEXT,
    pricing_percentage NUMERIC(5, 2),
    pricing_delta NUMERIC(10, 2),
    creator_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(name, creator_id)
);

-- Finansal İşlemler Tablosu
CREATE TABLE IF NOT EXISTS financial_transactions (
    transaction_id TEXT PRIMARY KEY,
    creator_id TEXT REFERENCES users(user_id) ON DELETE SET NULL,
    transaction_type VARCHAR(50) NOT NULL,
    category TEXT,
    amount NUMERIC(12, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'TRY',
    payment_method VARCHAR(50),
    description TEXT,
    transaction_date TIMESTAMPTZ NOT NULL,
    from_id TEXT,
    is_from_internal BOOLEAN,
    to_id TEXT,
    is_to_internal BOOLEAN,
    proof_url TEXT,
    approval_status VARCHAR(20) DEFAULT 'onayli',
    reference_id TEXT,
    reference_type VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ürünler Tablosu
CREATE TABLE IF NOT EXISTS products (
    product_id TEXT PRIMARY KEY,
    creator_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    supplier_id TEXT, 
    name TEXT NOT NULL,
    tags TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    last_purchase_date TIMESTAMPTZ,
    wholesale_price NUMERIC(12, 2),
    create_financial_transaction BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ürün Varyantları Tablosu
CREATE TABLE IF NOT EXISTS product_variants (
    variant_id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    rating NUMERIC(2, 1),
    shelf_location TEXT,
    images TEXT[],
    price NUMERIC(12, 2) NOT NULL,
    cost_price NUMERIC(12, 2),
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    sold_quantity INTEGER NOT NULL DEFAULT 0,
    tags TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Kategori Atama Tablosu
CREATE TABLE IF NOT EXISTS category_assignments (
    assignment_id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    category_id TEXT NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    assigner_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, category_id)
);

-- Etiket Atama Tablosu
CREATE TABLE IF NOT EXISTS tag_assignments (
    assignment_id TEXT PRIMARY KEY,
    tag_id TEXT NOT NULL REFERENCES tags(tag_id) ON DELETE CASCADE,
    relation_id TEXT NOT NULL REFERENCES relations(relation_id) ON DELETE CASCADE,
    assigner_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tag_id, relation_id)
);

-- Sepetler Tablosu
CREATE TABLE IF NOT EXISTS carts (
    cart_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    wholesaler_id TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    ordered_at TIMESTAMPTZ,
    financial_transaction_id TEXT REFERENCES financial_transactions(transaction_id) ON DELETE SET NULL
);

-- Sepet İçerikleri Tablosu
CREATE TABLE IF NOT EXISTS cart_items (
    cart_item_id TEXT PRIMARY KEY,
    cart_id TEXT NOT NULL REFERENCES carts(cart_id) ON DELETE CASCADE,
    variant_id TEXT NOT NULL REFERENCES product_variants(variant_id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL,
    current_price NUMERIC(12, 2) NOT NULL,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(cart_id, variant_id)
);

-- Indexler
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_tel_no ON users(tel_no);
CREATE INDEX IF NOT EXISTS idx_products_creator_id ON products(creator_id);
CREATE INDEX IF NOT EXISTS idx_variants_product_id ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_category_assignments_product_id ON category_assignments(product_id);
CREATE INDEX IF NOT EXISTS idx_category_assignments_category_id ON category_assignments(category_id);
CREATE INDEX IF NOT EXISTS idx_tag_assignments_tag_id ON tag_assignments(tag_id);
CREATE INDEX IF NOT EXISTS idx_tag_assignments_relation_id ON tag_assignments(relation_id);
CREATE INDEX IF NOT EXISTS idx_ft_creator_id ON financial_transactions(creator_id);
CREATE INDEX IF NOT EXISTS idx_ft_from_id ON financial_transactions(from_id);
CREATE INDEX IF NOT EXISTS idx_ft_to_id ON financial_transactions(to_id);
CREATE INDEX IF NOT EXISTS idx_ft_transaction_date ON financial_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_carts_customer_id ON carts(customer_id);
CREATE INDEX IF NOT EXISTS idx_carts_wholesaler_id ON carts(wholesaler_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart_id ON cart_items(cart_id);
CREATE INDEX IF NOT EXISTS idx_account_movements_user_id ON account_movements(user_id);
CREATE INDEX IF NOT EXISTS idx_address_info_user_id ON address_info(user_id);

-- Sadece aktif sepetler için unique constraint
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_cart ON carts(customer_id, wholesaler_id) WHERE status = 'active';
