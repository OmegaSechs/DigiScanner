import 'package:flutter/material.dart';
import '../data/collection_repository.dart';
import '../models/collection_models.dart';
import '../widgets/card_image.dart';

class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({super.key, required this.repo, required this.collection});
  final CollectionRepository repo;
  final CollectionModel collection;

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  List<CollectionItem>? _items;
  String? _error;
  final _busy = <String>{}; // itens com atualização em andamento

  String _key(CollectionItem i) => '${i.printId}|${i.language}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repo.items(widget.collection.id);
      if (mounted) setState(() {
        _items = items;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível carregar a coleção.');
    }
  }

  Future<void> _change(CollectionItem item, int delta) async {
    final key = _key(item);
    if (_busy.contains(key)) return;
    final q = item.quantity + delta;
    if (q <= 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remover ${item.cardName}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (q > 99) return;
    setState(() => _busy.add(key));
    try {
      await widget.repo.setQuantity(widget.collection.id, item, q);
      if (!mounted) return;
      setState(() {
        final list = _items!;
        final idx = list.indexWhere((e) => _key(e) == key);
        if (idx >= 0) {
          if (q <= 0) {
            list.removeAt(idx);
          } else {
            list[idx] = list[idx].withQuantity(q);
          }
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Não foi possível atualizar.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final total = items?.fold<int>(0, (s, e) => s + e.quantity) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection.name),
        bottom: items == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('$total cartas · ${items.length} únicas'),
                ),
              ),
      ),
      body: _body(items),
    );
  }

  Widget _body(List<CollectionItem>? items) {
    if (_error != null && items == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
        ]),
      );
    }
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhuma carta ainda.\nAbra uma carta na aba Cartas e toque em "Adicionar à coleção".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final it = items[i];
          final busy = _busy.contains(_key(it));
          final meta = [
            it.cardCode,
            if (it.isAlternate) 'alt.',
            if (it.rarity != null) it.rarity!,
            it.language,
            if (it.condition != null) it.condition!,
          ].join(' · ');
          return ListTile(
            leading: SizedBox(width: 44, height: 62, child: CardImage(it.imageUrl)),
            title: Text(it.cardName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(meta),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Menos',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: busy ? null : () => _change(it, -1),
              ),
              SizedBox(
                width: 28,
                child: Text('${it.quantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Mais',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: busy || it.quantity >= 99 ? null : () => _change(it, 1),
              ),
            ]),
          );
        },
      ),
    );
  }
}
