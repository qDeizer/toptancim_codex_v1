import 'package:flutter/material.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/transaction_provider.dart';
import 'package:frontend/providers/wholesaler_order_provider.dart';
import 'package:frontend/screens/analysis_hub_screen.dart';
import 'package:frontend/screens/cart_screen.dart';
import 'package:frontend/screens/classification_screen.dart';
import 'package:frontend/screens/connections_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/financial_transactions_screen.dart';
import 'package:frontend/screens/notifications_screen.dart';
import 'package:frontend/screens/products_screen.dart';
import 'package:frontend/screens/profile_view_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/screens/shop_screen.dart';
import 'package:frontend/screens/media_screen.dart';
import 'package:frontend/providers/media_provider.dart';
import 'package:frontend/screens/wholesaler_orders_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshDashboard());
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([
      context.read<NotificationProvider>().fetchNotifications(),
      context.read<CartProvider>().fetchMyCarts(),
      context.read<ConnectionProvider>().fetchConnections(),
      context.read<MediaProvider>().fetchMedia(refresh: true),
      context.read<TransactionProvider>().fetchAllFinancialData(),
      context.read<WholesalerOrderProvider>().fetchWholesalerOrders(),
    ]);
    if (mounted) setState(() => _lastRefresh = DateTime.now());
  }

  void _go(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    final cart = context.watch<CartProvider>();
    final connections = context.watch<ConnectionProvider>();
    final tx = context.watch<TransactionProvider>();
    final orders = context.watch<WholesalerOrderProvider>();
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final heroStats = [
      _HeroStat('Bağlantı', '${connections.allConnections.length}',
          Icons.people_alt_outlined),
      _HeroStat('Bildirim', '${notif.unreadCount}',
          Icons.notifications_active_outlined),
      _HeroStat('Aktif Sepet', '${cart.totalItemCount}',
          Icons.shopping_cart_checkout_outlined),
      _HeroStat('Bekleyen Sipariş', '${orders.orderedCarts.length}',
          Icons.pending_actions_outlined),
    ];
    const modules = [
      _ModuleItem(Icons.people_alt_outlined, 'Bağlantılar',
          'Müşteri ve toptancı ağını yönetin.', ConnectionsScreen()),
      _ModuleItem(
          Icons.account_balance_wallet_outlined,
          'Finans',
          'Cari hareketleri ve özetleri takip edin.',
          FinancialTransactionsScreen()),
      _ModuleItem(Icons.inbox_outlined, 'Siparişler',
          'Gelen siparişleri yönetin.', WholesalerOrdersScreen()),
      _ModuleItem(Icons.inventory_2_outlined, 'Ürünlerim',
          'Katalog ve stok düzenlemeleri.', ProductsScreen()),
      _ModuleItem(Icons.sell_outlined, 'Sınıflandırma',
          'Kategori ve etiket yönetimi.', ClassificationScreen()),
      _ModuleItem(Icons.auto_awesome_outlined, 'Analiz+',
          'Kişi ve ürün bazlı analiz akışları.', AnalysisHubScreen()),
      _ModuleItem(Icons.dashboard_customize_outlined, 'Dashboard',
          'Geniş dashboard görünümü.', DashboardScreen()),
      _ModuleItem(Icons.perm_media_outlined, 'Medya', 'Görsel arşiviniz ve AI görsel oluşturma.', MediaScreen()),
      _ModuleItem(Icons.storefront_outlined, 'Alışveriş',
          'Pazar ve ürün keşif ekranı.', ShopScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _refreshDashboard,
          ),
          Badge(
            label: Text(notif.unreadCount.toString()),
            isLabelVisible: notif.unreadCount > 0,
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Bildirimler',
              onPressed: () => _go(const NotificationsScreen()),
            ),
          ),
          Badge(
            label: Text(cart.totalItems.toString()),
            isLabelVisible: cart.totalItems > 0,
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              tooltip: 'Sepetim',
              onPressed: () => _go(const CartScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profilim',
            onPressed: () => _go(const ProfileViewScreen()),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration:
                  BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text('Menü',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            ...modules.map((item) => ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.title),
                  onTap: () {
                    Navigator.pop(context);
                    _go(item.screen);
                  },
                )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Ayarlar'),
              onTap: () {
                Navigator.pop(context);
                _go(const SettingsScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış Yap'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthProvider>().logout();
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth > 900;
            final moduleCols = box.maxWidth > 1100
                ? 4
                : box.maxWidth > 700
                    ? 3
                    : 2;
            final moduleWidth =
                (box.maxWidth - ((moduleCols - 1) * 12) - 32) / moduleCols;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _hero(context, heroStats),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: modules
                      .map((item) => SizedBox(
                          width: moduleWidth,
                          child: _ModuleCard(
                              item: item, onTap: () => _go(item.screen))))
                      .toList(),
                ),
                const SizedBox(height: 16),
                wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _financeCard(tx, currency)),
                          const SizedBox(width: 12),
                          Expanded(child: _focusCard(orders, cart)),
                        ],
                      )
                    : Column(
                        children: [
                          _financeCard(tx, currency),
                          const SizedBox(height: 12),
                          _focusCard(orders, cart),
                        ],
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, List<_HeroStat> stats) {
    final theme = Theme.of(context);
    final refreshed = _lastRefresh == null
        ? 'Henüz senkron yok'
        : DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(_lastRefresh!);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 450),
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operasyon Merkezi',
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
                'Bağlantılar, siparişler ve finans tek ekranda. Ana modüllere buradan hızlıca geçebilirsiniz.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.88))),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: stats
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(s.icon, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('${s.label}: ${s.value}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            Text('Son yenileme: $refreshed',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _financeCard(TransactionProvider tx, NumberFormat currency) {
    final items = [
      _InfoRow('Cari Durum', currency.format(tx.summary.currentBalance),
          Icons.account_balance_outlined),
      _InfoRow('Toplam Alacak', currency.format(tx.summary.totalReceivable),
          Icons.arrow_downward_rounded),
      _InfoRow('Toplam Borç', currency.format(tx.summary.totalDebt),
          Icons.arrow_upward_rounded),
      _InfoRow('Net Nakit', currency.format(tx.summary.netCash),
          Icons.paid_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Finans Özeti',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Cari tabloyu anlık olarak buradan okuyabilirsiniz.'),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(item.icon,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(item.label)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(item.value,
                      key: ValueKey(item.value),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            )),
      ]),
    );
  }

  Widget _focusCard(WholesalerOrderProvider orders, CartProvider cart) {
    final rows = [
      _FocusRow(
          'Onay bekleyen siparişler', '${orders.orderedCarts.length} adet'),
      _FocusRow(
          'Hazırlanan siparişler', '${orders.preparingCarts.length} adet'),
      _FocusRow('Kargodaki siparişler', '${orders.shippedCarts.length} adet'),
      _FocusRow('Aktif sepet ürünleri', '${cart.totalItemCount} kalem'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Odak Listesi',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Bugün ilk bakmanız gereken akışlar.'),
        const SizedBox(height: 16),
        ...rows.map((row) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Expanded(
                    child: Text(row.label,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(row.value),
              ]),
            )),
      ]),
    );
  }
}

class _ModuleItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget screen;
  const _ModuleItem(this.icon, this.title, this.subtitle, this.screen);
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;
  final VoidCallback onTap;
  const _ModuleCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  Icon(item.icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(item.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(item.subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      ),
    );
  }
}

class _HeroStat {
  final String label;
  final String value;
  final IconData icon;
  const _HeroStat(this.label, this.value, this.icon);
}

class _InfoRow {
  final String label;
  final String value;
  final IconData icon;
  const _InfoRow(this.label, this.value, this.icon);
}

class _FocusRow {
  final String label;
  final String value;
  const _FocusRow(this.label, this.value);
}


