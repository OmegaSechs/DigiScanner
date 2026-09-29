import 'package:flutter/material.dart';
import '../data/card_repository.dart';
import '../data/collection_repository.dart';
import '../models/card_models.dart';
import '../widgets/add_to_collection_sheet.dart';
import '../widgets/card_image.dart';

class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({
    super.key,
    required this.repo,
    required this.collections,
    required this.code,
    this.preview,
  });
  final CardRepository repo;
  final CollectionRepository collections;
  final String code;
  final CardModel? preview; // mostrado enquanto carrega o detalhe completo

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  CardModel? _card;
  bool _failed = false;
  int _printIndex = 0;

  @override
  void initState() {
    super.initState();
    _card = widget.preview;
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final c = await widget.repo.byCode(widget.code);
      if (!mounted) return;
      setState(() {
        _card = c ?? _card;
        _failed = _card == null;
      });
    } catch (_) {
      if (mounted && _card == null) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _card;
    return Scaffold(
      appBar: AppBar(title: Text(c?.code ?? widget.code)),
      body: c == null
          ? Center(
              child: _failed
                  ? const Text('Carta não encontrada.')
                  : const CircularProgressIndicator())
          : _content(context, c),
      floatingActionButton: c == null || c.prints.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddToCollectionSheet(
                context,
                repo: widget.collections,
                printId: c.prints[_printIndex.clamp(0, c.prints.length - 1)].id,
                cardName: c.name,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar à coleção'),
            ),
    );
  }

  String _evoText(Map<String, dynamic> e) {
    final extra = [
      if (e['color'] != null) '${e['color']}',
      if (e['level'] != null) 'Lv.${e['level']}',
    ].join(' ');
    return 'custo ${e['cost']}${extra.isEmpty ? '' : ' ($extra)'}';
  }

  Widget _content(BuildContext context, CardModel c) {
    final text = Theme.of(context).textTheme;
    final idx = c.prints.isEmpty ? 0 : _printIndex.clamp(0, c.prints.length - 1);
    final current = c.prints.isEmpty ? null : c.prints[idx];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: CardImage(current?.imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
        if (c.prints.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: c.prints.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _printIndex = i),
                child: Container(
                  width: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      width: 2,
                      color: i == idx
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: CardImage(c.prints[i].imageUrl),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(c.name, style: text.headlineSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Chip(label: Text(c.type)),
          if (c.color != null) Chip(label: Text(c.color!)),
          if (c.color2 != null) Chip(label: Text(c.color2!)),
          if (c.level != null) Chip(label: Text('Lv.${c.level}')),
          if (current?.rarity != null) Chip(label: Text(current!.rarity!)),
        ]),
        const SizedBox(height: 12),
        _row('Custo de jogo', c.playCost),
        _row('DP', c.dp),
        _row('Forma', c.form),
        _row('Atributo', c.attribute),
        _row('Digi-Type', c.digiTypes.isEmpty ? null : c.digiTypes.join(' / ')),
        for (final e in c.evolutions) _row('Evolução', _evoText(e)),
        _row('Artista', current?.artist),
        _effect(context, 'Efeito principal', c.mainEffect),
        _effect(context, 'Efeito herdado', c.sourceEffect),
        _effect(context, 'Efeito alternativo', c.altEffect),
      ],
    );
  }

  Widget _row(String label, Object? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text('$value')),
      ]),
    );
  }

  Widget _effect(BuildContext context, String title, String? body) {
    if (body == null || body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(body),
      ]),
    );
  }
}
