import 'package:flutter/material.dart';
import 'package:frontend/models/cart.dart';
import 'package:frontend/models/connection_details.dart';
import 'package:frontend/providers/transaction_provider.dart';
import 'package:frontend/providers/wholesaler_order_provider.dart';
import 'package:frontend/screens/analysis_plus_screen.dart';
import 'package:frontend/screens/external_user_edit_screen.dart';
import 'package:frontend/screens/wholesaler_order_edit_screen.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/services/connection_service.dart';
import 'package:frontend/services/image_service.dart';
import 'package:frontend/widgets/financial_transaction_card.dart';
import 'package:frontend/widgets/order_card.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class PersonProfileScreen extends StatefulWidget {
  final String relationId;

  const PersonProfileScreen({super.key, required this.relationId});

  @override
  State<PersonProfileScreen> createState() => _PersonProfileScreenState();
}

enum OrderStatus { ordered, preparing, shipped, delivered, cancelled }

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}

class _PersonProfileScreenState extends State<PersonProfileScreen> {
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAllData();
  }

  Future<List<dynamic>> _loadAllData() async {
    final token = context.read<AuthProvider>().token!;
    final transactionProvider = context.read<TransactionProvider>();
    final connectionDetails =
        await ConnectionService().fetchConnectionDetails(token, widget.relationId);
    final results = await Future.wait([
      Future.value(connectionDetails),
      CartService().getOrdersBetweenUsers(token, connectionDetails.id),
      if (transactionProvider.transactions.isEmpty &&
          !transactionProvider.isLoading)
        transactionProvider.fetchAllFinancialData(),
    ]);
    return results;
  }
  
  Future<void> _refreshData() async {
    setState(() {
      _dataFuture = _loadAllData();
    });
    await _dataFuture;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  void _showActionConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String actionText,
    required Function(Map<String, dynamic> options) onConfirm,
    bool showTransactionSwitch = false,
  }) {
    bool createTransaction = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content),
                if (showTransactionSwitch) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Ticari İşlem Uygula'),
                    subtitle:
                        const Text('Bu satış için finansal kayıt oluşturulur.'),
                    value: createTransaction,
                    onChanged: (value) {
                      setState(() {
                        createTransaction = value;
                      });
                    },
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm({'createTransaction': createTransaction});
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Hata: ${snapshot.error}')));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Kişi bulunamadı.')));
        }

        final person = snapshot.data![0] as ConnectionDetails;
        final orders = snapshot.data![1] as List<Cart>;

        return _buildProfileContent(person, orders);
      },
    );
  }

  Widget _buildProfileContent(ConnectionDetails person, List<Cart> orders) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  expandedHeight: 140,
                  pinned: true,
                  floating: false,
                  forceElevated: innerBoxIsScrolled,
                   actions: [
                    if(person.canEdit)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Profili Düzenle',
                        onPressed: () async {
                           final result = await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ExternalUserEditScreen(user: person)
                          ));
                          if(result == true){
                            _refreshData();
                          }
                        },
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
                    centerTitle: false,
                    title: _buildAppBarContent(person),
                    background: _buildAppBarBackground(person),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: _buildQuickActions(),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    const TabBar(
                      tabs: [
                        Tab(text: "Genel Bakış"),
                        Tab(text: "Finans"),
                        Tab(text: "Siparişler"),
                        Tab(text: "Aktiviteler"),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _buildInfoTab(person),
                _buildFinancialsTab(person),
                _buildOrdersTab(orders, person),
                _buildInfoTabContent("Aktiviteler içeriği burada gösterilecek."),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppBarBackground(ConnectionDetails person) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.8),
            Theme.of(context).primaryColor.withOpacity(0.5)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      ),
    );
  }

  Widget _buildAppBarContent(ConnectionDetails person) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage: person.profilFotografi != null
              ? NetworkImage(ImageService.getFullImageUrl(person.profilFotografi))
              : null,
          child: person.profilFotografi == null ? const Icon(Icons.person, size: 22) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    person.displayName,
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white, shadows: [const Shadow(blurRadius: 2)]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if(person.scope == 'Harici')
                    Chip(
                      label: const Text('Harici'),
                      backgroundColor: Colors.red.shade400,
                      labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                ],
              ),
              if (person.isletmeIsmi != null && person.isletmeIsmi!.isNotEmpty && person.displayName != person.fullName)
                Text(
                  person.fullName,
                  style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoTab(ConnectionDetails person) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.phone),
            title: const Text("Telefon"),
            subtitle: Text(person.telNo ?? "Belirtilmemiş"),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text("Adres"),
            subtitle: Text(person.addressAsString),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info),
            title: const Text("Roller"),
            subtitle: Text(person.roles.join(', ')),
          ),
        ),
         Card(
          child: ListTile(
            leading: const Icon(Icons.sell),
            title: const Text("Etiketler"),
            subtitle: Text(person.tags.isEmpty ? "Etiket yok" : person.tags.map((t) => t.name).join(', ')),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        QuickAction(
          icon: Icons.smart_toy_outlined,
          label: "AI Analiz",
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AnalysisPlusScreen(),
              ),
            );
          },
        ),
        const QuickAction(icon: Icons.route_outlined, label: "Rota Ekle"),
        const QuickAction(icon: Icons.shopping_cart_outlined, label: "Sipariş"),
        const QuickAction(icon: Icons.sell_outlined, label: "Etiket"),
        const QuickAction(icon: Icons.account_balance_wallet_outlined, label: "Finansal İşlem"),
        const QuickAction(icon: Icons.description_outlined, label: "Ekstre PDF"),
      ],
    );
  }

  Widget _buildOrdersTab(List<Cart> orders, ConnectionDetails person) {
    if (orders.isEmpty) {
      return _buildInfoTabContent("Bu kişiyle ilgili sipariş bulunmuyor.");
    }
    final bool canManageOrders = person.roles.contains('Müşterim');

    return ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: orders.length,
        itemBuilder: (ctx, index) {
          final order = orders[index];
          OrderStatus status = OrderStatus.values.firstWhere(
              (e) => e.name == order.status,
              orElse: () => OrderStatus.ordered);
          return OrderCard(
            cart: order,
            perspective: CardPerspective.wholesaler,
            actionButtons: canManageOrders ? _buildActionButtons(order, status) : null,
            onTap: canManageOrders
                ? () async {
                    final updated = await Navigator.of(context).push(MaterialPageRoute(
                       builder: (_) => WholesalerOrderEditScreen(cartId: order.cartId),
                    ));
                    if (updated == true) {
                      _refreshData();
                    }
                  }
                : null,
          );
        },
    );
  }

  List<Widget> _buildActionButtons(Cart cart, OrderStatus status) {
    final provider = context.read<WholesalerOrderProvider>();
    List<Widget> buttons = [];
    void handleAction(Future<void> Function() action, String successMessage) {
        action().then((_) {
            _showSnackBar(successMessage);
            _refreshData();
        }).catchError((e) => _showSnackBar('Hata: $e', isError: true));
    }

    if (status == OrderStatus.ordered) {
      buttons.add(Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Onayla'),
          style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: Colors.green),
          onPressed: () => _showActionConfirmationDialog(
            context: context,
            title: 'Siparişi Onayla',
            content:
                'Bu siparişi onaylamak ve hazırlama aşamasına geçirmek istediğinizden emin misiniz? Stoklarınız güncellenecektir.',
            actionText: 'Onayla',
            onConfirm: (_) => handleAction(() => provider.confirmSale(cart.cartId), 'Sipariş onaylandı.'),
          ),
        ),
      ));
    }

    if (status == OrderStatus.preparing) {
      buttons.add(Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.local_shipping),
          label: const Text('Kargoya Ver'),
          style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: Colors.blue),
          onPressed: () => _showActionConfirmationDialog(
            context: context,
            title: 'Kargoya Ver',
            content: 'Siparişin durumunu "Kargoda" olarak güncellemek istediğinizden emin misiniz?',
            actionText: 'Evet, Kargoya Ver',
            onConfirm: (_) => handleAction(() => provider.updateOrderStatus(cart.cartId, 'shipped', createTransaction: false), 'Sipariş kargoya verildi.'),
          ),
        ),
      ));
    }

    if (status == OrderStatus.shipped) {
      buttons.add(Expanded(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.delivery_dining),
          label: const Text('Teslim Edildi'),
          style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: Colors.teal),
          onPressed: () => _showActionConfirmationDialog(
            context: context,
            title: 'Teslim Edildi',
            content: 'Siparişin müşteriye teslim edildiğini onaylıyor musunuz?',
            actionText: 'Evet, Teslim Edildi',
            showTransactionSwitch: true,
            onConfirm: (options) => handleAction(() => provider.updateOrderStatus(cart.cartId, 'delivered', createTransaction: options['createTransaction']), 'Sipariş teslim edildi.'),
          ),
        ),
      ));
    }

    if (status == OrderStatus.ordered || status == OrderStatus.preparing || status == OrderStatus.shipped) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 8));
      buttons.add(IconButton(
        icon: Icon(Icons.cancel, color: Colors.red.shade700),
        tooltip: 'Siparişi İptal Et',
        onPressed: () => _showActionConfirmationDialog(
          context: context,
          title: 'Siparişi İptal Et',
          content: 'Bu siparişi iptal etmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
          actionText: 'Evet, İptal Et',
          onConfirm: (_) => handleAction(() => provider.updateOrderStatus(cart.cartId, 'cancelled', createTransaction: false), 'Sipariş iptal edildi.'),
        ),
      ));
    }

    return buttons;
  }

  Widget _buildFinancialsTab(ConnectionDetails person) {
    final transactionProvider = context.watch<TransactionProvider>();
    final myUserId = context.watch<AuthProvider>().userId;
    if (myUserId == null) {
      return _buildInfoTabContent("Kullanıcı kimliği bulunamadı.");
    }
    final relevantTransactions =
        transactionProvider.transactions.where((tx) {
      final fromId = tx.originalData['from_id'];
      final toId = tx.originalData['to_id'];
      return (fromId == person.id && toId == myUserId) ||
          (fromId == myUserId && toId == person.id);
    }).toList();
    if (relevantTransactions.isEmpty) {
      return _buildInfoTabContent("Bu kişiyle finansal işlem bulunmuyor.");
    }
    return ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: relevantTransactions.length,
        itemBuilder: (ctx, index) {
          final transaction = relevantTransactions[index];
          return FinancialTransactionCard(
            transaction: transaction,
          );
        },
      );
  }

  Widget _buildInfoTabContent(String text) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [Center(child: Text(text, style: const TextStyle(color: Colors.grey)))],
    );
  }
}

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const QuickAction({super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 90,
      child: Card(
        elevation: 1,
        color: Theme.of(context).cardColor,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(icon,
                    color: Theme.of(context).primaryColor, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
