import 'package:flutter/material.dart';
import '../data/card_repository.dart';
import '../data/collection_repository.dart';
import '../data/deck_repository.dart';
import 'collections_screen.dart';
import 'decks_screen.dart';
import 'scanner_screen.dart';
import 'search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.cards,
    required this.collections,
    required this.decks,
  });
  final CardRepository cards;
  final CollectionRepository collections;
  final DeckRepository decks;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        SearchScreen(repo: widget.cards, collections: widget.collections),
        ScannerScreen(
          cards: widget.cards,
          collections: widget.collections,
          isActive: _index == 1, // a câmera só liga nesta aba
        ),
        CollectionsScreen(repo: widget.collections, isActive: _index == 2),
        DecksScreen(repo: widget.decks, cards: widget.cards, isActive: _index == 3),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Cartas'),
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), label: 'Scanner'),
          NavigationDestination(icon: Icon(Icons.collections_bookmark_outlined), label: 'Coleções'),
          NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Decks'),
        ],
      ),
    );
  }
}
