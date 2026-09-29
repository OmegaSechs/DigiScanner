import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CardImage extends StatelessWidget {
  const CardImage(this.url, {super.key, this.fit = BoxFit.cover});
  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    final placeholder = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: const Center(child: Icon(Icons.style_outlined)),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}
