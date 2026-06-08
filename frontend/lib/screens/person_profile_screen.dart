import 'package:flutter/material.dart';
import 'package:frontend/models/cart.dart';
import 'package:frontend/models/connection.dart';
import 'package:frontend/models/connection_details.dart';
import 'package:frontend/models/financial_transaction.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/transaction_provider.dart';
import 'package:frontend/providers/wholesaler_order_provider.dart';
import 'package:frontend/screens/add_financial_transaction_screen.dart';
import 'package:frontend/screens/analysis_hub_screen.dart';
import 'package:frontend/screens/customer_order_builder_screen.dart';
import 'package:frontend/screens/external_user_edit_screen.dart';
import 'package:frontend/screens/select_tags_screen.dart';
import 'package:frontend/screens/shop_screen.dart';
import 'package:frontend/screens/wholesaler_order_edit_screen.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/services/connection_service.dart';
import 'package:frontend/services/image_service.dart';
import 'package:frontend/services/statement_pdf_service.dart';
import 'package:frontend/utils/contact_utils.dart';
import 'package:frontend/utils/financial_transaction_utils.dart';
import 'package:frontend/utils/logger.dart';
import 'package:frontend/widgets/financial_transaction_card.dart';
import 'package:frontend/widgets/order_card.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PersonProfileScreen extends StatefulWidget {
  final String relationId;
  const PersonProfileScreen({super.key, required this.relationId});

  @override
  State<PersonProfileScreen> createState() => _PersonProfileScreenState();
}

enum OrderStatus { ordered, preparing, shipped, delivered, cancelled }

class _Payload {
  final ConnectionDetails person;
  final List<Cart> orders;
  final List<FinancialTransaction> transactions;
  const _Payload(this.person, this.orders, this.transactions);
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarHeader(this.tabBar);
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(BuildContext c, double s, bool o) =>
      Container(color: Theme.of(c).scaffoldBackgroundColor, child: tabBar);
  @override
  bool shouldRebuild(covariant _TabBarHeader oldDelegate) => false;
}

class _PersonProfileScreenState extends State<PersonProfileScreen> {
  late Future<_Payload> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Payload> _load() async {
    AppLogger.info(
      'Person profile load started: relationId=${widget.relationId}',
    );
    final auth = context.read<AuthProvider>();
    final txProvider = context.read<TransactionProvider>();
    final token = auth.token;
    final myId = auth.userId;
    if (token == null || myId == null) {
      throw Exception('Yetkilendirme bilgisi bulunamadı.');
    }
    final person = await ConnectionService()
        .fetchConnectionDetails(token, widget.relationId);
    await txProvider.fetchAllFinancialData();
    final orders = person.scope == 'Dahili'
        ? await CartService().getOrdersBetweenUsers(token, person.id)
        : <Cart>[];
    final txs = txProvider.transactions.where((tx) {
      final fromId = tx.originalData['from_id'];
      final toId = tx.originalData['to_id'];
      return (fromId == person.id && toId == myId) ||
          (fromId == myId && toId == person.id);
    }).toList();
    AppLogger.info(
      'Person profile load completed: relationId=${widget.relationId}, personId=${person.id}, orders=${orders.length}, transactions=${txs.length}',
    );
    return _Payload(person, orders, txs);
  }

  Future<void> _refresh() async {
    AppLogger.debug(
      'Person profile refresh requested: relationId=${widget.relationId}',
    );
    setState(() => _future = _load());
    await _future;
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(text),
          backgroundColor:
              error ? Theme.of(context).colorScheme.error : Colors.green),
    );
  }

  Map<String, dynamic> _personMap(ConnectionDetails p) => {
        'person_id': p.id,
        'isletme_ismi': p.isletmeIsmi,
        'ad': p.ad,
        'soyad': p.soyad,
        'profil_fotografi': p.profilFotografi,
      };

  Future<void> _openTags(ConnectionDetails p) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SelectTagsScreen(
          connection: Connection(
            relationId: p.relationId,
            userId: p.id,
            isletmeIsmi: p.isletmeIsmi,
            ad: p.ad,
            soyad: p.soyad,
            profilFotografi: p.profilFotografi,
            relationRole: p.isWholesaler ? 'customer' : 'wholesaler',
            isInternal: p.scope == 'Dahili',
          ),
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _openFinancial(ConnectionDetails p) async {
    AppLogger.info(
      'Person profile opening financial transaction screen: personId=${p.id}, relationId=${p.relationId}',
    );
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddFinancialTransactionScreen(
          initialPerson: _personMap(p),
          title: '${p.displayName} için Finansal İşlem',
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _openOrder(ConnectionDetails p) async {
    if (p.scope != 'Dahili') {
      _snack(
          'Sipariş akışı yalnızca dahili kullanıcılar için kullanılabiliyor.',
          error: true);
      return;
    }
    AppLogger.info(
      'Person profile opening order flow: personId=${p.id}, isWholesaler=${p.isWholesaler}',
    );
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => p.isWholesaler
            ? CustomerOrderBuilderScreen(person: p)
            : ShopScreen(
                initialWholesalerId: p.id,
                initialWholesalerName: p.displayName),
      ),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _openWhatsApp(ConnectionDetails p) async {
    if (!await ContactUtils.openWhatsApp(p.telNo)) {
      _snack('WhatsApp için geçerli telefon numarası bulunamadı.', error: true);
    }
  }

  Future<void> _openRoute(ConnectionDetails p) async {
    if (!await ContactUtils.openDirections(
        latitude: p.latitude,
        longitude: p.longitude,
        query: p.addressAsString)) {
      _snack('Rota açmak için konum bilgisi bulunamadı.', error: true);
    }
  }

  Future<void> _export(_Payload payload) async {
    AppLogger.info(
      'Person profile statement export requested: personId=${payload.person.id}, transactionCount=${payload.transactions.length}',
    );
    if (payload.transactions.isEmpty) {
      _snack('Bu kişi için finansal işlem bulunmuyor.', error: true);
      return;
    }
    final request = await showModalBottomSheet<StatementExportRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StatementSheet(
          availableTypes: availableTransactionTypes(payload.transactions)),
    );
    if (request == null) return;
    try {
      final result = await StatementPdfService().createAndSave(
        person: payload.person,
        transactions: payload.transactions,
        request: request,
      );
      if (result == null) {
        _snack('PDF kaydetme iptal edildi.', error: true);
      } else {
        AppLogger.info(
          'Person profile statement export completed: personId=${payload.person.id}, location=${result.locationLabel}',
        );
        _snack('PDF kaydedildi: ${result.locationLabel}');
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Person profile statement export failed: personId=${payload.person.id}',
        e,
        stackTrace,
      );
      _snack('PDF oluşturulamadı: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Payload>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (s.hasError || !s.hasData) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(
                  child: Text('Hata: ${s.error ?? 'Kayıt bulunamadı.'}')));
        }
        final payload = s.data!;
        final p = payload.person;
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: NestedScrollView(
                headerSliverBuilder: (c, inner) => [
                  SliverAppBar(
                    expandedHeight: 180,
                    pinned: true,
                    forceElevated: inner,
                    actions: [
                      if (p.canEdit)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            final changed =
                                await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ExternalUserEditScreen(user: p)),
                            );
                            if (changed == true) await _refresh();
                          },
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      title: _header(p),
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primaryContainer,
                              Theme.of(context).colorScheme.secondaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _actions(payload))),
                  const SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarHeader(
                      TabBar(
                        tabs: [
                          Tab(text: 'Genel Bakış'),
                          Tab(text: 'Finans'),
                          Tab(text: 'Siparişler'),
                          Tab(text: 'Aktiviteler'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _overview(p),
                    payload.transactions.isEmpty
                        ? _empty('Bu kişiyle finansal işlem bulunmuyor.')
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: payload.transactions.length,
                            itemBuilder: (_, i) => FinancialTransactionCard(
                                transaction: payload.transactions[i]),
                          ),
                    _orders(payload.orders, p),
                    _empty('Aktivite akışı henüz bağlanmadı.'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(ConnectionDetails p) => Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: p.profilFotografi != null
              ? NetworkImage(ImageService.getFullImageUrl(p.profilFotografi))
              : null,
          child: p.profilFotografi == null ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip(p.scope),
                  ...p.roles.take(2).map(_chip),
                ]),
              ]),
        ),
      ]);

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  Widget _actions(_Payload payload) {
    final p = payload.person;
    final items = [
      _ActionItem(
          Icons.auto_awesome_outlined,
          'Analiz+',
          Colors.deepPurple,
          () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AnalysisHubScreen(
                    userId: p.id,
                    userDisplayName: p.displayName,
                  )))),
      _ActionItem(
          Icons.alt_route_rounded, 'Rota', Colors.indigo, () => _openRoute(p)),
      _ActionItem(Icons.shopping_cart_outlined, 'Sipariş', Colors.blue,
          () => _openOrder(p)),
      _ActionItem(Icons.sell_outlined, 'Etiket', Colors.amber.shade800,
          () => _openTags(p)),
      _ActionItem(Icons.account_balance_wallet_outlined, 'Finansal İşlem',
          Colors.teal, () => _openFinancial(p)),
      _ActionItem(Icons.picture_as_pdf_outlined, 'Ekstre PDF',
          Colors.red.shade700, () => _export(payload)),
      _ActionItem(Icons.chat_rounded, 'WhatsApp', Colors.green.shade700,
          () => _openWhatsApp(p)),
    ];
    return LayoutBuilder(builder: (c, box) {
      final cols = box.maxWidth > 720 ? 4 : 2;
      final width = (box.maxWidth - ((cols - 1) * 10)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map((i) => SizedBox(width: width, child: _ActionCard(item: i)))
            .toList(),
      );
    });
  }

  Widget _overview(ConnectionDetails p) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
              child: ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Telefon'),
            subtitle: Text(p.telNo ?? 'Belirtilmemiş'),
            onTap: p.telNo == null
                ? null
                : () async {
                    if (!await ContactUtils.openPhoneDialer(p.telNo)) {
                      _snack('Arama başlatılamadı.', error: true);
                    }
                  },
            trailing: p.telNo == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.copy_all_outlined),
                    onPressed: () async {
                      await ContactUtils.copyToClipboard(p.telNo!);
                      _snack('Telefon numarası kopyalandı.');
                    },
                  ),
          )),
          if (p.email != null && p.email!.isNotEmpty)
            Card(
                child: ListTile(
              leading: const Icon(Icons.alternate_email_outlined),
              title: const Text('E-posta'),
              subtitle: Text(p.email!),
            )),
          Card(
              child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Adres'),
            subtitle: Text(p.addressAsString),
          )),
          Card(
              child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Roller'),
            subtitle: Text(p.roles.join(', ')),
          )),
          Card(
            child: InkWell(
              onTap: () => _openTags(p),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.sell_outlined),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Text('Etiketler',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                        Icon(Icons.chevron_right_rounded,
                            color: Theme.of(context).colorScheme.primary),
                      ]),
                      const SizedBox(height: 12),
                      if (p.tags.isEmpty)
                        const Text(
                            'Henüz etiket yok. Dokunarak ekleyebilirsiniz.')
                      else
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: p.tags
                                .map((t) => Chip(
                                    label: Text(t.name),
                                    visualDensity: VisualDensity.compact))
                                .toList()),
                    ]),
              ),
            ),
          ),
        ],
      );

  Widget _orders(List<Cart> orders, ConnectionDetails p) {
    if (p.scope != 'Dahili') {
      return _empty(
          'Sipariş akışı yalnızca dahili kullanıcılar için kullanılabiliyor.');
    }
    if (orders.isEmpty) return _empty('Bu kişiyle ilgili sipariş bulunmuyor.');
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final cart = orders[i];
        final status = OrderStatus.values.firstWhere(
            (e) => e.name == cart.status,
            orElse: () => OrderStatus.ordered);
        return OrderCard(
          cart: cart,
          perspective: p.isWholesaler
              ? CardPerspective.wholesaler
              : CardPerspective.customer,
          actionButtons: p.isWholesaler ? _orderActions(cart, status) : null,
          onTap: p.isWholesaler
              ? () async {
                  final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                          builder: (_) =>
                              WholesalerOrderEditScreen(cartId: cart.cartId)));
                  if (changed == true) await _refresh();
                }
              : null,
        );
      },
    );
  }

  List<Widget> _orderActions(Cart cart, OrderStatus status) {
    final provider = context.read<WholesalerOrderProvider>();
    Future<void> run(Future<void> Function() action, String ok) async {
      try {
        await action();
        _snack(ok);
        await _refresh();
      } catch (e) {
        _snack('Hata: $e', error: true);
      }
    }

    final buttons = <Widget>[];
    if (status == OrderStatus.ordered) {
      buttons.add(Expanded(
          child: ElevatedButton.icon(
              onPressed: () => _confirm(
                  title: 'Siparişi Onayla',
                  content: 'Siparişi hazırlığa almak istiyor musunuz?',
                  actionText: 'Onayla',
                  onConfirm: (_) => run(() => provider.confirmSale(cart.cartId),
                      'Sipariş onaylandı.')),
              icon: const Icon(Icons.check),
              label: const Text('Onayla'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white))));
    }
    if (status == OrderStatus.preparing) {
      buttons.add(Expanded(
          child: ElevatedButton.icon(
              onPressed: () => _confirm(
                  title: 'Kargoya Ver',
                  content: 'Siparişi kargoya vermek istiyor musunuz?',
                  actionText: 'Kargoya Ver',
                  onConfirm: (_) => run(
                      () => provider.updateOrderStatus(cart.cartId, 'shipped',
                          createTransaction: false),
                      'Sipariş kargoya verildi.')),
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Kargoya Ver'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white))));
    }
    if (status == OrderStatus.shipped) {
      buttons.add(Expanded(
          child: ElevatedButton.icon(
              onPressed: () => _confirm(
                  title: 'Teslim Edildi',
                  content: 'Sipariş teslim edildi mi?',
                  actionText: 'Teslim Et',
                  showTransactionSwitch: true,
                  onConfirm: (o) => run(
                      () => provider.updateOrderStatus(cart.cartId, 'delivered',
                          createTransaction: o['createTransaction']),
                      'Sipariş teslim edildi.')),
              icon: const Icon(Icons.delivery_dining_outlined),
              label: const Text('Teslim Et'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white))));
    }
    if (status == OrderStatus.ordered ||
        status == OrderStatus.preparing ||
        status == OrderStatus.shipped) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 8));
      buttons.add(IconButton(
          icon: Icon(Icons.cancel_outlined, color: Colors.red.shade700),
          onPressed: () => _confirm(
              title: 'Siparişi İptal Et',
              content: 'Bu siparişi iptal etmek istediğinizden emin misiniz?',
              actionText: 'İptal Et',
              onConfirm: (_) => run(
                  () => provider.updateOrderStatus(cart.cartId, 'cancelled',
                      createTransaction: false),
                  'Sipariş iptal edildi.'))));
    }
    return buttons;
  }

  void _confirm(
      {required String title,
      required String content,
      required String actionText,
      required Function(Map<String, dynamic>) onConfirm,
      bool showTransactionSwitch = false}) {
    bool createTransaction = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
            builder: (_, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content),
                      if (showTransactionSwitch)
                        SwitchListTile(
                          title: const Text('Finansal işlem oluştur'),
                          subtitle: const Text(
                              'Teslimatla birlikte satış kaydı da açılsın.'),
                          value: createTransaction,
                          onChanged: (v) =>
                              setState(() => createTransaction = v),
                        ),
                    ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal')),
          ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onConfirm({'createTransaction': createTransaction});
              },
              child: Text(actionText)),
        ],
      ),
    );
  }

  Widget _empty(String text) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Center(
            child: Text(text,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center))
      ]);
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem(this.icon, this.label, this.color, this.onTap);
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;
  const _ActionCard({required this.item});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(item.label,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      );
}

class _StatementSheet extends StatefulWidget {
  final List<DisplayTransactionType> availableTypes;
  const _StatementSheet({required this.availableTypes});

  @override
  State<_StatementSheet> createState() => _StatementSheetState();
}

class _StatementSheetState extends State<_StatementSheet> {
  late Set<DisplayTransactionType> _types;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _types = widget.availableTypes.toSet();
  }

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final date = await showDatePicker(
        context: context,
        initialDate: current ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current ?? DateTime.now()));
    if (time == null) return;
    final result =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => start ? _start = result : _end = result);
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + inset),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ekstre PDF',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'İşlem türlerini ve tarih aralığını seçin. Sonraki adımda kaydetme yeri sorulacak.'),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.availableTypes
                      .map((t) => FilterChip(
                            selected: _types.contains(t),
                            avatar: Icon(transactionTypeIcon(t), size: 18),
                            label: Text(transactionTypeLabel(t)),
                            onSelected: (v) => setState(
                                () => v ? _types.add(t) : _types.remove(t)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_start == null
                            ? 'Başlangıç tarihi seçin'
                            : f.format(_start!))),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        alignment: Alignment.centerLeft)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_end == null
                            ? 'Bitiş tarihi seçin'
                            : f.format(_end!))),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        alignment: Alignment.centerLeft)),
                TextButton(
                    onPressed: () => setState(() {
                          _start = null;
                          _end = null;
                        }),
                    child: const Text('Tarih filtresini temizle')),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _types.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(
                            StatementExportRequest(
                                selectedTypes: _types,
                                startDate: _start,
                                endDate: _end)),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF Oluştur ve Kaydet'),
                  ),
                ),
              ]),
        ),
      ),
    );
  }
}
