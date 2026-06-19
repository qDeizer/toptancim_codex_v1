import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/screens/media_screen.dart';
import 'package:frontend/providers/media_provider.dart';

// AI Görsel Oluştur ekranındaki "hazır prompt önerileri" özelliğinin
// gerçek davranışını doğrular: chip'e dokununca metin prompt'a eklenir,
// yanındaki X'e basınca metin prompt'tan çıkar.
void main() {
  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<MediaProvider>(
        create: (_) => MediaProvider(),
        child: const MaterialApp(
          home: Scaffold(body: AiImageGeneratorSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Prompt TextField'ının güncel metnini bul.
  String promptText(WidgetTester tester) {
    final field = tester.widget<TextField>(
      find.byWidgetPredicate((w) => w is TextField && w.maxLines == 4),
    );
    return field.controller?.text ?? '';
  }

  const studioText = 'beyaz fonda profesyonel stüdyo ışığıyla çekilmiş ürün fotoğrafı';
  const mannequinText = 'ürün bir manken üzerinde sergileniyor';

  testWidgets('hazır öneri chip listesi gösterilir', (tester) async {
    await pumpSheet(tester);
    expect(find.text('Hazır öneriler'), findsOneWidget);
    expect(find.text('Stüdyo çekimi'), findsOneWidget);
    expect(find.text('Kutuyla sergile'), findsOneWidget);
    expect(find.text('Manken üzerinde'), findsOneWidget);
  });

  testWidgets('chip\'e dokununca metin prompt\'a eklenir', (tester) async {
    await pumpSheet(tester);
    expect(promptText(tester), isEmpty);

    await tester.tap(find.text('Stüdyo çekimi'));
    await tester.pumpAndSettle();

    expect(promptText(tester), contains(studioText));
  });

  testWidgets('birden fazla öneri ardışık eklenebilir', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Stüdyo çekimi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manken üzerinde'));
    await tester.pumpAndSettle();

    final txt = promptText(tester);
    expect(txt, contains(studioText));
    expect(txt, contains(mannequinText));
    // Ayraçla birleştirilmiş olmalı
    expect(txt.contains(', '), isTrue);
  });

  testWidgets('aktif chip\'in X\'ine basınca metin prompt\'tan çıkar', (tester) async {
    await pumpSheet(tester);

    // Ekle
    await tester.tap(find.text('Stüdyo çekimi'));
    await tester.pumpAndSettle();
    expect(promptText(tester), contains(studioText));

    // Aktif chip artık bir delete (X) ikonu gösterir — chip içindeki close ikonunu bul.
    final chip = find.ancestor(
      of: find.text('Stüdyo çekimi'),
      matching: find.byType(InputChip),
    );
    final deleteIcon = find.descendant(of: chip, matching: find.byIcon(Icons.close));
    expect(deleteIcon, findsOneWidget);

    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    expect(promptText(tester), isNot(contains(studioText)));
  });

  testWidgets('metni elle silmek chip\'i otomatik pasifleştirir', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Manken üzerinde'));
    await tester.pumpAndSettle();
    expect(promptText(tester), contains(mannequinText));

    // Prompt'u elle temizle
    final fieldFinder = find.byWidgetPredicate((w) => w is TextField && w.maxLines == 4);
    await tester.enterText(fieldFinder, '');
    await tester.pumpAndSettle();

    // Chip artık delete ikonu göstermemeli (pasif)
    final chip = find.ancestor(
      of: find.text('Manken üzerinde'),
      matching: find.byType(InputChip),
    );
    expect(find.descendant(of: chip, matching: find.byIcon(Icons.close)), findsNothing);
  });
}
