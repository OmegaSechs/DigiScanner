import 'package:flutter/material.dart';
import '../data/collection_repository.dart';
import '../models/collection_models.dart';

const _languages = ['EN', 'JA', 'KO', 'ZH'];
const _conditions = ['NM', 'LP', 'MP', 'HP', 'DMG'];

/// Abre a folha de "adicionar à coleção" para uma impressão específica.
Future<void> showAddToCollectionSheet(
  BuildContext context, {
  required CollectionRepository repo,
  required String printId,
  required String cardName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AddSheet(repo: repo, printId: printId, cardName: cardName),
    ),
  );
}

class _AddSheet extends StatefulWidget {
  const _AddSheet({required this.repo, required this.printId, required this.cardName});
  final CollectionRepository repo;
  final String printId;
  final String cardName;

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  List<CollectionModel>? _collections;
  String? _selected;
  int _qty = 1;
  String _language = 'EN';
  String? _condition;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.repo.listEnsuringDefault();
      if (!mounted) return;
      setState(() {
        _collections = list;
        _selected = list.first.id;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível carregar as coleções.');
    }
  }

  Future<void> _save() async {
    final id = _selected;
    if (id == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.add(
        collectionId: id,
        printId: widget.printId,
        quantity: _qty,
        language: _language,
        condition: _condition,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('$_qty× ${widget.cardName} adicionada.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Falha ao salvar. Tente de novo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = _collections;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: cols == null
            ? SizedBox(
                height: 120,
                child: Center(
                  child: _error != null
                      ? Text(_error!)
                      : const CircularProgressIndicator(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Adicionar ${widget.cardName}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selected,
                    decoration: const InputDecoration(
                        labelText: 'Coleção', border: OutlineInputBorder()),
                    items: [
                      for (final c in cols)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _selected = v),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _language,
                        decoration: const InputDecoration(
                            labelText: 'Idioma', border: OutlineInputBorder()),
                        items: [
                          for (final l in _languages)
                            DropdownMenuItem(value: l, child: Text(l)),
                        ],
                        onChanged: (v) => setState(() => _language = v ?? 'EN'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _condition,
                        decoration: const InputDecoration(
                            labelText: 'Condição', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('—')),
                          for (final c in _conditions)
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setState(() => _condition = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton.outlined(
                      tooltip: 'Menos',
                      onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text('$_qty', style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    IconButton.outlined(
                      tooltip: 'Mais',
                      onPressed: _qty < 99 ? () => setState(() => _qty++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Adicionar'),
                  ),
                ],
              ),
      ),
    );
  }
}
