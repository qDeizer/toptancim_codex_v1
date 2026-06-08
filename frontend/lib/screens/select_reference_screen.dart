import 'package:flutter/material.dart';

class SelectReferenceScreen extends StatelessWidget {
  final String referenceType;

  const SelectReferenceScreen({super.key, required this.referenceType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$referenceType Referansı Seç'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Referans Seçme Özelliği',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Bu özellik henüz geliştirme aşamasındadır. İleride buradan "${referenceType.toLowerCase()}" seçebileceksiniz.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
               const SizedBox(height: 24),
              ElevatedButton(
                child: const Text('Örnek Referans Seç ve Geri Dön'),
                onPressed: (){
                   Navigator.of(context).pop('Örnek Referans #12345');
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}