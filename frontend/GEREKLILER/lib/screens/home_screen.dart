import 'package:flutter/material.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/screens/cart_screen.dart';
import 'package:frontend/screens/notifications_screen.dart';
import 'package:frontend/screens/classification_screen.dart';
import 'package:frontend/screens/connections_screen.dart';
import 'package:frontend/screens/products_screen.dart';
import 'package:frontend/screens/financial_transactions_screen.dart';
import 'package:frontend/screens/shop_screen.dart';
import 'package:frontend/screens/wholesaler_orders_screen.dart';
import 'package:frontend/screens/analysis_plus_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/profile_view_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (ctx, notif, ch) => Badge(
              label: Text(notif.unreadCount.toString()),
              isLabelVisible: notif.unreadCount > 0,
              child: IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: 'Bildirimler',
                onPressed: () => _navigateTo(context, const NotificationsScreen()),
              ),
            ),
          ),
          Consumer<CartProvider>(
            builder: (ctx, cart, ch) => Badge(
              label: Text(cart.totalItems.toString()),
              isLabelVisible: cart.totalItems > 0,
              child: ch,
            ),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart),
              tooltip: 'Sepetim',
              onPressed: () => _navigateTo(context, const CartScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profilim',
            onPressed: () => _navigateTo(context, const ProfileViewScreen()),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueAccent,
              ),
              child: Text(
                'Menü',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Alışveriş'),
              onTap: () {
                Navigator.pop(context);
                _navigateTo(context, const ShopScreen());
              },
            ),

             ListTile(
              leading: const Icon(Icons.account_balance_wallet),
               title: const Text('Finansal İşlemler'),
              onTap: () {
                Navigator.pop(context);
                _navigateTo(context, const FinancialTransactionsScreen());
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("Satıcı Paneli", style: TextStyle(color: Colors.grey)),
            ),
             // YENİ EKLENEN SİPARİŞLER EKRANI BUTONU
            ListTile(
              leading: const Icon(Icons.inbox),
              title: const Text('Gelen Siparişler'),
              onTap: () {
                Navigator.pop(context);
                _navigateTo(context, const WholesalerOrdersScreen());
              },
            ),
            ListTile( 
              leading: const Icon(Icons.inventory_2),
              title: const Text('Ürünlerim'),
              onTap: () {
                Navigator.pop(context);
                _navigateTo(context, const ProductsScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Sınıflandırma'),
              onTap: () {
                Navigator.pop(context);
                _navigateTo(context, const ClassificationScreen());
              },
            ),
            ExpansionTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('Analizler'),
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Analiz+'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(context, const AnalysisPlusScreen());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(context, const DashboardScreen());
                  },
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Bağlantılar'),
              onTap: () {
                Navigator.pop(context);
                _navigateTo(context, const ConnectionsScreen());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış Yap'),
              onTap: () {
                Navigator.pop(context);
                Provider.of<AuthProvider>(context, listen: false).logout();
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Başarıyla giriş yaptınız!'),
      ),
    );
  }
}
