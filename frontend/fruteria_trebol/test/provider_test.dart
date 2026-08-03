import 'package:flutter_test/flutter_test.dart';
import 'package:fruteria_trebol/models/daily_list.dart';
import 'package:fruteria_trebol/models/product.dart';
import 'package:fruteria_trebol/providers/daily_list_provider.dart';

void main() {
  group('DailyListProvider hasUnsavedChanges', () {
    test('detects changes after editing an item', () {
      final provider = DailyListProvider();
      final product = Product(id: 1, name: 'Tomate', category: 'verdura');
      provider.products = [product];
      provider.currentList = DailyList(
        listDate: DateTime(2024, 1, 1),
        items: [
          DailyListItem(productId: product.id, product: product),
        ],
      );

      expect(provider.hasUnsavedChanges, isFalse);

      provider.updateItem(product.id, hay: '5', action: 'TRAE', quantityToBring: '10');

      expect(provider.hasUnsavedChanges, isTrue);
    });

    test('detects changes when notes are updated', () {
      final provider = DailyListProvider();
      final product = Product(id: 1, name: 'Tomate', category: 'verdura');
      provider.products = [product];
      provider.currentList = DailyList(
        listDate: DateTime(2024, 1, 1),
        items: [
          DailyListItem(productId: product.id, product: product),
        ],
      );

      expect(provider.hasUnsavedChanges, isFalse);

      provider.setNotes('Traer mas tomates');

      expect(provider.hasUnsavedChanges, isTrue);
    });
  });
}
