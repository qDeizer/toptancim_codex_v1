import 'package:flutter/material.dart';
import 'package:frontend/screens/map_picker_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _registerData = {
    'user_name': '',
    'isletme_ismi': '',
    'ad': '',
    'soyad': '',
    'tel_no': '',
    'email': '',
    'password': '',
    'hakkinda': '',
    'address_title': '',
    'address': '',
    'detailed_address': '',
    'latitude': null,
    'longitude': null,
    'profil_fotografi': null,
  };
  bool _isLoading = false;
  int _currentStep = 0;
  final _passwordController = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Lütfen tüm zorunlu alanları doğru bir şekilde doldurun.');
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).register(
        userName: _registerData['user_name']!,
        isletmeIsmi: _registerData['isletme_ismi']!,
        ad: _registerData['ad']!,
        soyad: _registerData['soyad']!,
        telNo: _registerData['tel_no']!,
        email: _registerData['email']!,
        password: _registerData['password']!,
        hakkinda: _registerData['hakkinda'],
        address_info: {
         "address_title": _registerData['address_title'],
          "address": _registerData['address'],
          "detailed_address": _registerData['detailed_address'],
          "latitude": _registerData['latitude'],
          "longitude": _registerData['longitude'],
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt başarılı! Lütfen giriş yapın.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showErrorSnackBar('Kayıt başarısız: ${error.toString()}');
    }

    if (mounted) {
      setState(() => _isLoading = false);
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
      appBar: AppBar(title: const Text('Yeni Hesap Oluştur')),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep += 1);
            } else {
              _submit();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          steps: _buildSteps(),
          controlsBuilder: (BuildContext context, ControlsDetails details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(_currentStep == 2 ? 'KAYDI TAMAMLA' : 'İLERİ'),
                        ),
                        if (_currentStep != 0)
                          TextButton(
                            onPressed: details.onStepCancel,
                            child: const Text('GERİ'),
                          ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Kişisel Bilgiler'),
        content: Column(
          children: <Widget>[
            TextFormField(
                initialValue: _registerData['ad'],
                decoration: const InputDecoration(labelText: 'Ad'),
                validator: (val) => val!.isEmpty ? 'Gerekli' : null,
                onSaved: (val) => _registerData['ad'] = val!),
            TextFormField(
                initialValue: _registerData['soyad'],
                decoration: const InputDecoration(labelText: 'Soyad'),
                validator: (val) => val!.isEmpty ? 'Gerekli' : null,
                onSaved: (val) => _registerData['soyad'] = val!),
            TextFormField(
                initialValue: _registerData['isletme_ismi'],
                decoration: const InputDecoration(labelText: 'İşletme İsmi'),
                validator: (val) => val!.isEmpty ? 'Gerekli' : null,
                onSaved: (val) => _registerData['isletme_ismi'] = val!),
            TextFormField(
                initialValue: _registerData['tel_no'],
                decoration: const InputDecoration(labelText: 'Telefon No'),
                keyboardType: TextInputType.phone,
                validator: (val) => val!.isEmpty ? 'Gerekli' : null,
                onSaved: (val) => _registerData['tel_no'] = val!),
            TextFormField(
                initialValue: _registerData['hakkinda'],
                decoration: const InputDecoration(labelText: 'Hakkında (İsteğe bağlı)'),
                onSaved: (val) => _registerData['hakkinda'] = val!),
          ],
        ),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Hesap Bilgileri'),
        content: Column(
          children: [
            TextFormField(
                initialValue: _registerData['user_name'],
                decoration: const InputDecoration(labelText: 'Kullanıcı Adı'),
                validator: (val) => val!.isEmpty ? 'Gerekli' : null,
                onSaved: (val) => _registerData['user_name'] = val!),
            TextFormField(
                initialValue: _registerData['email'],
                decoration: const InputDecoration(labelText: 'E-Mail'),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val!.isEmpty || !val.contains('@') ? 'Geçerli e-posta girin' : null,
                onSaved: (val) => _registerData['email'] = val!),
            TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Şifre'),
                obscureText: true,
                validator: (val) => val!.length < 6 ? 'En az 6 karakter olmalı' : null,
                onSaved: (val) => _registerData['password'] = val!),
            TextFormField(
                decoration: const InputDecoration(labelText: 'Şifre Tekrar'),
                obscureText: true,
                validator: (val) => val! != _passwordController.text ? 'Şifreler eşleşmiyor' : null),
          ],
        ),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Adres Bilgileri'),
        content: Column(
          children: <Widget>[
            TextFormField(
                initialValue: _registerData['address_title'],
                decoration: const InputDecoration(labelText: 'Adres Başlığı (Örn: Ev, İş)'),
                validator: (val) => val!.isEmpty ? 'Gerekli' : null,
                onSaved: (val) => _registerData['address_title'] = val!),
            TextFormField(
                initialValue: _registerData['address'],
                decoration: const InputDecoration(labelText: 'Adres (Sokak, Mahalle vb.)'),
                validator: (val) => val!.isEmpty ? 'Gerekli' : null,
                onSaved: (val) => _registerData['address'] = val!),
            TextFormField(
                initialValue: _registerData['detailed_address'],
                decoration: const InputDecoration(labelText: 'Açık Adres (Bina, Daire No vb.)'),
                onSaved: (val) => _registerData['detailed_address'] = val!),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.map),
              label: const Text('Haritadan Konum Seç'),
              onPressed: () async {
                final LatLng? pickedLocation = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const MapPickerScreen(),
                  ),
                );
                if (pickedLocation != null) {
                  setState(() {
                    _registerData['latitude'] = pickedLocation.latitude;
                    _registerData['longitude'] = pickedLocation.longitude;
                  });
                }
              },
            ),
            if (_registerData['latitude'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Konum seçildi: (${_registerData['latitude'].toStringAsFixed(4)}, ${_registerData['longitude'].toStringAsFixed(4)})',
                  style: const TextStyle(color: Colors.green),
                ),
              ),
          ],
        ),
        isActive: _currentStep >= 2,
      ),
    ];
  }
}