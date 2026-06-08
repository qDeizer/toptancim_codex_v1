import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_settings.dart';
import '../providers/auth_provider.dart';
import '../services/ai_settings_service.dart';
import '../utils/logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AiSettingsService _service = AiSettingsService();
  final TextEditingController _geminiModelController = TextEditingController();
  final TextEditingController _chatResetSecondsController =
      TextEditingController();
  final TextEditingController _chatRequestTimeoutController =
      TextEditingController();
  final TextEditingController _localBaseUrlController = TextEditingController();
  final TextEditingController _localModelController = TextEditingController();
  final TextEditingController _localTimeoutController = TextEditingController();
  final TextEditingController _localTokenController = TextEditingController();
  final TextEditingController _mlServiceBaseUrlController =
      TextEditingController();
  final TextEditingController _mlServiceTimeoutController =
      TextEditingController();
  final Map<String, TextEditingController> _providerKeyControllers = {};

  AiSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _geminiModelController.dispose();
    _chatResetSecondsController.dispose();
    _chatRequestTimeoutController.dispose();
    _localBaseUrlController.dispose();
    _localModelController.dispose();
    _localTimeoutController.dispose();
    _localTokenController.dispose();
    _mlServiceBaseUrlController.dispose();
    _mlServiceTimeoutController.dispose();
    for (final controller in _providerKeyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      AppLogger.warning('Settings screen load blocked due to missing auth');
      setState(() {
        _error = 'Oturum bilgisi bulunamadi.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      AppLogger.info('Settings screen load started');
      final settings = await _service.fetchSettings(token);
      _applySettings(settings);
      AppLogger.info('Settings screen load completed');
    } catch (error, stackTrace) {
      AppLogger.error('Settings screen load failed', error, stackTrace);
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applySettings(AiSettings settings) {
    AppLogger.debug(
      'Settings screen applying settings: strategy=${settings.strategy}, providerCount=${settings.providers.length}',
    );
    _settings = settings;
    _geminiModelController.text = settings.geminiModel;
    _chatResetSecondsController.text = settings.chatResetSeconds.toString();
    _chatRequestTimeoutController.text =
        settings.chatRequestTimeoutMs.toString();
    _mlServiceBaseUrlController.text = settings.mlService.baseUrl;
    _mlServiceTimeoutController.text = settings.mlService.timeoutMs.toString();
    _localBaseUrlController.text = settings.localProvider.baseUrl;
    _localModelController.text = settings.localProvider.model;
    _localTimeoutController.text = settings.localProvider.timeoutMs.toString();
    _localTokenController.text = settings.localProvider.apiToken;

    for (final provider in settings.providers) {
      _providerKeyControllers
          .putIfAbsent(
            provider.id,
            () => TextEditingController(text: provider.apiKey),
          )
          .text = provider.apiKey;
    }

    setState(() {});
  }

  Future<void> _save() async {
    if (_settings == null) {
      AppLogger.warning(
          'Settings screen save ignored because settings are null');
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      AppLogger.warning('Settings screen save blocked due to missing auth');
      setState(() {
        _error = 'Oturum bilgisi bulunamadi.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final updatedSettings = _settings!.copyWith(
      geminiModel: _geminiModelController.text.trim(),
      chatResetSeconds:
          int.tryParse(_chatResetSecondsController.text.trim()) ?? 15,
      chatRequestTimeoutMs:
          int.tryParse(_chatRequestTimeoutController.text.trim()) ?? 95000,
      providers: _settings!.providers
          .map(
            (provider) => provider.copyWith(
              apiKey: _providerKeyControllers[provider.id]?.text.trim() ?? '',
            ),
          )
          .toList(),
      mlService: _settings!.mlService.copyWith(
        baseUrl: _mlServiceBaseUrlController.text.trim(),
        timeoutMs:
            int.tryParse(_mlServiceTimeoutController.text.trim()) ?? 120000,
      ),
      localProvider: _settings!.localProvider.copyWith(
        baseUrl: _localBaseUrlController.text.trim(),
        model: _localModelController.text.trim(),
        timeoutMs: int.tryParse(_localTimeoutController.text.trim()) ?? 20000,
        apiToken: _localTokenController.text.trim(),
      ),
    );

    try {
      AppLogger.info(
        'Settings screen save started: strategy=${updatedSettings.strategy}, providerCount=${updatedSettings.providers.length}',
      );
      final savedSettings =
          await _service.updateSettings(token, updatedSettings);
      _applySettings(savedSettings);
      if (!mounted) {
        return;
      }
      AppLogger.info('Settings screen save completed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI ayarlari kaydedildi.')),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Settings screen save failed', error, stackTrace);
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updateStrategy(String? strategy) {
    if (_settings == null || strategy == null) {
      return;
    }

    setState(() {
      _settings = _settings!.copyWith(strategy: strategy);
    });
  }

  void _toggleFallbackToLocal(bool value) {
    if (_settings == null) {
      return;
    }

    setState(() {
      _settings = _settings!.copyWith(fallbackToLocal: value);
    });
  }

  void _toggleProvider(String providerId, bool enabled) {
    if (_settings == null) {
      return;
    }

    final updatedProviders = _settings!.providers
        .map(
          (provider) => provider.id == providerId
              ? provider.copyWith(enabled: enabled)
              : provider,
        )
        .toList();

    setState(() {
      _settings = _settings!.copyWith(providers: updatedProviders);
    });
  }

  void _moveProvider(int index, int direction) {
    if (_settings == null) {
      return;
    }

    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= _settings!.providers.length) {
      return;
    }

    final updatedProviders = [..._settings!.providers];
    final item = updatedProviders.removeAt(index);
    updatedProviders.insert(newIndex, item);

    setState(() {
      _settings = _settings!.copyWith(providers: updatedProviders);
    });
  }

  void _toggleLocalEnabled(bool value) {
    if (_settings == null) {
      return;
    }

    setState(() {
      _settings = _settings!.copyWith(
        localProvider: _settings!.localProvider.copyWith(enabled: value),
      );
    });
  }

  void _toggleMlServiceEnabled(bool value) {
    if (_settings == null) {
      return;
    }

    setState(() {
      _settings = _settings!.copyWith(
        mlService: _settings!.mlService.copyWith(enabled: value),
      );
    });
  }

  void _toggleLocalRequiresAuth(bool value) {
    if (_settings == null) {
      return;
    }

    setState(() {
      _settings = _settings!.copyWith(
        localProvider: _settings!.localProvider.copyWith(requiresAuth: value),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _settings == null
              ? Center(
                  child: Text(_error ?? 'AI ayarlari yuklenemedi.'),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    _buildStrategyCard(),
                    const SizedBox(height: 12),
                    _buildGeminiCard(),
                    const SizedBox(height: 12),
                    _buildMlServiceCard(),
                    const SizedBox(height: 12),
                    _buildLocalCard(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isSaving ? 'Kaydediliyor...' : 'Kaydet',
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStrategyCard() {
    final settings = _settings!;
    const strategyItems = [
      DropdownMenuItem(value: 'AUTO', child: Text('Otomatik fallback')),
      DropdownMenuItem(value: 'GEMINI_ONLY', child: Text('Sadece Gemini')),
      DropdownMenuItem(value: 'LOCAL_ONLY', child: Text('Sadece LM Studio')),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calisma sekli',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: settings.strategy,
              items: strategyItems,
              onChanged: _updateStrategy,
              decoration: const InputDecoration(
                labelText: 'AI stratejisi',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gemini bittiginde LM Studio dene'),
              subtitle: const Text(
                'AUTO modunda tum uzak anahtarlar hata verirse yerel modele gecilir.',
              ),
              value: settings.fallbackToLocal,
              onChanged:
                  settings.strategy == 'AUTO' ? _toggleFallbackToLocal : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chatResetSecondsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sohbet sifirlama suresi (sn)',
                helperText:
                    'Analiz ekranindan cikilip bu sure icinde geri donulmezse sohbet temizlenir.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chatRequestTimeoutController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'AI istek timeout (ms)',
                helperText:
                    'Mobil/web istemci AI cevabini en fazla bu kadar bekler.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiCard() {
    final settings = _settings!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gemini anahtarlari',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Liste sirasina gore denenir. 429, quota, auth veya baska provider hatalarinda bir sonraki anahtara gecilir.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _geminiModelController,
              decoration: const InputDecoration(
                labelText: 'Gemini modeli',
              ),
            ),
            const SizedBox(height: 12),
            ...settings.providers.asMap().entries.map((entry) {
              final index = entry.key;
              final provider = entry.value;
              final controller = _providerKeyControllers[provider.id]!;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${provider.label}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              index > 0 ? () => _moveProvider(index, -1) : null,
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          onPressed: index < settings.providers.length - 1
                              ? () => _moveProvider(index, 1)
                              : null,
                          icon: const Icon(Icons.arrow_downward),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Etkin'),
                      value: provider.enabled,
                      onChanged: (value) => _toggleProvider(provider.id, value),
                    ),
                    TextField(
                      controller: controller,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'API anahtari',
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalCard() {
    final localProvider = _settings!.localProvider;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yerel AI (9router / LM Studio)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'OpenAI uyumlu /v1/chat/completions endpointi cagrilir. 9router veya LM Studio gibi yerel sunucularla calisir. Tum uzak denemeler biterse ya da strateji LOCAL_ONLY ise burasi kullanilir.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Yerel AI etkin'),
              value: localProvider.enabled,
              onChanged: _toggleLocalEnabled,
            ),
            TextField(
              controller: _localBaseUrlController,
              decoration: const InputDecoration(
                labelText: 'Sunucu adresi',
                helperText:
                    'Ornek: http://localhost:20128/v1 (9router) veya http://localhost:1234 (LM Studio).',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _localModelController,
              decoration: const InputDecoration(
                labelText: 'Model kimligi',
                helperText:
                    'Sunucuda yuklu model adi. Bilmiyorsaniz local-default yazip degistirebilirsiniz.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _localTimeoutController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Yerel AI timeout (ms)',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('API token zorunlu'),
              subtitle: const Text(
                'Sunucu auth gerektiriyorsa acin (Bearer header gonderilir).',
              ),
              value: localProvider.requiresAuth,
              onChanged: _toggleLocalRequiresAuth,
            ),
            TextField(
              controller: _localTokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API token',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMlServiceCard() {
    final mlService = _settings!.mlService;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ML Servisi',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'KNN ve trend tahmini gibi ayri Python/FastAPI servis araclari bu adrese gore cagrilir.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ML servisi etkin'),
              value: mlService.enabled,
              onChanged: _toggleMlServiceEnabled,
            ),
            TextField(
              controller: _mlServiceBaseUrlController,
              decoration: const InputDecoration(
                labelText: 'Servis adresi',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mlServiceTimeoutController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Timeout (ms)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
