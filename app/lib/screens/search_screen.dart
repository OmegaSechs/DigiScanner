import 'dart:async';
import 'package:flutter/material.dart';
import '../data/card_repository.dart';
import '../data/collection_repository.dart';
import '../models/card_models.dart';
import '../widgets/card_image.dart';
import 'card_detail_screen.dart';

const _types = ['Digimon', 'Digi-Egg', 'Tamer', 'Option'];
const _colors = ['Red', 'Blue', 'Yellow', 'Green', 'Black', 'Purple', 'White'];
const _levels = [2, 3, 4, 5, 6, 7];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.repo, required this.collections});
  final CardRepository repo;
  final CollectionRepository collections;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _scroll = ScrollController();
  final _cards = <CardModel>[];
  CardFilters _filters = const CardFilters();
  Timer? _debounce;
  int _page = 0;
  int _requestId = 0; // descarta respostas antigas
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _load();
      }
    });
    _reset();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _reset() {
    _requestId++;
    setState(() {
      _cards.clear();
      _page = 0;
      _done = false;
      _error = null;
      _loading = false;
    });
    _load();
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    final id = _requestId;
    setState(() => _loading = true);
    try {
      final batch = await widget.repo.search(_filters, page: _page);
      if (id != _requestId || !mounted) return;
      setState(() {
        _cards.addAll(batch);
        _page++;
        _done = batch.length < CardRepository.pageSize;
        _loading = false;
      });
    } catch (_) {
      if (id != _requestId || !mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as cartas.';
        _loading = false;
      });
    }
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _filters = _filters.copyWith(query: v);
      _reset();
    });
  }

  void _toggleType(String v) {
    _filters = _filters.copyWith(type: _filters.type == v ? null : v);
    _reset();
  }

  void _toggleColor(String v) {
    _filters = _filters.copyWith(color: _filters.color == v ? null : v);
    _reset();
  }

  void _toggleLevel(int v) {
    _filters = _filters.copyWith(level: _filters.level == v ? null : v);
    _reset();
  }

  Widget _chipRow(List<Widget> chips) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final c in chips)
              Padding(padding: const EdgeInsets.only(right: 6), child: c),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: _onQuery,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Nome ou código (ex: BT1-010)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _chipRow([
            for (final t in _types)
              FilterChip(
                label: Text(t),
                selected: _filters.type == t,
                onSelected: (_) => _toggleType(t),
              ),
          ]),
          _chipRow([
            for (final c in _colors)
              FilterChip(
                label: Text(c),
                selected: _filters.color == c,
                onSelected: (_) => _toggleColor(c),
              ),
          ]),
          _chipRow([
            for (final l in _levels)
              FilterChip(
                label: Text('Lv.$l'),
                selected: _filters.level == l,
                onSelected: (_) => _toggleLevel(l),
              ),
          ]),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null && _cards.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 8),
          FilledButton(onPressed: _reset, child: const Text('Tentar de novo')),
        ]),
      );
    }
    if (_cards.isEmpty && !_loading) {
      return const Center(child: Text('Nenhuma carta encontrada.'));
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.66,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _cards.length + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _cards.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final c = _cards[i];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CardDetailScreen(
              repo: widget.repo,
              collections: widget.collections,
              code: c.code,
              preview: c,
            ),
          )),
          child: Semantics(
            label: '${c.name}, ${c.code}',
            child: CardImage(c.thumbnail),
          ),
        );
      },
    );
  }
}
