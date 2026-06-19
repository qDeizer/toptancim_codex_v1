/**
 * Demo seed: uygulama "kullanılmış" görünsün diye gerçekçi veri üretir.
 *
 * Kullanıcılar: demo1 (toptancı), demo2 (hem toptancı hem müşteri), demo3 (müşteri)
 * Hepsinin şifresi: asdasd
 *
 * Çalıştır: cd backend && node db/seed_demo.js
 * Not: idempotent — demo kullanıcıları varsa önce siler, baştan kurar.
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env'), quiet: true });
const bcrypt = require('bcryptjs');
const db = require('../db');
const generateId = require('../utils/generateId');

const PASSWORD = 'asdasd';

// Tarih yardımcıları: son 90 güne yayılmış aktivite
const daysAgo = (d, hourJitter = true) => {
    const t = new Date();
    t.setDate(t.getDate() - d);
    if (hourJitter) t.setHours(8 + Math.floor(Math.random() * 12), Math.floor(Math.random() * 60), 0, 0);
    return t;
};

async function main() {
    const client = await db.connect();
    try {
        await client.query('BEGIN');

        // ---------- 0) Eski demo verisini temizle ----------
        const old = await client.query("SELECT user_id FROM users WHERE user_name IN ('demo1','demo2','demo3')");
        if (old.rows.length > 0) {
            const ids = old.rows.map(r => r.user_id);
            // FK CASCADE'ler users silinince çoğunu götürür; relations/carts/ft'lerde FK yok → elle sil
            await client.query('DELETE FROM cart_items WHERE cart_id IN (SELECT cart_id FROM carts WHERE customer_id = ANY($1) OR wholesaler_id = ANY($1))', [ids]);
            await client.query('DELETE FROM carts WHERE customer_id = ANY($1) OR wholesaler_id = ANY($1)', [ids]);
            await client.query('DELETE FROM financial_transactions WHERE creator_id = ANY($1) OR from_id = ANY($1) OR to_id = ANY($1)', [ids]);
            await client.query('DELETE FROM tag_assignments WHERE assigner_id = ANY($1)', [ids]);
            await client.query('DELETE FROM relations WHERE wholesaler_id = ANY($1) OR customer_id = ANY($1)', [ids]);
            await client.query('DELETE FROM users WHERE user_id = ANY($1)', [ids]);
            console.log('Eski demo verisi temizlendi:', ids.join(', '));
        }

        const hash = await bcrypt.hash(PASSWORD, 10);

        // ---------- 1) Kullanıcılar ----------
        const USERS = [
            {
                user_name: 'demo1', isletme: 'Demo Toptan Gıda', ad: 'Ahmet', soyad: 'Demir',
                tel: '05550000001', email: 'demo1@demo.com', toptanci: true,
                hakkinda: 'Toptan gıda ve şarküteri ürünleri tedarikçisi. 20 yıllık sektör tecrübesi.',
                adres: { title: 'Merkez Depo', address: 'İstanbul / Bayrampaşa', detail: 'Hal Cd. No:12 Depo 5', lat: 41.0451, lon: 28.9125 },
            },
            {
                user_name: 'demo2', isletme: 'Demo Market', ad: 'Mehmet', soyad: 'Kaya', tel: '05550000002',
                email: 'demo2@demo.com', toptanci: true,
                hakkinda: 'Mahalle marketi. Aynı zamanda çevre bakkallarara toptan dağıtım yapıyoruz.',
                adres: { title: 'Mağaza', address: 'İstanbul / Kadıköy', detail: 'Moda Cd. No:48', lat: 40.9819, lon: 29.0258 },
            },
            {
                user_name: 'demo3', isletme: 'Demo Büfe', ad: 'Ayşe', soyad: 'Yılmaz', tel: '05550000003',
                email: 'demo3@demo.com', toptanci: false,
                hakkinda: 'Okul karşısı büfe işletmesi.',
                adres: { title: 'Büfe', address: 'İstanbul / Üsküdar', detail: 'Çamlıca Mh. Okul Sk. No:3', lat: 41.0214, lon: 29.0666 },
            },
        ];

        const uid = {};
        for (const u of USERS) {
            const id = generateId('usr_', 10);
            uid[u.user_name] = id;
            await client.query(
                `INSERT INTO users (user_id, user_name, isletme_ismi, ad, soyad, tel_no, email, password_hash, hakkinda, toptanci_uyelik, created_at)
                 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
                [id, u.user_name, u.isletme, u.ad, u.soyad, u.tel, u.email, hash, u.hakkinda, u.toptanci, daysAgo(90)]
            );
            await client.query(
                `INSERT INTO account_movements (movement_id, user_id, creation_date, last_login, last_update, login_count)
                 VALUES ($1,$2,$3,$4,$5,$6)`,
                ['mov_' + id, id, daysAgo(90), daysAgo(0), daysAgo(0), 47 + Math.floor(Math.random() * 80)]
            );
            await client.query(
                `INSERT INTO address_info (address_id, user_id, address_title, address, detailed_address, latitude, longitude)
                 VALUES ($1,$2,$3,$4,$5,$6,$7)`,
                ['addr_' + id, id, u.adres.title, u.adres.address, u.adres.detail, u.adres.lat, u.adres.lon]
            );
            console.log(`Kullanıcı: ${u.user_name} (${id}) şifre: ${PASSWORD}`);
        }

        // ---------- 2) İlişkiler (toptancı ↔ müşteri) ----------
        // demo1 toptancı → demo2 ve demo3 müşterisi; demo2 toptancı → demo3 müşterisi
        const relations = [
            { w: uid.demo1, c: uid.demo2 },
            { w: uid.demo1, c: uid.demo3 },
            { w: uid.demo2, c: uid.demo3 },
        ];
        const relIds = [];
        for (const r of relations) {
            const id = generateId('rel_', 10);
            relIds.push(id);
            await client.query(
                `INSERT INTO relations (relation_id, wholesaler_id, customer_id, is_wholesaler_internal, is_customer_internal, relation_start_date)
                 VALUES ($1,$2,$3,true,true,$4)`,
                [id, r.w, r.c, daysAgo(85)]
            );
        }
        console.log('İlişkiler kuruldu (demo1→demo2, demo1→demo3, demo2→demo3)');

        // ---------- 3) Kategoriler ve etiketler ----------
        const catNames = ['İçecek', 'Atıştırmalık', 'Temel Gıda', 'Temizlik'];
        const catIds = {};
        for (const name of catNames) {
            const id = generateId('cat_', 10);
            catIds[name] = id;
            await client.query(
                'INSERT INTO categories (category_id, name, creator_id) VALUES ($1,$2,$3)',
                [id, name, uid.demo1]
            );
        }

        const tagId = generateId('tag_', 10);
        await client.query(
            `INSERT INTO tags (tag_id, name, note, pricing_percentage, creator_id) VALUES ($1,$2,$3,$4,$5)`,
            [tagId, 'Sadık Müşteri', 'Uzun süreli müşterilere %5 indirim', -5.00, uid.demo1]
        );
        await client.query(
            `INSERT INTO tag_assignments (assignment_id, tag_id, relation_id, assigner_id) VALUES ($1,$2,$3,$4)`,
            [generateId('tas_', 10), tagId, relIds[1], uid.demo1]
        );
        console.log('Kategoriler + Sadık Müşteri etiketi eklendi');

        // ---------- 4) Ürünler + varyantlar (demo1 toptancının kataloğu) ----------
        const PRODUCTS_D1 = [
            {
                name: 'Kola 330ml', cat: 'İçecek', variants: [
                    { name: 'Tekli Kutu', price: 18.50, cost: 14.00, stock: 480, sold: 1240 },
                    { name: '24lü Koli', price: 420.00, cost: 330.00, stock: 60, sold: 185 },
                ]
            },
            {
                name: 'Su 0.5L (24lü)', cat: 'İçecek', variants: [
                    { name: 'Koli', price: 96.00, cost: 72.00, stock: 200, sold: 540 },
                ]
            },
            {
                name: 'Cips Klasik 110g', cat: 'Atıştırmalık', variants: [
                    { name: 'Tekli', price: 32.00, cost: 24.50, stock: 350, sold: 890 },
                    { name: '20li Kutu', price: 590.00, cost: 470.00, stock: 45, sold: 120 },
                ]
            },
            {
                name: 'Çikolatalı Gofret 36g', cat: 'Atıştırmalık', variants: [
                    { name: '24lü Kutu', price: 168.00, cost: 126.00, stock: 80, sold: 310 },
                ]
            },
            {
                name: 'Ayçiçek Yağı 5L', cat: 'Temel Gıda', variants: [
                    { name: 'Teneke', price: 385.00, cost: 330.00, stock: 120, sold: 260 },
                ]
            },
            {
                name: 'Makarna 500g', cat: 'Temel Gıda', variants: [
                    { name: 'Burgu (20li koli)', price: 240.00, cost: 185.00, stock: 90, sold: 410 },
                    { name: 'Spagetti (20li koli)', price: 240.00, cost: 185.00, stock: 75, sold: 380 },
                ]
            },
            {
                name: 'Pirinç Baldo 1kg', cat: 'Temel Gıda', variants: [
                    { name: '10lu Koli', price: 680.00, cost: 560.00, stock: 55, sold: 145 },
                ]
            },
            {
                name: 'Bulaşık Deterjanı 750ml', cat: 'Temizlik', variants: [
                    { name: 'Limon (12li)', price: 312.00, cost: 240.00, stock: 65, sold: 175 },
                ]
            },
        ];

        const variantIds = {}; // ad → {variant_id, price}
        for (const p of PRODUCTS_D1) {
            const pid = generateId('prd_', 10);
            await client.query(
                `INSERT INTO products (product_id, creator_id, name, is_active, wholesale_price, last_purchase_date, created_at)
                 VALUES ($1,$2,$3,true,$4,$5,$6)`,
                [pid, uid.demo1, p.name, p.variants[0].cost, daysAgo(20), daysAgo(80)]
            );
            await client.query(
                `INSERT INTO category_assignments (assignment_id, product_id, category_id, assigner_id) VALUES ($1,$2,$3,$4)`,
                [generateId('cas_', 10), pid, catIds[p.cat], uid.demo1]
            );
            for (let i = 0; i < p.variants.length; i++) {
                const v = p.variants[i];
                const vid = generateId('var_', 10);
                variantIds[`${p.name}|${v.name}`] = { id: vid, price: v.price };
                await client.query(
                    `INSERT INTO product_variants (variant_id, product_id, name, description, price, cost_price, stock_quantity, sold_quantity, is_active, sort_order, rating, created_at)
                     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true,$9,$10,$11)`,
                    [vid, pid, v.name, `${p.name} - ${v.name}`, v.price, v.cost, v.stock, v.sold, i, (3.5 + Math.random() * 1.5).toFixed(1), daysAgo(80)]
                );
            }
        }
        console.log(`demo1 kataloğu: ${PRODUCTS_D1.length} ürün`);

        // demo2'nin kendi küçük kataloğu (demo3'e satıyor)
        const PRODUCTS_D2 = [
            {
                name: 'Tost Ekmeği', cat: null, variants: [
                    { name: 'Standart', price: 25.00, cost: 17.50, stock: 40, sold: 220 },
                ]
            },
            {
                name: 'Kaşar Peyniri 1kg', cat: null, variants: [
                    { name: 'Vakumlu', price: 280.00, cost: 230.00, stock: 25, sold: 85 },
                ]
            },
        ];
        for (const p of PRODUCTS_D2) {
            const pid = generateId('prd_', 10);
            await client.query(
                `INSERT INTO products (product_id, creator_id, name, is_active, wholesale_price, created_at)
                 VALUES ($1,$2,$3,true,$4,$5)`,
                [pid, uid.demo2, p.name, p.variants[0].cost, daysAgo(60)]
            );
            for (let i = 0; i < p.variants.length; i++) {
                const v = p.variants[i];
                const vid = generateId('var_', 10);
                variantIds[`${p.name}|${v.name}`] = { id: vid, price: v.price };
                await client.query(
                    `INSERT INTO product_variants (variant_id, product_id, name, price, cost_price, stock_quantity, sold_quantity, is_active, sort_order, created_at)
                     VALUES ($1,$2,$3,$4,$5,$6,$7,true,$8,$9)`,
                    [vid, pid, v.name, v.price, v.cost, v.stock, v.sold, i, daysAgo(60)]
                );
            }
        }
        console.log(`demo2 kataloğu: ${PRODUCTS_D2.length} ürün`);

        // ---------- 5) Siparişler (sepet akışı: ordered → preparing → shipped → delivered) ----------
        // helper: sipariş + cart_items + finansal işlem (Tahakkuk) oluştur
        let orderCount = 0;
        async function makeOrder({ customer, wholesaler, items, status, day }) {
            const cartId = generateId('crt_', 10);
            let total = 0;
            for (const it of items) total += it.v.price * it.qty;
            const orderedAt = daysAgo(day);
            await client.query(
                `INSERT INTO carts (cart_id, customer_id, wholesaler_id, status, total_amount, created_at, updated_at, ordered_at)
                 VALUES ($1,$2,$3,$4,$5,$6,$6,$7)`,
                [cartId, customer, wholesaler, status, total.toFixed(2), daysAgo(day + 1), orderedAt]
            );
            for (const it of items) {
                await client.query(
                    `INSERT INTO cart_items (cart_item_id, cart_id, variant_id, quantity, current_price, added_at)
                     VALUES ($1,$2,$3,$4,$5,$6)`,
                    [generateId('cit_', 10), cartId, it.v.id, it.qty, it.v.price, daysAgo(day + 1)]
                );
            }
            // Sipariş tahakkuku: toptancı alacaklanır (from: müşteri, to: toptancı)
            const ftId = generateId('ftr_', 12);
            await client.query(
                `INSERT INTO financial_transactions
                 (transaction_id, creator_id, transaction_type, category, amount, currency, payment_method, description, transaction_date, from_id, is_from_internal, to_id, is_to_internal, approval_status, reference_id, reference_type)
                 VALUES ($1,$2,'Tahakkuk','Satış',$3,'TRY','Açık Hesap',$4,$5,$6,true,$7,true,'onayli',$8,'order')`,
                [ftId, wholesaler, total.toFixed(2), `Sipariş bedeli (#${cartId.slice(-6)})`, orderedAt, customer, wholesaler, cartId]
            );
            await client.query('UPDATE carts SET financial_transaction_id = $1 WHERE cart_id = $2', [ftId, cartId]);
            orderCount++;
            return { cartId, total };
        }

        const v = (k) => variantIds[k];

        // demo2 → demo1'den siparişler (geçmişten bugüne)
        const o1 = await makeOrder({
            customer: uid.demo2, wholesaler: uid.demo1, status: 'delivered', day: 45,
            items: [{ v: v('Kola 330ml|24lü Koli'), qty: 5 }, { v: v('Cips Klasik 110g|20li Kutu'), qty: 3 }],
        });
        const o2 = await makeOrder({
            customer: uid.demo2, wholesaler: uid.demo1, status: 'delivered', day: 30,
            items: [{ v: v('Ayçiçek Yağı 5L|Teneke'), qty: 10 }, { v: v('Makarna 500g|Burgu (20li koli)'), qty: 4 }],
        });
        const o3 = await makeOrder({
            customer: uid.demo2, wholesaler: uid.demo1, status: 'delivered', day: 14,
            items: [{ v: v('Su 0.5L (24lü)|Koli'), qty: 20 }, { v: v('Çikolatalı Gofret 36g|24lü Kutu'), qty: 6 }],
        });
        const o4 = await makeOrder({
            customer: uid.demo2, wholesaler: uid.demo1, status: 'shipped', day: 3,
            items: [{ v: v('Pirinç Baldo 1kg|10lu Koli'), qty: 8 }, { v: v('Bulaşık Deterjanı 750ml|Limon (12li)'), qty: 5 }],
        });

        // demo3 → demo1'den siparişler
        const o5 = await makeOrder({
            customer: uid.demo3, wholesaler: uid.demo1, status: 'delivered', day: 21,
            items: [{ v: v('Kola 330ml|Tekli Kutu'), qty: 48 }, { v: v('Cips Klasik 110g|Tekli'), qty: 30 }],
        });
        const o6 = await makeOrder({
            customer: uid.demo3, wholesaler: uid.demo1, status: 'preparing', day: 1,
            items: [{ v: v('Çikolatalı Gofret 36g|24lü Kutu'), qty: 2 }, { v: v('Su 0.5L (24lü)|Koli'), qty: 5 }],
        });

        // demo3 → demo2'den sipariş
        const o7 = await makeOrder({
            customer: uid.demo3, wholesaler: uid.demo2, status: 'delivered', day: 10,
            items: [{ v: v('Tost Ekmeği|Standart'), qty: 20 }, { v: v('Kaşar Peyniri 1kg|Vakumlu'), qty: 3 }],
        });

        // demo3'ün demo1'de AKTİF (henüz sipariş edilmemiş) sepeti — uygulama canlı dursun
        const activeCart = generateId('crt_', 10);
        const acItems = [{ v: v('Makarna 500g|Spagetti (20li koli)'), qty: 2 }, { v: v('Kola 330ml|24lü Koli'), qty: 1 }];
        let acTotal = 0;
        for (const it of acItems) acTotal += it.v.price * it.qty;
        await client.query(
            `INSERT INTO carts (cart_id, customer_id, wholesaler_id, status, total_amount, created_at, updated_at)
             VALUES ($1,$2,$3,'active',$4,NOW(),NOW())`,
            [activeCart, uid.demo3, uid.demo1, acTotal.toFixed(2)]
        );
        for (const it of acItems) {
            await client.query(
                `INSERT INTO cart_items (cart_item_id, cart_id, variant_id, quantity, current_price)
                 VALUES ($1,$2,$3,$4,$5)`,
                [generateId('cit_', 10), activeCart, it.v.id, it.qty, it.v.price]
            );
        }
        console.log(`${orderCount} sipariş + 1 aktif sepet oluşturuldu`);

        // ---------- 6) Ödemeler (Nakit Akışı) ve giderler ----------
        // Teslim edilen siparişlerin bir kısmı ödenmiş olsun (kısmi bakiye kalsın)
        const payments = [
            { from: uid.demo2, to: uid.demo1, amount: o1.total, day: 40, desc: 'Sipariş ödemesi (havale)' },
            { from: uid.demo2, to: uid.demo1, amount: o2.total, day: 25, desc: 'Sipariş ödemesi (nakit)' },
            { from: uid.demo2, to: uid.demo1, amount: Math.round(o3.total * 0.5), day: 7, desc: 'Kısmi ödeme' },
            { from: uid.demo3, to: uid.demo1, amount: o5.total, day: 15, desc: 'Sipariş ödemesi (kart)' },
            { from: uid.demo3, to: uid.demo2, amount: o7.total, day: 8, desc: 'Sipariş ödemesi (nakit)' },
        ];
        for (const p of payments) {
            await client.query(
                `INSERT INTO financial_transactions
                 (transaction_id, creator_id, transaction_type, category, amount, currency, payment_method, description, transaction_date, from_id, is_from_internal, to_id, is_to_internal, approval_status)
                 VALUES ($1,$2,'Nakit Akışı','Tahsilat',$3,'TRY','Havale/Nakit',$4,$5,$6,true,$7,true,'onayli')`,
                [generateId('ftr_', 12), p.to, p.amount, p.desc, daysAgo(p.day), p.from, p.to]
            );
        }

        // demo1'in tedarikçi alımları ve işletme giderleri (Doğrudan İşlem)
        const expenses = [
            { amount: 45000, day: 50, cat: 'Mal Alımı', desc: 'Toptan içecek alımı (tedarikçi)' },
            { amount: 28500, day: 35, cat: 'Mal Alımı', desc: 'Gıda toptan alım' },
            { amount: 6200, day: 28, cat: 'Nakliye', desc: 'Aylık nakliye gideri' },
            { amount: 14000, day: 12, cat: 'Kira', desc: 'Depo kirası' },
        ];
        for (const e of expenses) {
            await client.query(
                `INSERT INTO financial_transactions
                 (transaction_id, creator_id, transaction_type, category, amount, currency, payment_method, description, transaction_date, from_id, is_from_internal, approval_status)
                 VALUES ($1,$2,'Doğrudan İşlem',$3,$4,'TRY','Havale',$5,$6,$7,true,'onayli')`,
                [generateId('ftr_', 12), uid.demo1, e.cat, e.amount, e.desc, daysAgo(e.day), uid.demo1]
            );
        }
        console.log(`${payments.length} ödeme + ${expenses.length} gider işlendi`);

        // ---------- 7) Bildirimler ----------
        const notifs = [
            { user: uid.demo1, title: 'Yeni Sipariş', msg: 'Demo Büfe yeni bir sipariş verdi.', type: 'order_update', day: 1 },
            { user: uid.demo1, title: 'Ödeme Alındı', msg: 'Demo Market kısmi ödeme yaptı.', type: 'transaction', day: 7 },
            { user: uid.demo2, title: 'Sipariş Kargoda', msg: 'Demo Toptan Gıda siparişinizi kargoya verdi.', type: 'order_update', day: 3 },
            { user: uid.demo3, title: 'Sipariş Hazırlanıyor', msg: 'Siparişiniz hazırlanmaya başlandı.', type: 'order_update', day: 1 },
        ];
        for (const n of notifs) {
            await client.query(
                `INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
                 VALUES ($1,$2,$3,$4,$5,$6)`,
                [n.user, n.title, n.msg, n.type, Math.random() > 0.5, daysAgo(n.day)]
            );
        }
        console.log(`${notifs.length} bildirim eklendi`);

        await client.query('COMMIT');
        console.log('\n=== SEED TAMAM ===');
        console.log('Giriş bilgileri: demo1 / demo2 / demo3 — şifre hepsi: asdasd');
        console.log('demo1: toptancı (8 ürün, 6 sipariş aldı, gelir/gider kayıtlı)');
        console.log('demo2: market (demo1 müşterisi + demo3 e satan toptancı)');
        console.log('demo3: büfe (demo1 ve demo2 müşterisi, 1 aktif sepeti var)');
    } catch (e) {
        await client.query('ROLLBACK');
        console.error('SEED HATASI:', e.message);
        throw e;
    } finally {
        client.release();
        await db.pool?.end?.();
        process.exit(0);
    }
}

main();
