import 'package:flutter/material.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:provider/provider.dart';

class AddConnectionScreen extends StatefulWidget {
  const AddConnectionScreen({super.key});

  @override
  State<AddConnectionScreen> createState() => _AddConnectionScreenState();
}

enum ConnectionType { internal, external }
enum RelationType { customer, wholesaler }

class _AddConnectionScreenState extends State<AddConnectionScreen> {
  ConnectionType _connectionType = ConnectionType.internal;
  RelationType _relationType = RelationType.customer;
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _formData = {};
  bool _isLoading = false;

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<ConnectionProvider>(context, listen: false);
      if (_connectionType == ConnectionType.internal) {
        await provider.addInternalConnection(
          _formData['identifier']!,
          _relationType.name,
        );
      } else {
        final Map<String, dynamic> externalData = {..._formData};
        externalData['relation_type'] = _relationType.name;
        await provider.addExternalConnection(externalData);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showErrorSnackBar('İşlem başarısız: ${e.toString()}');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Bağlantı Ekle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            SegmentedButton<ConnectionType>(
              segments: const [
                ButtonSegment(value: ConnectionType.internal, label: Text('Dahili Kullanıcı')),
                ButtonSegment(value: ConnectionType.external, label: Text('Harici Kullanıcı')),
              ],
              selected: {_connectionType},
              onSelectionChanged: (newSelection) {
                setState(() => _connectionType = newSelection.first);
              },
            ),
            const SizedBox(height: 24),
            if (_connectionType == ConnectionType.internal) _buildInternalForm(),
            if (_connectionType == ConnectionType.external) _buildExternalForm(),
            const SizedBox(height: 24),
            const Text('İlişki Türü', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<RelationType>(
              title: const Text('Bu kişi benim müşterim'),
              value: RelationType.customer,
              groupValue: _relationType,
              onChanged: (value) => setState(() => _relationType = value!),
            ),
            RadioListTile<RelationType>(
              title: const Text('Bu kişi benim toptancım'),
              value: RelationType.wholesaler,
              groupValue: _relationType,
              onChanged: (value) => setState(() => _relationType = value!),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Bağlantıyı Kaydet'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalForm() {
    return TextFormField(
      decoration: const InputDecoration(labelText: 'Kullanıcı Adı, E-posta veya Telefon'),
      validator: (val) => val!.isEmpty ? 'Bu alan gerekli' : null,
      onSaved: (val) => _formData['identifier'] = val!,
    );
  }

  Widget _buildExternalForm() {
    return Column(
      children: [
        TextFormField(decoration: const InputDecoration(labelText: 'İşletme Adı'), onSaved: (val) => _formData['isletme_ismi'] = val ?? ''),
        const SizedBox(height: 8),
        TextFormField(decoration: const InputDecoration(labelText: 'Ad'), onSaved: (val) => _formData['ad'] = val ?? ''),
        const SizedBox(height: 8),
        TextFormField(decoration: const InputDecoration(labelText: 'Soyad'), onSaved: (val) => _formData['soyad'] = val ?? ''),
        const SizedBox(height: 8),
        TextFormField(decoration: const InputDecoration(labelText: 'Telefon'), keyboardType: TextInputType.phone, onSaved: (val) => _formData['tel_no'] = val ?? ''),
        const SizedBox(height: 8),
        TextFormField(decoration: const InputDecoration(labelText: 'E-posta'), keyboardType: TextInputType.emailAddress, onSaved: (val) => _formData['email'] = val ?? ''),
        const SizedBox(height: 8),
        TextFormField(decoration: const InputDecoration(labelText: 'Adres'), onSaved: (val) => _formData['adres'] = val ?? ''),
      ],
    );
  }
}