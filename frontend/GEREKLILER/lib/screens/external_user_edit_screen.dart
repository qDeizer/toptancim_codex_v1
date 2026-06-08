import 'package:flutter/material.dart';
import 'package:frontend/models/connection_details.dart';
import 'package:frontend/services/connection_service.dart';
import 'package:frontend/services/image_service.dart';
import 'package:frontend/screens/map_picker_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ExternalUserEditScreen extends StatefulWidget {
  final ConnectionDetails user;
  const ExternalUserEditScreen({super.key, required this.user});

  @override
  State<ExternalUserEditScreen> createState() => _ExternalUserEditScreenState();
}

class _ExternalUserEditScreenState extends State<ExternalUserEditScreen> {
  final ConnectionService _connectionService = ConnectionService();
  final ImageService _imageService = ImageService();
  final _formKey = GlobalKey<FormState>();

  bool _isUpdating = false;
  String? _profileImageUrl;

  late TextEditingController _isletmeIsmiController;
  late TextEditingController _adController;
  late TextEditingController _soyadController;
  late TextEditingController _telNoController;
  late TextEditingController _emailController;
  late TextEditingController _addressTitleController;
  late TextEditingController _addressController;
  late TextEditingController _detailedAddressController;

  double? _selectedLatitude;
  double? _selectedLongitude;


  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _isletmeIsmiController = TextEditingController(text: widget.user.isletmeIsmi ?? '');
    _adController = TextEditingController(text: widget.user.ad ?? '');
    _soyadController = TextEditingController(text: widget.user.soyad ?? '');
    _telNoController = TextEditingController(text: widget.user.telNo ?? '');
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _addressTitleController = TextEditingController(text: widget.user.addressTitle ?? '');
    _addressController = TextEditingController(text: widget.user.address ?? '');
    _detailedAddressController = TextEditingController(text: widget.user.detailedAddress ?? '');
    _profileImageUrl = widget.user.profilFotografi;
    _selectedLatitude = widget.user.latitude;
    _selectedLongitude = widget.user.longitude;
  }

  @override
  void dispose() {
    _isletmeIsmiController.dispose();
    _adController.dispose();
    _soyadController.dispose();
    _telNoController.dispose();
    _emailController.dispose();
    _addressTitleController.dispose();
    _addressController.dispose();
    _detailedAddressController.dispose();
    super.dispose();
  }

  Future<void> _updateProfilePhoto() async {
    try {
      final XFile? image = await _imageService.showImageSourceDialog(context);
      if (image != null) {
        setState(() => _isUpdating = true);
        final imageUrl = await _imageService.uploadProfileImage(image);
        if (imageUrl != null) {
          setState(() {
            _profileImageUrl = imageUrl;
          });
          _showSuccessSnackBar('Profil fotoğrafı seçildi');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Profil fotoğrafı yüklenemedi: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception("Not authenticated");
      
      final profileData = {
        'isletme_ismi': _isletmeIsmiController.text,
        'ad': _adController.text,
        'soyad': _soyadController.text,
        'tel_no': _telNoController.text,
        'email': _emailController.text,
        'profil_fotografi': _profileImageUrl,
        'address_title': _addressTitleController.text,
        'address': _addressController.text,
        'detailed_address': _detailedAddressController.text,
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
      };

      await _connectionService.updateExternalUser(token, widget.user.id, profileData);
      _showSuccessSnackBar('Profil başarıyla güncellendi');
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showErrorSnackBar('Profil güncellenemedi: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
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

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _selectLocationOnMap() async {
    final LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLocation: _selectedLatitude != null && _selectedLongitude != null
              ? LatLng(_selectedLatitude!, _selectedLongitude!)
              : const LatLng(38.6143, 27.4287), // Manisa
        ),
      ),
    );
    if (selectedLocation != null) {
      setState(() {
        _selectedLatitude = selectedLocation.latitude;
        _selectedLongitude = selectedLocation.longitude;
      });
      _showSuccessSnackBar('Konum seçildi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text('Düzenle: ${widget.user.displayName}'),
            Chip(
              label: const Text('Harici'),
              backgroundColor: Colors.red.shade400,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
          ],
        ),
        actions: [
          if (_isUpdating)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: 'Profili Kaydet',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildProfilePhotoSection(),
            const SizedBox(height: 24),
            _buildSectionCard('Kişisel & Firma Bilgileri', [
              TextFormField(controller: _isletmeIsmiController, decoration: const InputDecoration(labelText: 'İşletme Adı')),
              const SizedBox(height: 16),
              TextFormField(controller: _adController, decoration: const InputDecoration(labelText: 'Ad')),
              const SizedBox(height: 16),
              TextFormField(controller: _soyadController, decoration: const InputDecoration(labelText: 'Soyad')),
            ]),
            const SizedBox(height: 16),
             _buildSectionCard('İletişim Bilgileri', [
              TextFormField(controller: _telNoController, decoration: const InputDecoration(labelText: 'Telefon'), keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-posta'), keyboardType: TextInputType.emailAddress),
            ]),
            const SizedBox(height: 16),
            _buildAddressInfoSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInfoSection() {
    return _buildSectionCard('Adres Bilgileri', [
      TextFormField(
        controller: _addressTitleController,
        decoration: const InputDecoration(labelText: 'Adres Başlığı (Örn: İş, Depo)'),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _addressController,
        decoration: const InputDecoration(labelText: 'Adres (Sokak, Mahalle vb.)'),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _detailedAddressController,
        decoration: const InputDecoration(labelText: 'Açık Adres (Bina, Daire No vb.)'),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _selectLocationOnMap,
        icon: const Icon(Icons.location_on),
        label: Text(
          _selectedLatitude != null && _selectedLongitude != null
              ? 'Konum Seçildi'
              : 'Haritadan Konum Seç',
        ),
      ),
      if (_selectedLatitude != null)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            '(${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)})',
            style: const TextStyle(color: Colors.green),
          ),
        ),
    ]);
  }

  Widget _buildProfilePhotoSection() {
    return Center(
      child: GestureDetector(
        onTap: _updateProfilePhoto,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[300],
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(ImageService.getFullImageUrl(_profileImageUrl!))
                  : null,
              child: _profileImageUrl == null
                  ? const Icon(Icons.person, size: 60, color: Colors.grey)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}