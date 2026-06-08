import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend/models/cart.dart';
import 'package:frontend/models/connection.dart';
import 'package:frontend/models/connection_details.dart';
import 'package:frontend/models/financial_transaction.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/transaction_provider.dart';
import 'package:frontend/providers/wholesaler_order_provider.dart';
import 'package:frontend/screens/map_picker_screen.dart';
import 'package:frontend/services/user_service.dart';
import 'package:frontend/utils/business_metrics.dart';
import 'package:frontend/utils/contact_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const double _averageSpeedKmh = 38;
  static const double _stopMinutes = 12;
  static const double _fuelLitersPer100Km = 10.5;
  static const double _fuelPricePerLiter = 46;

  final UserService _userService = UserService();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final DateFormat _dateFormat = DateFormat('d MMMM EEEE', 'tr_TR');

  bool _isLoading = true;
  String? _error;
  _DashboardBundle? _bundle;
  String? _selectedTagId;
  String? _selectedTagName;
  final Set<String> _excludedRelationIds = <String>{};
  final Map<String, _StopProgress> _progressByRelationId =
      <String, _StopProgress>{};
  LatLng? _liveStartLocation;
  LatLng? _manualStartLocation;
  bool _isResolvingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token == null || token.isEmpty) {
        throw Exception('Oturum bulunamadı.');
      }

      final connectionProvider = context.read<ConnectionProvider>();
      final transactionProvider = context.read<TransactionProvider>();
      final orderProvider = context.read<WholesalerOrderProvider>();
      final productProvider = context.read<ProductProvider>();

      await Future.wait([
        connectionProvider.fetchConnections(),
        transactionProvider.fetchAllFinancialData(),
        orderProvider.fetchWholesalerOrders(),
        productProvider.fetchProducts(),
      ]);

      final rawConnections = connectionProvider.allConnections
          .where((item) => item.relationRole == 'customer')
          .toList();
      final connections = rawConnections.isNotEmpty
          ? rawConnections
          : connectionProvider.allConnections;

      final details = await Future.wait(
        connections.map((connection) async {
          try {
            return await connectionProvider
                .fetchConnectionDetails(connection.relationId);
          } catch (_) {
            return null;
          }
        }),
      );

      final profile = await _userService.getProfile();
      final variantIndex = buildVariantMetricsIndex(productProvider.products);

      final stops = <_DashboardStop>[];
      for (var i = 0; i < connections.length; i++) {
        final detail = details[i];
        if (detail == null) {
          continue;
        }

        final relatedOrders = orderProvider.orders
            .where(
              (order) =>
                  order.customerId == detail.id &&
                  _isRouteRelevantStatus(order.status),
            )
            .toList();

        final partnerTransactions = transactionProvider.transactions
            .where((transaction) => transaction.partnerId == detail.id)
            .toList();

        final sales = partnerTransactions
            .where((tx) => tx.displayType == DisplayTransactionType.satis)
            .fold<double>(
              0,
              (sum, tx) => sum + (isApprovedTransaction(tx) ? tx.amount : 0),
            );
        final collections = partnerTransactions
            .where((tx) => tx.displayType == DisplayTransactionType.tahsilat)
            .fold<double>(
              0,
              (sum, tx) => sum + (isApprovedTransaction(tx) ? tx.amount : 0),
            );

        stops.add(
          _DashboardStop(
            connection: connections[i],
            details: detail,
            relatedOrders: relatedOrders,
            plannedSales: relatedOrders.fold<double>(
              0,
              (sum, cart) => sum + cart.totalAmount,
            ),
            estimatedProfit: relatedOrders.fold<double>(
              0,
              (sum, cart) => sum + estimateCartProfit(cart, variantIndex),
            ),
            estimatedCollection: math.max(0, sales - collections),
            location: detail.latitude != null && detail.longitude != null
                ? LatLng(detail.latitude!, detail.longitude!)
                : null,
          ),
        );
      }

      final bundle = _DashboardBundle(
        profile: profile,
        stops: stops,
        variantIndex: variantIndex,
      );
      final availableTags = _collectTags(bundle.stops);
      final matchingTodayTag = _findTodayTag(availableTags);

      if (!mounted) {
        return;
      }

      setState(() {
        _bundle = bundle;
        if (_selectedTagId != null &&
            !availableTags.any((tag) => tag.tagId == _selectedTagId)) {
          _selectedTagId = null;
          _selectedTagName = null;
        }
        if (_selectedTagId == null && matchingTodayTag != null) {
          _selectedTagId = matchingTodayTag.tagId;
          _selectedTagName = matchingTodayTag.name;
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  bool _isRouteRelevantStatus(String status) {
    return const {'active', 'ordered', 'preparing', 'shipped'}.contains(status);
  }

  List<Tag> _collectTags(List<_DashboardStop> stops) {
    final bucket = <String, Tag>{};
    for (final stop in stops) {
      for (final tag in stop.details.tags) {
        bucket[tag.tagId] = tag;
      }
    }
    final items = bucket.values.toList();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Tag? _findTodayTag(List<Tag> availableTags) {
    const weekdayNames = <String>[
      'pazartesi',
      'sali',
      'çarşamba',
      'carsamba',
      'perşembe',
      'persembe',
      'cuma',
      'cumartesi',
      'pazar',
    ];
    final today = weekdayNames[DateTime.now().weekday - 1];
    for (final tag in availableTags) {
      if (_normalize(tag.name) == _normalize(today)) {
        return tag;
      }
    }
    return null;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }

  LatLng? get _profileLocation {
    final profile = _bundle?.profile;
    final latitude = (profile?['latitude'] as num?)?.toDouble();
    final longitude = (profile?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  LatLng? get _startLocation =>
      _liveStartLocation ?? _manualStartLocation ?? _profileLocation;

  String get _startLocationLabel {
    if (_liveStartLocation != null) return 'Canlı cihaz konumu';
    if (_manualStartLocation != null) return 'Elle seçilen rota başlangıcı';
    if (_profileLocation != null) {
      return 'Profil konumu başlangıç olarak kullanılıyor';
    }
    return 'Başlangıç konumu seçilmedi';
  }

  List<_DashboardStop> get _filteredStops {
    final bundle = _bundle;
    if (bundle == null) return const <_DashboardStop>[];

    Iterable<_DashboardStop> stops = bundle.stops;
    if (_selectedTagId != null) {
      stops = stops.where(
        (stop) => stop.details.tags.any((tag) => tag.tagId == _selectedTagId),
      );
    }
    stops = stops.where(
      (stop) => !_excludedRelationIds.contains(stop.details.relationId),
    );
    return _routeOrderedStops(stops.toList());
  }

  List<_DashboardStop> _routeOrderedStops(List<_DashboardStop> stops) {
    final withLocation = stops.where((stop) => stop.location != null).toList();
    final withoutLocation =
        stops.where((stop) => stop.location == null).toList();

    if (withLocation.length <= 1) {
      return [...withLocation, ...withoutLocation];
    }

    final ordered = <_DashboardStop>[];
    final pool = List<_DashboardStop>.from(withLocation);
    var current = _startLocation ?? pool.removeAt(0).location!;

    while (pool.isNotEmpty) {
      pool.sort(
        (a, b) => _distanceBetween(current, a.location!).compareTo(
          _distanceBetween(current, b.location!),
        ),
      );
      final next = pool.removeAt(0);
      ordered.add(next);
      current = next.location!;
    }

    return [...ordered, ...withoutLocation];
  }

  double _degreesToRadians(double degree) => degree * math.pi / 180;

  double _distanceBetween(LatLng from, LatLng to) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(to.latitude - from.latitude);
    final dLng = _degreesToRadians(to.longitude - from.longitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_degreesToRadians(from.latitude)) *
            math.cos(_degreesToRadians(to.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a as num), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double get _routeDistanceKm {
    final route =
        _filteredStops.where((stop) => stop.location != null).toList();
    if (route.isEmpty) {
      return 0;
    }

    var total = 0.0;
    var current = _startLocation;
    for (final stop in route) {
      if (current != null) {
        total += _distanceBetween(current, stop.location!);
      }
      current = stop.location!;
    }
    return total;
  }

  double get _travelMinutes {
    final pureTravel = (_routeDistanceKm / _averageSpeedKmh) * 60;
    return pureTravel + (_filteredStops.length * _stopMinutes);
  }

  double get _fuelLiters => _routeDistanceKm * (_fuelLitersPer100Km / 100);

  double get _fuelCost => _fuelLiters * _fuelPricePerLiter;

  double get _plannedSales =>
      _filteredStops.fold<double>(0, (sum, stop) => sum + stop.plannedSales);

  double get _estimatedProfit =>
      _filteredStops.fold<double>(0, (sum, stop) => sum + stop.estimatedProfit);

  double get _estimatedCollection => _filteredStops.fold<double>(
        0,
        (sum, stop) => sum + stop.estimatedCollection,
      );

  double get _actualSales => _filteredStops.fold<double>(
        0,
        (sum, stop) =>
            sum +
            (_progressByRelationId[stop.details.relationId]?.actualSales ?? 0),
      );

  double get _actualCollections => _filteredStops.fold<double>(
        0,
        (sum, stop) =>
            sum +
            (_progressByRelationId[stop.details.relationId]?.actualCollection ??
                0),
      );

  int get _visitedCount => _filteredStops
      .where(
        (stop) =>
            _progressByRelationId[stop.details.relationId]?.visited == true,
      )
      .length;

  List<DemandItemMetrics> get _loadList {
    final bundle = _bundle;
    if (bundle == null) {
      return const <DemandItemMetrics>[];
    }
    final carts = _filteredStops.expand((stop) => stop.relatedOrders).toList();
    return buildDemandMetrics(carts, bundle.variantIndex);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isResolvingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisi kapalı.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni verilmedi.');
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) {
        return;
      }
      setState(() {
        _liveStartLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Canlı konum alınamadı: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  Future<void> _pickManualLocation() async {
    final initial =
        _manualStartLocation ?? _liveStartLocation ?? _profileLocation;
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: initial),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _manualStartLocation = selected;
      _liveStartLocation = null;
    });
  }

  void _clearExclusions() {
    setState(() => _excludedRelationIds.clear());
  }

  Future<void> _openProgressSheet(_DashboardStop stop) async {
    final previous =
        _progressByRelationId[stop.details.relationId] ?? const _StopProgress();
    final saleController = TextEditingController(
      text: previous.actualSales > 0
          ? previous.actualSales.toStringAsFixed(0)
          : '',
    );
    final collectionController = TextEditingController(
      text: previous.actualCollection > 0
          ? previous.actualCollection.toStringAsFixed(0)
          : '',
    );
    final noteController = TextEditingController(text: previous.note);
    var visited = previous.visited;

    final result = await showModalBottomSheet<_StopProgress>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stop.details.displayName} güncellemesi',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bugünkü gerçekleşmeleri işleyin. Dashboard kalan satış ve tahsilatı anında günceller.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bu müşteriye uğradım'),
                    value: visited,
                    onChanged: (value) => setModalState(() => visited = value),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: saleController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Gerçekleşen satış',
                            helperText:
                                'Plan: ${_currency.format(stop.plannedSales)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: collectionController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Gerçekleşen tahsilat',
                            helperText:
                                'Plan: ${_currency.format(stop.estimatedCollection)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Not',
                      hintText:
                          'Örn. Tahsilat yarına kaldı, sipariş revize edildi.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          saleController.text =
                              stop.plannedSales.toStringAsFixed(0);
                          collectionController.text =
                              stop.estimatedCollection.toStringAsFixed(0);
                        },
                        child: const Text('Planı Doldur'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _StopProgress(
                              visited: visited,
                              actualSales:
                                  double.tryParse(saleController.text) ?? 0,
                              actualCollection:
                                  double.tryParse(collectionController.text) ??
                                      0,
                              note: noteController.text.trim(),
                            ),
                          );
                        },
                        child: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    saleController.dispose();
    collectionController.dispose();
    noteController.dispose();

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _progressByRelationId[stop.details.relationId] = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadDashboard,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHero(),
                      const SizedBox(height: 16),
                      _buildTagFilters(),
                      const SizedBox(height: 16),
                      _buildLocationControls(),
                      const SizedBox(height: 16),
                      _buildKpiGrid(),
                      const SizedBox(height: 16),
                      _buildRouteCard(),
                      const SizedBox(height: 16),
                      _buildLoadCard(),
                      const SizedBox(height: 16),
                      _buildProgressCard(),
                      const SizedBox(height: 16),
                      _buildStopsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHero() {
    final visibleStops = _filteredStops.length;
    final totalStops = _bundle?.stops.length ?? 0;
    final todayLabel = _selectedTagName ?? 'Tüm müşteriler';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugünkü saha planı',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _dateFormat.format(DateTime.now()),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroPill('Filtre', todayLabel),
              _heroPill('Görünen durak', '$visibleStops / $totalStops'),
              _heroPill('Ziyaret tamamlanan', '$_visitedCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilters() {
    final tags = _bundle == null ? const <Tag>[] : _collectTags(_bundle!.stops);
    return _SectionCard(
      title: 'Gün filtresi',
      subtitle:
          'Etikete göre bugünkü müşterileri alın. Görünen müşterileri o günkü plandan hariç bırakabilirsiniz.',
      action: _excludedRelationIds.isEmpty
          ? null
          : TextButton.icon(
              onPressed: _clearExclusions,
              icon: const Icon(Icons.undo),
              label: Text(
                  'Hariç tutulanları geri al (${_excludedRelationIds.length})'),
            ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Tümü'),
            selected: _selectedTagId == null,
            onSelected: (_) {
              setState(() {
                _selectedTagId = null;
                _selectedTagName = null;
              });
            },
          ),
          ...tags.map(
            (tag) => ChoiceChip(
              label: Text(tag.name),
              selected: _selectedTagId == tag.tagId,
              onSelected: (_) {
                setState(() {
                  _selectedTagId = tag.tagId;
                  _selectedTagName = tag.name;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationControls() {
    return _SectionCard(
      title: 'Başlangıç ve rota kontrolü',
      subtitle:
          'Canlı cihaz konumunuzu kullanabilir veya haritadan manuel başlangıç seçebilirsiniz.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _isResolvingLocation ? null : _useCurrentLocation,
                icon: _isResolvingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Canlı konumu kullan'),
              ),
              OutlinedButton.icon(
                onPressed: _pickManualLocation,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Haritadan başlangıç seç'),
              ),
              if (_liveStartLocation != null || _manualStartLocation != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _liveStartLocation = null;
                      _manualStartLocation = null;
                    });
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Sıfırla'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.route, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(_startLocationLabel)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    final items = [
      _DashboardMetric(
        'Bugünkü satış planı',
        _currency.format(_plannedSales),
        Icons.sell_outlined,
        Colors.blue,
      ),
      _DashboardMetric(
        'Tahmini tahsilat',
        _currency.format(_estimatedCollection),
        Icons.payments_outlined,
        Colors.green,
      ),
      _DashboardMetric(
        'Tahmini brüt kazanç',
        _currency.format(_estimatedProfit),
        Icons.trending_up_outlined,
        Colors.deepPurple,
      ),
      _DashboardMetric(
        'Yolda harcanacak süre',
        '${_travelMinutes.toStringAsFixed(0)} dk',
        Icons.schedule_outlined,
        Colors.orange,
      ),
      _DashboardMetric(
        'Yakıt tüketimi',
        '${_fuelLiters.toStringAsFixed(1)} lt',
        Icons.local_gas_station_outlined,
        Colors.redAccent,
      ),
      _DashboardMetric(
        'Yakıt maliyeti',
        _currency.format(_fuelCost),
        Icons.receipt_long_outlined,
        Colors.brown,
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    final cardWidth = width > 980
        ? (width - 72) / 3
        : width > 640
            ? (width - 60) / 2
            : double.infinity;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map((item) =>
              SizedBox(width: cardWidth, child: _MetricCard(item: item)))
          .toList(),
    );
  }

  Widget _buildRouteCard() {
    final routeStops =
        _filteredStops.where((stop) => stop.location != null).toList();
    final start = _startLocation;
    final markers = <Marker>{};
    final polylinePoints = <LatLng>[];

    if (start != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: start,
          infoWindow: const InfoWindow(title: 'Başlangıç'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
      polylinePoints.add(start);
    }

    for (final stop in routeStops) {
      final progress = _progressByRelationId[stop.details.relationId];
      markers.add(
        Marker(
          markerId: MarkerId(stop.details.relationId),
          position: stop.location!,
          infoWindow: InfoWindow(
            title: stop.details.displayName,
            snippet: stop.details.addressAsString,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            progress?.visited == true
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueOrange,
          ),
        ),
      );
      polylinePoints.add(stop.location!);
    }

    return _SectionCard(
      title: 'Google Maps rota görünümü',
      subtitle:
          'Pinler bugünkü durakları gösterir. Çizgi, en yakın durak mantığıyla tahmini operasyon sırasını verir.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (routeStops.isEmpty)
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: const Text('Harita için konumlu müşteri bulunmuyor.'),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 300,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: start ?? routeStops.first.location!,
                    zoom: 10.5,
                  ),
                  markers: markers,
                  polylines: {
                    if (polylinePoints.length > 1)
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: polylinePoints,
                        color: Theme.of(context).colorScheme.primary,
                        width: 5,
                      ),
                  },
                  myLocationEnabled: _liveStartLocation != null,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: true,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _miniMetric('Durak', '${_filteredStops.length}'),
              _miniMetric('Haritalı durak', '${routeStops.length}'),
              _miniMetric(
                  'Mesafe', '${_routeDistanceKm.toStringAsFixed(1)} km'),
              _miniMetric('Süre', '${_travelMinutes.toStringAsFixed(0)} dk'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadCard() {
    final loadItems = _loadList;
    return _SectionCard(
      title: 'Araca yüklenecek ürünler',
      subtitle:
          'Bugünkü açık siparişlerden türetilen yükleme listesi. Hangi raftan kaç adet alınacağını önden görürsünüz.',
      child: loadItems.isEmpty
          ? const Text('Seçili grupta yüklemeye konu açık sipariş bulunmuyor.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Ürün')),
                  DataColumn(label: Text('Varyant')),
                  DataColumn(label: Text('Raf')),
                  DataColumn(label: Text('Adet')),
                  DataColumn(label: Text('Durak')),
                  DataColumn(label: Text('Stok')),
                ],
                rows: loadItems
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.productName)),
                          DataCell(Text(item.variantName)),
                          DataCell(Text(item.shelfLocation)),
                          DataCell(Text(item.quantity.toString())),
                          DataCell(Text(item.stopCount.toString())),
                          DataCell(
                            Text(
                              item.availableStock.toString(),
                              style: TextStyle(
                                color: item.availableStock < item.quantity
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  Widget _buildProgressCard() {
    final remainingSales = math.max(0, _plannedSales - _actualSales);
    final remainingCollection =
        math.max(0, _estimatedCollection - _actualCollections);

    return _SectionCard(
      title: 'Gün içi operasyon güncellemesi',
      subtitle:
          'Canlı veya manuel işlediğiniz ziyaretler burada birikir. Ne kadar iş kaldığını anlık görürsünüz.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _ProgressSummaryCard(
            title: 'Tamamlanan ziyaret',
            value: '$_visitedCount / ${_filteredStops.length}',
            caption: 'Bugün uğradığınız müşteri sayısı',
            color: Colors.green,
          ),
          _ProgressSummaryCard(
            title: 'Gerçekleşen satış',
            value: _currency.format(_actualSales),
            caption: 'Kalan: ${_currency.format(remainingSales)}',
            color: Colors.blue,
          ),
          _ProgressSummaryCard(
            title: 'Gerçekleşen tahsilat',
            value: _currency.format(_actualCollections),
            caption: 'Kalan: ${_currency.format(remainingCollection)}',
            color: Colors.deepOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildStopsSection() {
    final stops = _filteredStops;
    return _SectionCard(
      title: 'Bugünkü müşterilerim',
      subtitle:
          'Müşteri kartlarından rota, filtre dışı bırakma ve gün içi gerçekleşme kontrolünü yapabilirsiniz.',
      child: stops.isEmpty
          ? const Text(
              'Seçili etikete ve hariç tutma ayarlarına göre görüntülenecek müşteri yok.',
            )
          : Column(
              children: stops
                  .map(
                    (stop) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildStopCard(stop),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildStopCard(_DashboardStop stop) {
    final progress =
        _progressByRelationId[stop.details.relationId] ?? const _StopProgress();
    final distanceFromStart = stop.location != null && _startLocation != null
        ? _distanceBetween(_startLocation!, stop.location!)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: progress.visited
              ? Colors.green.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.details.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stop.details.addressAsString,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(progress.visited ? 'Uğrandı' : 'Planlandı'),
                avatar: Icon(
                  progress.visited ? Icons.check_circle : Icons.schedule,
                  size: 18,
                  color: progress.visited ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          if (stop.details.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stop.details.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag.name,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StopInfoItem(
                label: 'Satış planı',
                value: _currency.format(stop.plannedSales),
                icon: Icons.sell_outlined,
              ),
              _StopInfoItem(
                label: 'Tahsilat potansiyeli',
                value: _currency.format(stop.estimatedCollection),
                icon: Icons.payments_outlined,
              ),
              _StopInfoItem(
                label: 'Tahmini kâr',
                value: _currency.format(stop.estimatedProfit),
                icon: Icons.trending_up_outlined,
              ),
              _StopInfoItem(
                label: 'Açık sipariş',
                value: stop.relatedOrders.length.toString(),
                icon: Icons.shopping_bag_outlined,
              ),
              if (distanceFromStart != null)
                _StopInfoItem(
                  label: 'Başlangıca mesafe',
                  value: '${distanceFromStart.toStringAsFixed(1)} km',
                  icon: Icons.route_outlined,
                ),
            ],
          ),
          if (progress.note.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              progress.note,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _openProgressSheet(stop),
                icon: const Icon(Icons.edit_note),
                label:
                    Text(progress.visited ? 'Güncelle' : 'Uğradım / Güncelle'),
              ),
              OutlinedButton.icon(
                onPressed: stop.location == null
                    ? null
                    : () => ContactUtils.openDirections(
                          latitude: stop.location!.latitude,
                          longitude: stop.location!.longitude,
                          query: stop.details.addressAsString,
                        ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Haritada aç'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _excludedRelationIds.add(stop.details.relationId);
                  });
                },
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Filtre dışı bırak'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardBundle {
  final Map<String, dynamic> profile;
  final List<_DashboardStop> stops;
  final Map<String, VariantMetrics> variantIndex;

  const _DashboardBundle({
    required this.profile,
    required this.stops,
    required this.variantIndex,
  });
}

class _DashboardStop {
  final Connection connection;
  final ConnectionDetails details;
  final List<Cart> relatedOrders;
  final double plannedSales;
  final double estimatedProfit;
  final double estimatedCollection;
  final LatLng? location;

  const _DashboardStop({
    required this.connection,
    required this.details,
    required this.relatedOrders,
    required this.plannedSales,
    required this.estimatedProfit,
    required this.estimatedCollection,
    required this.location,
  });
}

class _StopProgress {
  final bool visited;
  final double actualSales;
  final double actualCollection;
  final String note;

  const _StopProgress({
    this.visited = false,
    this.actualSales = 0,
    this.actualCollection = 0,
    this.note = '',
  });
}

class _DashboardMetric {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardMetric(this.title, this.value, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final _DashboardMetric item;

  const _MetricCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(height: 14),
          Text(
            item.title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ProgressSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final Color color;

  const _ProgressSummaryCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(caption),
        ],
      ),
    );
  }
}

class _StopInfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StopInfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
