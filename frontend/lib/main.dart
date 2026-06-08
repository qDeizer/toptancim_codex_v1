import 'package:flutter/material.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/category_provider.dart';
import 'package:frontend/providers/connection_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/shop_provider.dart';
import 'package:frontend/providers/tag_assignment_provider.dart';
import 'package:frontend/providers/tag_provider.dart';
import 'package:frontend/providers/transaction_provider.dart';
import 'package:frontend/providers/wholesaler_order_provider.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/providers/ai_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() {
  initializeDateFormatting('tr_TR', null).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, CategoryProvider>(
          create: (ctx) => CategoryProvider(null),
          update: (ctx, auth, previous) => CategoryProvider(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TagProvider>(
          create: (ctx) => TagProvider(null),
          update: (ctx, auth, previous) => TagProvider(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ConnectionProvider>(
          create: (ctx) => ConnectionProvider(null),
          update: (ctx, auth, previous) => ConnectionProvider(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TagAssignmentProvider>(
          create: (ctx) => TagAssignmentProvider(null),
          update: (ctx, auth, previous) => TagAssignmentProvider(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (ctx) => TransactionProvider(null),
          update: (ctx, auth, previous) => TransactionProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ShopProvider>(
          create: (ctx) => ShopProvider(null),
          update: (ctx, auth, previous) => ShopProvider(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (ctx) => CartProvider(null),
          update: (ctx, auth, previous) {
            final provider = previous ?? CartProvider(auth.token);
            provider.updateAuth(auth.token);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (ctx) => NotificationProvider(null),
          update: (ctx, auth, previous) {
            final provider = previous ?? NotificationProvider(auth.token);
            provider.updateAuth(auth.token);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AiProvider>(
          create: (ctx) => AiProvider(null),
          update: (ctx, auth, previous) {
            final provider = previous ?? AiProvider(auth.token);
            provider.updateAuth(auth.token);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, WholesalerOrderProvider>(
          create: (ctx) => WholesalerOrderProvider(null),
          update: (ctx, auth, previous) => WholesalerOrderProvider(auth.token),
        ),
        ChangeNotifierProxyProvider3<AuthProvider, CategoryProvider,
            TagProvider, ProductProvider>(
          create: (ctx) => ProductProvider(null, [], [], []),
          update: (ctx, auth, categoryProvider, tagProvider,
                  previousProductProvider) =>
              ProductProvider(
            auth.token,
            previousProductProvider?.products ?? [],
            categoryProvider.categories,
            tagProvider.tags,
          ),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (ctx, auth, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Toptancım',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              strokeWidth: 3,
            ),
          ),
          home: Consumer<AuthProvider>(
            builder: (ctx, auth, _) {
              if (!auth.isAuthCheckComplete) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              return auth.isAuthenticated
                  ? const HomeScreen()
                  : const LoginScreen();
            },
          ),
        ),
      ),
    );
  }
}
