import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:frontend/models/financial_transaction.dart';
import 'package:frontend/providers/transaction_provider.dart';
import 'package:frontend/screens/select_person_screen.dart';
import 'package:frontend/screens/select_reference_screen.dart';
import 'package:frontend/services/image_service.dart';
import 'package:frontend/utils/financial_transaction_utils.dart';
import 'package:frontend/utils/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AddFinancialTransactionScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPerson;
  final bool lockPersonSelection;
  final String? title;

  const AddFinancialTransactionScreen({
    super.key,
    this.initialPerson,
    this.lockPersonSelection = false,
    this.title,
  });

  @override
  State<AddFinancialTransactionScreen> createState() =>
      _AddFinancialTransactionScreenState();
}

class _AddFinancialTransactionScreenState
    extends State<AddFinancialTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImageService _imageService = ImageService();

  bool _isLoading = false;
  DisplayTransactionType _selectedTransactionType =
      DisplayTransactionType.satis;
  Map<String, dynamic>? _selectedPerson;
  String _selectedCurrency = 'TRY';
  String? _selectedPaymentMethod;
  String _selectedReferenceType = 'Yok';
  String? _selectedReference;
  DateTime _selectedDate = DateTime.now();
  XFile? _proofImage;
  Uint8List? _proofImageBytes;

  @override
  void initState() {
    super.initState();
    _selectedPerson = widget.initialPerson;
    AppLogger.info(
      'Financial transaction screen initialized: locked=${widget.lockPersonSelection}, initialPerson=${widget.initialPerson?['person_id'] ?? "none"}',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  String _getDisplayName(Map<String, dynamic>? person) {
    if (person == null) return '';
    final isletmeIsmi = person['isletme_ismi']?.toString().trim();
    if (isletmeIsmi != null && isletmeIsmi.isNotEmpty) {
      return isletmeIsmi;
    }
    final ad = person['ad']?.toString() ?? '';
    final soyad = person['soyad']?.toString() ?? '';
    return '$ad $soyad'.trim();
  }

  bool get _isPersonOptional =>
      _selectedTransactionType == DisplayTransactionType.gelir ||
      _selectedTransactionType == DisplayTransactionType.gider;

  bool get _isPaymentLocked =>
      _selectedTransactionType == DisplayTransactionType.satis ||
      _selectedTransactionType == DisplayTransactionType.alis;

  Future<void> _submitForm() async {
    AppLogger.info(
      'Financial transaction submit requested: type=${_selectedTransactionType.name}, personId=${_selectedPerson?['person_id'] ?? "none"}',
    );
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (!_isPersonOptional && _selectedPerson == null) {
      AppLogger.warning(
        'Financial transaction submit blocked because person is required',
      );
      _showSnackBar(
        'Bu işlem türü için kişi seçimi zorunludur.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final transactionData = {
        'type': _selectedTransactionType,
        'person_id': _selectedPerson?['person_id'],
        'personName':
            _selectedPerson != null ? _getDisplayName(_selectedPerson) : null,
        'amount': double.parse(_amountController.text.replaceAll(',', '.')),
        'currency': _selectedCurrency,
        'payment_method': _isPaymentLocked ? null : _selectedPaymentMethod,
        'description': _descriptionController.text.trim(),
        'transaction_date': _selectedDate,
        'proof_image_url': null,
        'reference_type': _selectedReferenceType,
        'reference_id': _selectedReference,
        'category': transactionTypeLabel(_selectedTransactionType),
      };

      await context.read<TransactionProvider>().addTransaction(transactionData);
      AppLogger.info('Financial transaction submit completed successfully');

      if (mounted) {
        _showSnackBar('İşlem başarıyla oluşturuldu.');
        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Financial transaction submit failed',
        error,
        stackTrace,
      );
      _showSnackBar(
        'İşlem oluşturulamadı: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
    AppLogger.debug('Financial transaction date selected: $_selectedDate');
  }

  Future<void> _pickProofImage() async {
    final image = await _imageService.showImageSourceDialog(context);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _proofImage = image;
      _proofImageBytes = bytes;
    });
    AppLogger.debug(
      'Financial transaction proof image selected: ${image.name}, bytes=${bytes.length}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Finansal İşlem Ekle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle(
              context,
              'İşlem Türü',
              'Sistemdeki tüm finansal işlem tiplerinden seçim yapın.',
            ),
            _buildTransactionTypeSelector(theme),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context,
              'İlgili Kişi',
              _isPersonOptional
                  ? 'Gelir ve gider işlemlerinde kişi seçimi opsiyoneldir.'
                  : 'Bu işlem için ilgili kişiyi seçin.',
            ),
            _buildPersonSelector(theme),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context,
              'Tutar ve Ödeme',
              'Tutarı, para birimini ve gerekiyorsa ödeme yöntemini girin.',
            ),
            _buildAmountAndPaymentMethod(theme),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context,
              'Açıklama',
              'İşlem açıklaması, not veya kısa detay ekleyebilirsiniz.',
            ),
            _buildDescriptionField(),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context,
              'Referans',
              'İsterseniz ilişki, alışveriş veya ürün referansı bağlayabilirsiniz.',
            ),
            _buildReferenceSection(),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context,
              'İşlem Tarihi',
              'Tarih ve saat bilgisiyle işlem zamanını belirleyin.',
            ),
            _buildDatePicker(),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context,
              'Kanıt Görseli',
              'İsterseniz işleme ait görsel kanıt ekleyebilirsiniz.',
            ),
            _buildImagePicker(theme),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isLoading ? null : _submitForm,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isLoading ? 'Kaydediliyor...' : 'İşlemi Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    String description,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTransactionTypeSelector(ThemeData theme) {
    final types = DisplayTransactionType.values
        .where((type) => type != DisplayTransactionType.bilinmeyen)
        .toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((type) {
        final isSelected = _selectedTransactionType == type;
        return ChoiceChip(
          selected: isSelected,
          avatar: Icon(
            transactionTypeIcon(type),
            size: 18,
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
          ),
          label: Text(transactionTypeLabel(type)),
          onSelected: (_) {
            setState(() {
              _selectedTransactionType = type;
              if (_isPaymentLocked) {
                _selectedPaymentMethod = null;
              }
            });
          },
          selectedColor: theme.colorScheme.primary,
          labelStyle: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        );
      }).toList(),
    );
  }

  Widget _buildPersonSelector(ThemeData theme) {
    return OutlinedButton(
      onPressed: widget.lockPersonSelection
          ? null
          : () async {
              final result =
                  await Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(builder: (_) => const SelectPersonScreen()),
              );
              if (result != null) {
                setState(() {
                  _selectedPerson = result;
                });
              }
            },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      child: _selectedPerson == null
          ? Row(
              children: [
                const Icon(Icons.person_search_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isPersonOptional
                        ? 'Kişi seçin (opsiyonel)'
                        : 'İşlem yapılacak kişiyi seçin',
                  ),
                ),
              ],
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Text(
                    _getDisplayName(_selectedPerson).isNotEmpty
                        ? _getDisplayName(_selectedPerson)[0].toUpperCase()
                        : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getDisplayName(_selectedPerson),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!widget.lockPersonSelection)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedPerson = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                    tooltip: 'Kişiyi kaldır',
                  ),
              ],
            ),
    );
  }

  Widget _buildAmountAndPaymentMethod(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = [
          Expanded(
            child: TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tutar',
                prefixIcon: _buildCurrencySelector(theme),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tutar girin';
                }
                if (double.tryParse(value.replaceAll(',', '.')) == null) {
                  return 'Geçerli bir sayı girin';
                }
                return null;
              },
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedPaymentMethod,
              decoration: InputDecoration(
                labelText: _isPaymentLocked
                    ? 'Ödeme yöntemi (otomatik)'
                    : 'Ödeme yöntemi',
              ),
              items: const [
                DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                DropdownMenuItem(
                    value: 'Havale/EFT', child: Text('Havale / EFT')),
                DropdownMenuItem(
                    value: 'Kredi Kartı', child: Text('Kredi Kartı')),
                DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
              ],
              onChanged: _isPaymentLocked
                  ? null
                  : (value) {
                      setState(() {
                        _selectedPaymentMethod = value;
                      });
                    },
            ),
          ),
        ];

        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              Row(children: [children[0]]),
              const SizedBox(height: 12),
              Row(children: [children[1]]),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            children[0],
            const SizedBox(width: 16),
            children[1],
          ],
        );
      },
    );
  }

  Widget _buildCurrencySelector(ThemeData theme) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedCurrency,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.only(left: 12),
        items: const [
          DropdownMenuItem(value: 'TRY', child: Text('TL')),
          DropdownMenuItem(value: 'USD', child: Text('\$')),
          DropdownMenuItem(value: 'EUR', child: Text('€')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _selectedCurrency = value;
          });
        },
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'İşlem açıklaması',
        alignLabelWithHint: true,
      ),
      maxLines: 4,
      textInputAction: TextInputAction.newline,
    );
  }

  Widget _buildReferenceSection() {
    return Column(
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Yok', label: Text('Yok')),
            ButtonSegment(value: 'Ticari İlişki', label: Text('İlişki')),
            ButtonSegment(value: 'Alışveriş', label: Text('Alışveriş')),
            ButtonSegment(value: 'Toptan Ürün', label: Text('Ürün')),
          ],
          selected: {_selectedReferenceType},
          onSelectionChanged: (newSelection) {
            setState(() {
              _selectedReferenceType = newSelection.first;
              _selectedReference = null;
            });
          },
          showSelectedIcon: false,
        ),
        if (_selectedReferenceType != 'Yok') ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => SelectReferenceScreen(
                    referenceType: _selectedReferenceType,
                  ),
                ),
              );
              if (result != null) {
                setState(() {
                  _selectedReference = result;
                });
              }
            },
            icon: const Icon(Icons.link_outlined),
            label: Text(
              _selectedReference ?? '$_selectedReferenceType referansı seçin',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker() {
    return OutlinedButton.icon(
      onPressed: _pickDateTime,
      icon: const Icon(Icons.schedule_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(_selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  Widget _buildImagePicker(ThemeData theme) {
    return GestureDetector(
      onTap: _pickProofImage,
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(18),
        dashPattern: const [8, 6],
        color: theme.colorScheme.outline,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: _proofImageBytes == null
              ? Column(
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 34,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Kanıt görseli eklemek için dokunun',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Web ve mobilde önizleme desteklenir.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _proofImageBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _proofImage?.name ?? 'Görsel seçildi',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _proofImage = null;
                              _proofImageBytes = null;
                            });
                          },
                          child: const Text('Kaldır'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
