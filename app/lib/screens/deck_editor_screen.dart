import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/card_repository.dart';
import '../data/deck_repository.dart';
import '../models/card_models.dart';
import '../models/deck_models.dart';
import '../widgets/card_image.dart';

class DeckEditorScreen extends StatefulWidget {
  const DeckEditorScreen({
    super.key,
    required this.repo,
    required this.cards,
    required this.deck,
  });
  final DeckRepository repo;
  final CardRepository cards;
  final DeckSummary deck;

  @override
  State<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends State<DeckEditorScreen> {
  bool _loading = true;
  bool _busy = false; // operações longas (importar/limpar) bloqueiam a tela
  String? _loadError;
  List<DeckCard> _cards = [];
  DeckValidation _validation = DeckValidation.validate(const []);
  List<CostCurveEntry> _curve = [];
  String? _notes;

  @override
  void initState() {
    super.initState();
    _notes = widget.deck.notes;
    _reload(spinner: true);
  }

  void _apply(List<DeckCard> cards) {
    _cards = cards;
    _validation = DeckValidation.validate(cards);
    _curve = CostCurveEntry.fromCards(cards);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Recarrega do servidor. Sem [spinner], a tela e a rolagem são preservadas.
  Future<void> _reload({bool spinner = false}) async {
    if (spinner) setState(() => _loading = true);
    try {
      final cards = await widget.repo.cards(widget.deck.id);
      if (!mounted) return;
      setState(() {
        _apply(cards);
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_cards.isEmpty) _loadError = 'Não foi possível carregar o deck.';
      });
      if (_cards.isNotEmpty) _snack('Não foi possível atualizar o deck.');
    }
  }

  /// Executa uma operação que bloqueia a tela, com tratamento de erro.
  Future<void> _blocking(Future<void> Function() op, {String? error}) async {
    setState(() => _busy = true);
    try {
      await op();
    } catch (_) {
      _snack(error ?? 'Não foi possível concluir a operação.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- quantidades ----------

  Future<void> _changeQuantity(DeckCard card, int delta) async {
    final q = card.quantity + delta;
    if (delta > 0 && q > card.maxCopies) {
      _snack('Limite de ${card.maxCopies} cópia(s) para ${card.name}.');
      return;
    }
    if (q <= 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remover ${card.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
          ],
        ),
      );
      if (ok != true) return;
    }

    // Atualização otimista: a lista muda na hora, sem spinner.
    final next = q <= 0
        ? _cards.where((c) => c.cardCode != card.cardCode).toList()
        : [for (final c in _cards) c.cardCode == card.cardCode ? c.copyWith(quantity: q) : c];
    setState(() => _apply(next));
    try {
      await widget.repo.setCard(widget.deck.id, card.cardCode, q);
    } catch (_) {
      _snack('Não foi possível salvar. Recarregando o deck.');
      await _reload();
    }
  }

  Future<void> _addCard(CardModel card) async {
    if (card.banned) {
      _snack('${card.name} está banida.');
      return;
    }
    final current =
        _cards.where((c) => c.cardCode == card.code).firstOrNull?.quantity ?? 0;
    if (current + 1 > card.maxCopies) {
      _snack('Limite de ${card.maxCopies} cópia(s) para ${card.name}.');
      return;
    }
    try {
      await widget.repo.setCard(widget.deck.id, card.code, current + 1);
      await _reload();
    } catch (_) {
      _snack('Não foi possível adicionar a carta.');
    }
  }

  // ---------- menu ----------

  Future<void> _editNotes() async {
    final controller = TextEditingController(text: _notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notas do deck'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Anotações sobre o deck...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (result == null) return;
    try {
      await widget.repo.updateNotes(widget.deck.id, result);
      if (mounted) setState(() => _notes = result);
    } catch (_) {
      _snack('Não foi possível salvar as notas.');
    }
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar lista'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Ex.:\n4 BT1-010 Agumon\n2 ST1-16',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Importar')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;

    await _blocking(() async {
      final r = await widget.repo.importText(widget.deck.id, text);
      await _reload();
      final msg = StringBuffer('${r.added} cartas importadas.');
      if (r.clamped.isNotEmpty) msg.write(' Reduzidas ao limite: ${r.clamped.join(', ')}.');
      if (r.banned.isNotEmpty) msg.write(' Banidas (ignoradas): ${r.banned.join(', ')}.');
      if (r.notFound.isNotEmpty) msg.write(' Não encontradas: ${r.notFound.join(', ')}.');
      _snack(msg.toString());
    }, error: 'Falha ao importar a lista.');
  }

  Future<void> _export() async {
    try {
      final text = await widget.repo.exportText(widget.deck.id);
      await Clipboard.setData(ClipboardData(text: text));
      _snack('Deck copiado para a área de transferência.');
    } catch (_) {
      _snack('Não foi possível exportar o deck.');
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar deck?'),
        content: const Text('Todas as cartas serão removidas do deck.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Limpar')),
        ],
      ),
    );
    if (ok != true) return;
    await _blocking(() async {
      await widget.repo.clearCards(widget.deck.id);
      await _reload();
    }, error: 'Não foi possível limpar o deck.');
  }

  void _showValidation() {
    showDialog(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Validação do deck'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in _validation.errors)
                  Text('• $e', style: TextStyle(color: scheme.error)),
                for (final w in _validation.warnings) Text('• $w'),
                if (_validation.errors.isEmpty && _validation.warnings.isEmpty)
                  const Text('Nenhum problema encontrado.'),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
        );
      },
    );
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddCardSheet(
        cardsRepo: widget.cards,
        deckCards: () => _cards,
        onAdd: _addCard,
      ),
    );
  }

  // ---------- UI ----------

  Widget _banner() {
    final scheme = Theme.of(context).colorScheme;
    final ok = _validation.isValid;
    final color = ok ? Colors.green : scheme.error;
    final problems = _validation.errors.length;
    return InkWell(
      onTap: _showValidation,
      child: Container(
        color: color.withAlpha(28),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.warning_amber, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_validation.mainCount}/50 cartas · ${_validation.eggCount}/5 ovos'
              '${ok ? '' : ' · $problems problema(s)'}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ]),
      ),
    );
  }

  Widget _costCurve() {
    if (_curve.isEmpty) return const SizedBox.shrink();
    final maxCount = _curve.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    final barColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Curva de custo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in _curve)
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${e.count}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 60 * (maxCount == 0 ? 0 : e.count / maxCount),
                    color: barColor,
                  ),
                  const SizedBox(height: 4),
                  Text('${e.cost}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _section(String title, List<DeckCard> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      for (final c in list)
        ListTile(
          tileColor: c.banned ? scheme.error.withAlpha(25) : null,
          leading: SizedBox(width: 44, height: 62, child: CardImage(c.imageUrl)),
          title: Text(c.name, style: TextStyle(color: c.banned ? scheme.error : null)),
          subtitle: Text([
            c.cardCode,
            if (c.color != null) c.color!,
            if (c.level != null) 'Nv.${c.level}',
            if (c.playCost != null) 'Custo ${c.playCost}',
            if (c.dp != null) 'DP ${c.dp}',
            if (c.maxCopies != 4) 'máx. ${c.maxCopies}',
          ].join(' · ')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Menos',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _changeQuantity(c, -1),
            ),
            Text('${c.quantity}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              tooltip: 'Mais',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: c.quantity < c.maxCopies ? () => _changeQuantity(c, 1) : null,
            ),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final eggs = _cards.where((c) => c.isEgg).toList();
    final mains = _cards.where((c) => !c.isEgg).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'notes':
                  _editNotes();
                case 'import':
                  _import();
                case 'export':
                  _export();
                case 'clear':
                  _clear();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'notes', child: Text('Notas')),
              PopupMenuItem(value: 'import', child: Text('Importar')),
              PopupMenuItem(value: 'export', child: Text('Exportar')),
              PopupMenuItem(value: 'clear', child: Text('Limpar')),
            ],
          ),
        ],
      ),
      body: Stack(children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_loadError != null)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_loadError!),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => _reload(spinner: true), child: const Text('Tentar de novo')),
            ]),
          )
        else
          SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _banner(),
              if (_notes != null && _notes!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(_notes!, style: Theme.of(context).textTheme.bodySmall),
                ),
              _costCurve(),
              const Divider(),
              _section('Digi-Eggs (${_validation.eggCount}/5)', eggs),
              _section('Deck principal (${_validation.mainCount}/50)', mains),
              if (_cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Deck vazio. Toque em + para buscar cartas.')),
                ),
              const SizedBox(height: 88),
            ]),
          ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar cartas',
        onPressed: _openAddSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet({
    required this.cardsRepo,
    required this.deckCards,
    required this.onAdd,
  });
  final CardRepository cardsRepo;
  final List<DeckCard> Function() deckCards;
  final Future<void> Function(CardModel) onAdd;

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _controller = TextEditingController();
  List<CardModel> _results = [];
  bool _searching = false;
  bool _failed = false;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() {}); // atualiza o botão de limpar
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _failed = false;
    });
    try {
      final r = await widget.cardsRepo.search(CardFilters(query: query));
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _searching = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inDeck = {for (final c in widget.deckCards()) c.cardCode: c.quantity};
    Widget body;
    if (_searching) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_failed) {
      body = const Center(child: Text('Falha na busca. Tente de novo.'));
    } else if (_results.isEmpty) {
      body = Center(
        child: Text(_controller.text.trim().isEmpty
            ? 'Digite um nome ou código.'
            : 'Nenhuma carta encontrada.'),
      );
    } else {
      body = GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.66,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _results.length,
        itemBuilder: (context, i) {
          final card = _results[i];
          final qty = inDeck[card.code] ?? 0;
          return GestureDetector(
            onTap: () async {
              await widget.onAdd(card);
              if (mounted) setState(() {}); // atualiza os contadores
            },
            child: Stack(fit: StackFit.expand, children: [
              CardImage(card.thumbnail),
              if (card.banned)
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Chip(label: Text('Banida'), visualDensity: VisualDensity.compact),
                ),
              if (qty > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text('$qty',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary)),
                  ),
                ),
            ]),
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom),
      child: Column(children: [
        TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Buscar por nome ou código',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: body),
      ]),
    );
  }
}
