import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:frontend/models/financial_transaction.dart';
import 'package:frontend/providers/transaction_provider.dart';
import 'package:frontend/screens/select_person_screen.dart';
import 'package:frontend/screens/select_reference_screen.dart';
import 'package:frontend/services/image_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';

class AddFinancialTransactionScreen extends StatefulWidget {
  const AddFinancialTransactionScreen({super.key});
  @override
  State<AddFinancialTransactionScreen> createState() =>
      _AddFinancialTransactionScreenState();
}

class _AddFinancialTransactionScreenState
    extends State<AddFinancialTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  DisplayTransactionType _selectedTransactionType = DisplayTransactionType.satis;
  Map<String, dynamic>? _selectedPerson;
  final _amountController = TextEditingController();
  String _selectedCurrency = '₺';
  String? _selectedPaymentMethod;
  final _descriptionController = TextEditingController();
  String _selectedReferenceType = 'Yok';
  String? _selectedReference;
  DateTime _selectedDate = DateTime.now();
  XFile? _proofImage;

  final ImageService _imageService = ImageService();

  Widget _buildSegment(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }

  String _getDisplayName(Map<String, dynamic>? person) {
    if (person == null) return '';
    final isletmeIsmi = person['isletme_ismi'];
    if (isletmeIsmi != null && isletmeIsmi.isNotEmpty) {
      return isletmeIsmi;
    }
    final ad = person['ad'] ?? '';
    final soyad = person['soyad'] ?? '';
    return '$ad $soyad'.trim();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _submitForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    
    // Gelir-Gider dışındaki işlemler için kişi seçimi zorunlu
    if (_selectedTransactionType != DisplayTransactionType.gelir && 
        _selectedTransactionType != DisplayTransactionType.gider && 
        _selectedPerson == null) {
      _showErrorSnackBar('Bu işlem türü için kişi seçimi zorunludur.');
      return;
    }

    _formKey.currentState?.save();
    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_proofImage != null) {
        print("Resim seçildi: ${_proofImage!.path}");
      }

      final transactionData = {
        'type': _selectedTransactionType,
        'person_id': _selectedPerson?['person_id'],
        'personName': _selectedPerson != null ? _getDisplayName(_selectedPerson) : null,
        'amount': double.parse(_amountController.text),
        'currency': _selectedCurrency,
        'payment_method': (_selectedTransactionType == DisplayTransactionType.satis || 
                          _selectedTransactionType == DisplayTransactionType.alis) 
                          ? null : _selectedPaymentMethod,
        'description': _descriptionController.text,
        'transaction_date': _selectedDate,
        'proof_image_url': imageUrl,
        'reference_type': _selectedReferenceType,
        'reference_id': _selectedReference,
      };
      await Provider.of<TransactionProvider>(context, listen: false)
          .addTransaction(transactionData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşlem başarıyla oluşturuldu'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showErrorSnackBar('İşlem oluşturulamadı: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finansal İşlem Ekle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionTitle('Yapılan İşlemin Türü'),
            _buildTransactionTypeSelector(),
            const SizedBox(height: 24),
            _buildSectionTitle('İşlem Kiminle Yapıldı?'),
            _buildPersonSelector(),
            const SizedBox(height: 24),
            _buildSectionTitle('Tutar ve Ödeme Yöntemi'),
            _buildAmountAndPaymentMethod(),
            const SizedBox(height: 24),
            _buildSectionTitle('Açıklama'),
            _buildDescriptionField(),
            const SizedBox(height: 24),
            _buildSectionTitle('Referans (İsteğe Bağlı)'),
            _buildReferenceSection(),
            const SizedBox(height: 24),
            _buildSectionTitle('İşlem Tarihi'),
            _buildDatePicker(),
            const SizedBox(height: 24),
            _buildSectionTitle('Kanıt Fotoğrafı (İsteğe Bağlı)'),
            _buildImagePicker(),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('İşlemi Oluştur'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildTransactionTypeSelector() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        SegmentedButton<DisplayTransactionType>(
          segments: [
            ButtonSegment(
                value: DisplayTransactionType.satis,
                label: _buildSegment(Icons.point_of_sale, 'Satış')),
            ButtonSegment(
                value: DisplayTransactionType.tahsilat,
                label: _buildSegment(Icons.call_received, 'Tahsilat')),
            ButtonSegment(
                value: DisplayTransactionType.alis,
                label: _buildSegment(Icons.add_shopping_cart, 'Alış')),
            ButtonSegment(
                value: DisplayTransactionType.odeme,
                label: _buildSegment(Icons.call_made, 'Ödeme')),
            ButtonSegment(
                value: DisplayTransactionType.gelir,
                label: _buildSegment(Icons.trending_up, 'Gelir')),
            ButtonSegment(
                value: DisplayTransactionType.gider,
                label: _buildSegment(Icons.trending_down, 'Gider')),
          ],
          selected: {_selectedTransactionType},
          onSelectionChanged: (newSelection) {
            setState(() {
              _selectedTransactionType = newSelection.first;
              // Satış-Alış seçildiğinde ödeme yöntemini sıfırla
              if (_selectedTransactionType == DisplayTransactionType.satis || 
                  _selectedTransactionType == DisplayTransactionType.alis) {
                _selectedPaymentMethod = null;
              }
            });
          },
          showSelectedIcon: false,
        ),
      ],
    );
  }

  Widget _buildPersonSelector() {
    // Gelir-Gider için kişi seçimi isteğe bağlı
    final isPersonOptional = _selectedTransactionType == DisplayTransactionType.gelir || 
                             _selectedTransactionType == DisplayTransactionType.gider;
    
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        side: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
      ),
      onPressed: () async {
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (ctx) => const SelectPersonScreen()),
        );
        if (result != null) {
          setState(() {
            _selectedPerson = result;
          });
        }
      },
      child: _selectedPerson == null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_alt_1),
                const SizedBox(width: 8),
                Text(isPersonOptional ? 'Kişi Seç (İsteğe Bağlı)' : 'Kişi Seç'),
              ],
            )
          : Row(
              children: [
                CircleAvatar(
                  backgroundImage: _selectedPerson!['profil_fotografi'] != null
                      ? NetworkImage(ImageService.getFullImageUrl(
                          _selectedPerson!['profil_fotografi']))
                      : null,
                  radius: 18,
                  child: _selectedPerson!['profil_fotografi'] == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getDisplayName(_selectedPerson),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedPerson = null;
                    });
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildAmountAndPaymentMethod() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Tutar',
              prefixIcon: DropdownButton<String>(
                value: _selectedCurrency,
                items: ['₺', '\$', '€']
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(c),
                        )))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCurrency = value;
                    });
                  }
                },
                underline: const SizedBox(),
              ),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Tutar girin';
              }
              if (double.tryParse(value) == null) {
                return 'Geçerli bir sayı girin';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<String>(
            value: _selectedPaymentMethod,
            decoration: InputDecoration(
              labelText: (_selectedTransactionType == DisplayTransactionType.satis || 
                         _selectedTransactionType == DisplayTransactionType.alis) 
                         ? 'Ödeme Yöntemi (Devre Dışı)' 
                         : 'Ödeme Yöntemi (İsteğe Bağlı)',
              enabled: _selectedTransactionType != DisplayTransactionType.satis && 
                      _selectedTransactionType != DisplayTransactionType.alis,
            ),
            items: ['Nakit', 'Havale/EFT', 'Kredi Kartı', 'Diğer']
                .map((method) =>
                    DropdownMenuItem(value: method, child: Text(method)))
                .toList(),
            onChanged: (_selectedTransactionType == DisplayTransactionType.satis || 
                       _selectedTransactionType == DisplayTransactionType.alis) 
                       ? null 
                       : (value) {
              setState(() {
                _selectedPaymentMethod = value;
              });
            },
            validator: (value) {
              // Ödeme yöntemi hiçbir işlem türü için zorunlu değil
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'İşlem açıklaması, notlar vb.',
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
        ),
        if (_selectedReferenceType != 'Yok') ...[
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
            onPressed: () async {
              final result = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => SelectReferenceScreen(
                      referenceType: _selectedReferenceType),
                ),
              );
              if (result != null) {
                setState(() {
                  _selectedReference = result;
                });
              }
            },
            child: Text(_selectedReference ??
                '$_selectedReferenceType Referansı Seç'),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      onPressed: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (pickedDate != null) {
          setState(() {
            _selectedDate = pickedDate;
          });
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tarih: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
            style: const TextStyle(fontSize: 16),
          ),
          const Icon(Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () async {
        final image = await _imageService.showImageSourceDialog(context);
        if (image != null) {
          setState(() {
            _proofImage = image;
          });
        }
      },
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(12),
        padding: const EdgeInsets.all(6),
        dashPattern: const [6, 6],
        strokeWidth: 2,
        color: Colors.grey.shade400,
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _proofImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 40,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fotoğraf yüklemek için dokunun',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: kIsWeb
                      ? Image.network(_proofImage!.path, fit: BoxFit.cover)
                      : Image.file(File(_proofImage!.path),
                          fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }
}