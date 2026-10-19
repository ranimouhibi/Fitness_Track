import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/store_models.dart';

class StoreProductImage extends StatelessWidget {
  final List<String> paths;
  final double size;

  const StoreProductImage({super.key, required this.paths, this.size = 88});

  @override
  Widget build(BuildContext context) {
    final path = paths.isEmpty ? null : paths.first;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? const Icon(Icons.shopping_bag_outlined, color: AppColors.deepBlue)
          : Image.file(
              File(path),
              fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                  const Icon(Icons.image_not_supported_outlined, color: AppColors.deepBlue),
            ),
    );
  }
}

class StoreProductTile extends StatelessWidget {
  final StoreProduct product;
  final VoidCallback? onTap;
  final Widget? action;
  final String? statusLabel;

  const StoreProductTile({
    super.key,
    required this.product,
    this.onTap,
    this.action,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              StoreProductImage(paths: product.imagePaths, size: 64),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_categoryLabel(product.category)} · ${product.stock > 0 ? '${product.stock} available' : 'Out of stock'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (product.sellerName != null)
                      Text(
                        'By ${product.sellerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    if (statusLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          statusLabel!,
                          style: const TextStyle(
                            color: AppColors.deepBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_price(product.priceTnd)} TND',
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 5),
                    action!,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const StoreMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String storePrice(double value) => value.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');

String storeCategoryLabel(String category) => switch (category) {
      'training_gear' => 'Training gear',
      'supplement' => 'Supplement',
      _ => category,
    };

String _categoryLabel(String category) => storeCategoryLabel(category);
String _price(double value) => storePrice(value);
