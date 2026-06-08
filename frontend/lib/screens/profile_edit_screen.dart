import 'package:flutter/material.dart';
import 'package:frontend/services/user_service.dart';
import 'package:frontend/services/image_service.dart';
import 'package:frontend/screens/map_picker_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  const ProfileEditScreen({super.key, required this.userProfile});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final UserService _userService = UserService();
  final ImageService _imageService = ImageService();
  final _formKey = GlobalKey<FormState>();
  bool _isUpdating = false;
  String? _profileImageUrl;

  late TextEditingController _userNameController;
  late TextEditingController _isletmeIsmiController;
  late TextEditingController _adController;
  late TextEditingController _soyadController;
  late TextEditingController _telNoController;
  late TextEditingController _emailController;
  late TextEditingController _hakkindaController;
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
    _userNameController = TextEditingController(text: widget.userProfile['user_name'] ?? '');
    _isletmeIsmiController = TextEditingController(text: widget.userProfile['isletme_ismi'] ?? '');
    _adController = TextEditingController(text: widget.userProfile['ad'] ?? '');
    _soyadController = TextEditingController(text: widget.userProfile['soyad'] ?? '');
    _telNoController = TextEditingController(text: widget.userProfile['tel_no'] ?? '');
    _emailController = TextEditingController(text: widget.userProfile['email'] ?? '');
    _hakkindaController = TextEditingController(text: widget.userProfile['hakkinda'] ?? '');
    
    _addressTitleController = TextEditingController(text: widget.userProfile['address_title'] ?? '');
    _addressController = TextEditingController(text: widget.userProfile['address'] ?? '');
    _detailedAddressController = TextEditingController(text: widget.userProfile['detailed_address'] ?? '');
    
    _selectedLatitude = (widget.userProfile['latitude'] as num?)?.toDouble();
    _selectedLongitude = (widget.userProfile['longitude'] as num?)?.toDouble();
    _profileImageUrl = widget.userProfile['profil_fotografi'];
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _isletmeIsmiController.dispose();
    _adController.dispose();
    _soyadController.dispose();
    _telNoController.dispose();
    _emailController.dispose();
    _hakkindaController.dispose();
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
      final profileData = {
        'user_name': _userNameController.text,
        'isletme_ismi': _isletmeIsmiController.text,
        'ad': _adController.text,
        'soyad': _soyadController.text,
        'tel_no': _telNoController.text,
        'email': _emailController.text,
        'hakkinda': _hakkindaController.text,
        'profil_fotografi': _profileImageUrl,
        'address_info': {
          'address_title': _addressTitleController.text,
          'address': _addressController.text,
          'detailed_address': _detailedAddressController.text,
          'latitude': _selectedLatitude,
          'longitude': _selectedLongitude,
        },
      };
      await _userService.updateProfile(profileData);
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
              : const LatLng(41.0082, 28.9784),
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
        title: const Text('Profili Düzenle'),
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
            _buildPersonalInfoSection(),
            const SizedBox(height: 24),
            _buildContactInfoSection(),
            const SizedBox(height: 24),
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

  Widget _buildPersonalInfoSection() {
    return _buildSectionCard('Kişisel Bilgiler', [
      TextFormField(
        controller: _userNameController,
        decoration: const InputDecoration(labelText: 'Kullanıcı Adı'),
        validator: (value) => value!.isEmpty ? 'Kullanıcı adı gerekli' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _isletmeIsmiController,
        decoration: const InputDecoration(labelText: 'İşletme Adı'),
        validator: (value) => value!.isEmpty ? 'İşletme adı gerekli' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _adController,
        decoration: const InputDecoration(labelText: 'Ad'),
        validator: (value) => value!.isEmpty ? 'Ad gerekli' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _soyadController,
        decoration: const InputDecoration(labelText: 'Soyad'),
        validator: (value) => value!.isEmpty ? 'Soyad gerekli' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _hakkindaController,
        decoration: const InputDecoration(labelText: 'Hakkında', alignLabelWithHint: true),
        maxLines: 3,
      ),
    ]);
  }

  Widget _buildContactInfoSection() {
    return _buildSectionCard('İletişim Bilgileri', [
      TextFormField(
        controller: _telNoController,
        decoration: const InputDecoration(labelText: 'Telefon'),
        keyboardType: TextInputType.phone,
        validator: (value) => value!.isEmpty ? 'Telefon numarası gerekli' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        decoration: const InputDecoration(labelText: 'E-posta'),
        keyboardType: TextInputType.emailAddress,
        validator: (value) => value!.isEmpty || !value.contains('@') ? 'Geçerli bir e-posta adresi girin' : null,
      ),
    ]);
  }

  Widget _buildAddressInfoSection() {
    return _buildSectionCard('Adres Bilgileri', [
      TextFormField(
        controller: _addressTitleController,
        decoration: const InputDecoration(labelText: 'Adres Başlığı (Örn: Ev, İş)'),
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
}