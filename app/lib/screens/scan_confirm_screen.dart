import 'package:flutter/material.dart';

import '../data/card_repository.dart';
import '../models/card_models.dart';
import '../widgets/card_image.dart';
import '../data/collection_repository.dart';
import '../widgets/add_to_collection_sheet.dart';

class ScanConfirmScreen extends StatefulWidget {
  const ScanConfirmScreen({
    super.key,
    required this.repo,
    required this.collections,
    required this.detectedCode,
    this.alternativeCodes,
  });

  final CardRepository repo;
  final CollectionRepository collections;
  final String detectedCode;
  final List<String>? alternativeCodes;

  @override
  State<ScanConfirmScreen> createState() => _ScanConfirmScreenState();
}

class _ScanConfirmScreenState extends State<ScanConfirmScreen> {
  bool _isLoading = true;
  CardModel? _card;
  late String _currentCode;
  PrintModel? _selectedPrint;

  @override
  void initState() {
    super.initState();
    _currentCode = widget.detectedCode;
    _fetchCard(_currentCode);
  }

  Future<void> _fetchCard(String code) async {
    setState(() {
      _isLoading = true;
      _currentCode = code;
      _card = null;
      _selectedPrint = null;
    });

    try {
      final fetchedCard = await widget.repo.byCode(code);
      if (mounted) {
        setState(() {
          _card = fetchedCard;
          if (fetchedCard != null && fetchedCard.prints.isNotEmpty) {
            _selectedPrint = fetchedCard.prints.first;
          }
        });
      }
    } catch (e) {
      // Ignore errors, will show not found
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detectado: $_currentCode'),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_card == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Carta não encontrada\nCódigo: $_currentCode',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.alternativeCodes != null && widget.alternativeCodes!.isNotEmpty)
              _buildAlternatives(),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Large Image
          AspectRatio(
            aspectRatio: 2.5 / 3.5,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: CardImage(_selectedPrint?.imageUrl),
            ),
          ),
          const SizedBox(height: 16),

          // Title and Code
          Text(
            _card!.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          Text(
            _card!.code,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Basic Info
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_card!.type.isNotEmpty) Chip(label: Text('Tipo: ${_card!.type}')),
              if (_card!.color != null) Chip(label: Text('Cor: ${_card!.color}')),
              if (_card!.level != null) Chip(label: Text('Level: ${_card!.level}')),
              if (_card!.playCost != null) Chip(label: Text('Custo: ${_card!.playCost}')),
              if (_card!.dp != null) Chip(label: Text('DP: ${_card!.dp}')),
            ],
          ),
          const SizedBox(height: 24),

          // Print Selector
          if (_card!.prints.length > 1) ...[
            Text(
              'Versões da carta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _card!.prints.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final printModel = _card!.prints[index];
                  final isSelected = _selectedPrint == printModel;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPrint = printModel;
                      });
                    },
                    child: Container(
                      width: 85,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: CardImage(printModel.imageUrl),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Alternatives
          if (widget.alternativeCodes != null && widget.alternativeCodes!.isNotEmpty)
            _buildAlternatives(),
        ],
      ),
    );
  }

  Widget _buildAlternatives() {
    final alternatives = widget.alternativeCodes!.where((c) => c != _currentCode).toList();
    if (alternatives.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Outros códigos detectados',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: alternatives.map((code) {
            return ActionChip(
              label: Text(code),
              onPressed: () => _fetchCard(code),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: (_card == null || _selectedPrint == null)
                  ? null
                  : () {
                      showAddToCollectionSheet(
                        context,
                        repo: widget.collections,
                        printId: _selectedPrint!.id,
                        cardName: _card!.name,
                      ).then((_) {
                        if (mounted) {
                          // Optional: Do something after adding, or just stay on screen
                        }
                      });
                    },
              icon: const Icon(Icons.add),
              label: const Text('Confirmar e adicionar à coleção'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
