import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/collection_repository.dart';
import '../models/collection_models.dart';
import 'collection_detail_screen.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key, required this.repo, this.isActive = true});
  final CollectionRepository repo;
  final bool isActive; // recarrega ao voltar para a aba

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<CollectionModel>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CollectionsScreen old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.repo.listEnsuringDefault();
      if (mounted) setState(() {
        _items = list;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível carregar as coleções.');
    }
  }

  Future<String?> _askName(String title, {String initial = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Salvar')),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final name = await _askName('Nova coleção');
    if (name == null || name.isEmpty) return;
    await _guard(() => widget.repo.create(name));
  }

  Future<void> _rename(CollectionModel c) async {
    final name = await _askName('Renomear', initial: c.name);
    if (name == null || name.isEmpty || name == c.name) return;
    await _guard(() => widget.repo.rename(c.id, name));
  }

  Future<void> _delete(CollectionModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${c.name}"?'),
        content: Text(c.totalCards == 0
            ? 'A coleção está vazia.'
            : 'As ${c.totalCards} cartas dela serão removidas da coleção.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) await _guard(() => widget.repo.delete(c.id));
  }

  Future<void> _guard(Future<void> Function() op) async {
    try {
      await op();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Não foi possível concluir.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coleções'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null && _items == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
        ]),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = items[i];
          return ListTile(
            title: Text(c.name),
            subtitle: Text('${c.totalCards} cartas · ${c.uniquePrints} únicas'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => v == 'rename' ? _rename(c) : _delete(c),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Renomear')),
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CollectionDetailScreen(repo: widget.repo, collection: c),
              ));
              _load();
            },
          );
        },
      ),
    );
  }
}
