import 'package:flutter/material.dart';
import 'package:frontend/screens/profile_edit_screen.dart';
import 'package:frontend/services/user_service.dart';
import 'package:frontend/services/image_service.dart';
import 'package:intl/intl.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final UserService _userService = UserService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getProfile();
      setState(() {
        _userProfile = profile;
      });
    } catch (e) {
      _showErrorSnackBar('Profil yüklenemedi: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(userProfile: _userProfile!),
      ),
    );
    if (result == true) {
      _loadProfile();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          if (!_isLoading && _userProfile != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Profili Düzenle',
              onPressed: _navigateToEdit,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? Center(child: TextButton(onPressed: _loadProfile, child: const Text('Profil yüklenemedi. Tekrar dene.')))
              : RefreshIndicator(onRefresh: _loadProfile, child: _buildProfileContent()),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildPersonalInfoCard(),
          const SizedBox(height: 16),
          _buildContactInfoCard(),
          const SizedBox(height: 16),
          _buildAddressInfoCard(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[300],
              backgroundImage: _userProfile!['profil_fotografi'] != null
                  ? NetworkImage(ImageService.getFullImageUrl(_userProfile!['profil_fotografi']))
                  : null,
              child: _userProfile!['profil_fotografi'] == null
                  ? const Icon(Icons.person, size: 60, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              '${_userProfile!['ad'] ?? ''} ${_userProfile!['soyad'] ?? ''}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _userProfile!['isletme_ismi'] ?? '',
              style: const TextStyle(fontSize: 18, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(
              '@${_userProfile!['user_name'] ?? ''}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(String title, List<Widget> children) {
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

  Widget _buildPersonalInfoCard() {
    return _buildInfoCard('Kişisel Bilgiler', [
      _buildInfoRow('Hakkında', _userProfile!['hakkinda']),
      _buildInfoRow('Üyelik Tipi', _userProfile!['toptanci_uyelik'] == true ? 'Toptancı' : 'Perakendeci'),
      _buildInfoRow('Üye Olma Tarihi', _formatDate(_userProfile!['created_at'])),
    ]);
  }

  Widget _buildContactInfoCard() {
    return _buildInfoCard('İletişim Bilgileri', [
      _buildInfoRow('Telefon', _userProfile!['tel_no']),
      _buildInfoRow('E-posta', _userProfile!['email']),
    ]);
  }

  Widget _buildAddressInfoCard() {
     return _buildInfoCard('Adres Bilgileri', [
      _buildInfoRow('Adres Başlığı', _userProfile!['address_title']),
      _buildInfoRow('Adres', _userProfile!['address']),
      _buildInfoRow('Açık Adres', _userProfile!['detailed_address']),
      if (_userProfile!['latitude'] != null)
        _buildInfoRow('Konum', 'Enlem: ${_userProfile!['latitude']}, Boylam: ${_userProfile!['longitude']}'),
    ]);
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(date);
    } catch (e) {
      return '-';
    }
  }
}