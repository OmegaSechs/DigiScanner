import 'package:flutter/material.dart';
import '../data/deck_repository.dart';
import '../models/deck_models.dart';
import 'deck_editor_screen.dart';
import '../data/card_repository.dart';

class DecksScreen extends StatefulWidget {
  const DecksScreen({
    super.key,
    required this.repo,
    required this.cards,
    this.isActive = true,
  });

  final DeckRepository repo;
  final CardRepository cards;
  final bool isActive;

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  List<DeckSummary>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(DecksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    try {
      final items = await widget.repo.list();
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'load';
      });
    }
  }

  Future<void> _guard(Future<void> Function() fn) async {
    try {
      await fn();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível concluir a operação.')),
      );
    }
  }

  Future<String?> _askName([String? current]) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(current == null ? 'Novo Baralho' : 'Renomear Baralho'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (val) => Navigator.pop(context, val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final name = await _askName();
    if (name == null || name.isEmpty) return;
    await _guard(() => widget.repo.create(name));
  }

  Future<void> _rename(DeckSummary deck) async {
    final name = await _askName(deck.name);
    if (name == null || name.isEmpty || name == deck.name) return;
    await _guard(() => widget.repo.rename(deck.id, name));
  }

  Future<void> _delete(DeckSummary deck) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir baralho?'),
        content: Text('Tem certeza que deseja excluir "${deck.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _guard(() => widget.repo.delete(deck.id));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    Widget body;
    if (_error != null) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Não foi possível carregar os decks.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    } else if (_items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items!.isEmpty) {
      body = Center(
        child: Text(
          'Nenhum baralho encontrado.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    } else {
      body = ListView.builder(
        itemCount: _items!.length,
        itemBuilder: (context, index) {
          final deck = _items![index];
          final isValid = deck.isComplete;
          
          return ListTile(
            title: Text(deck.name),
            subtitle: Text('${deck.cardCount}/50 cartas · ${deck.eggCount}/5 ovos'),
            leading: Icon(
              isValid ? Icons.check_circle : Icons.error_outline,
              color: isValid ? Colors.green : Colors.red,
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'rename') _rename(deck);
                if (val == 'delete') _delete(deck);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Renomear'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir'),
                ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeckEditorScreen(
                    repo: widget.repo,
                    cards: widget.cards,
                    deck: deck,
                  ),
                ),
              );
              _load();
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Baralhos'),
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
    );
  }
}
