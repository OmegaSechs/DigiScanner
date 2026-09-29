import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'data/card_repository.dart';
import 'data/collection_repository.dart';
import 'data/deck_repository.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // O scanner assume o aparelho em pé (rotação do OCR).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const DigimonScannerApp());
}

class DigimonScannerApp extends StatelessWidget {
  const DigimonScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final cards = CardRepository(client);
    final collections = CollectionRepository(client);
    final decks = DeckRepository(client);
    return MaterialApp(
      title: 'Digimon Scanner',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.orange,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthState>(
        stream: client.auth.onAuthStateChange,
        builder: (context, _) {
          if (client.auth.currentSession == null) return const AuthScreen();
          return HomeShell(cards: cards, collections: collections, decks: decks);
        },
      ),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Faltam SUPABASE_URL e SUPABASE_ANON_KEY.\n'
                'Rode com --dart-define (veja o README).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
