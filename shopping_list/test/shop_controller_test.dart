import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/app_database.dart';
import 'package:shopping_list/data/product_repository.dart';
import 'package:shopping_list/models/shopping_item.dart';
import 'package:shopping_list/state/shop_controller.dart';

class FakeDatabase extends AppDatabase {
  FakeDatabase(this.items);

  final List<ShoppingItem> items;
  int nextId = 100;

  @override
  Future<List<ShoppingItem>> loadShoppingItems() async => [...items];

  @override
  Future<Map<String, int>> loadCart() async => {};

  @override
  Future<ShoppingItem> addShoppingItem(String name) async {
    final item = ShoppingItem(id: nextId++, name: name);
    items.add(item);
    return item;
  }

  @override
  Future<void> updateShoppingItem(ShoppingItem item) async {}

  @override
  Future<void> deleteShoppingItem(int id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> restoreShoppingItem(ShoppingItem item) async {
    items.add(item);
  }

  @override
  Future<void> close() async {}
}

ShopController buildController(List<ShoppingItem> items) {
  return ShopController(
    database: FakeDatabase(items),
    repository: const ProductRepository(),
  );
}

void main() {
  group('Shopping List+', () {
    test(
      'duplicates ignore spaces and capitals and increase quantity',
      () async {
        final milk = ShoppingItem(id: 1, name: 'Milk');
        final controller = buildController([milk]);
        await controller.initialize();

        final result = await controller.addShoppingItem('  mILK  ');

        expect(result.status, AddShoppingItemStatus.quantityIncreased);
        expect(result.item, same(milk));
        expect(milk.quantity, 2);
        expect(controller.shoppingItems, hasLength(1));
      },
    );

    test('quantity never goes below one', () async {
      final rice = ShoppingItem(id: 2, name: 'Rice');
      final controller = buildController([rice]);
      await controller.initialize();

      await controller.changeShoppingQuantity(rice, -5);

      expect(rice.quantity, 1);
    });

    test(
      'bought items are returned after items left in All ordering',
      () async {
        final milk = ShoppingItem(id: 1, name: 'Milk', bought: true);
        final bread = ShoppingItem(id: 2, name: 'Bread');
        final rice = ShoppingItem(id: 3, name: 'Rice');
        final controller = buildController([milk, bread, rice]);
        await controller.initialize();

        expect(controller.sortedShoppingItems.map((item) => item.name), [
          'Bread',
          'Rice',
          'Milk',
        ]);
      },
    );

    test('delete and undo restore the same object and position', () async {
      final milk = ShoppingItem(id: 1, name: 'Milk');
      final bread = ShoppingItem(
        id: 2,
        name: 'Bread',
        quantity: 3,
        bought: true,
      );
      final rice = ShoppingItem(id: 3, name: 'Rice');
      final controller = buildController([milk, bread, rice]);
      await controller.initialize();

      final index = controller.shoppingItems.indexOf(bread);
      await controller.deleteShoppingItem(bread);
      await controller.restoreShoppingItem(bread, index);

      expect(controller.shoppingItems, [milk, bread, rice]);
      expect(controller.shoppingItems[1].quantity, 3);
      expect(controller.shoppingItems[1].bought, isTrue);
    });

    test('details save name, note, and category together', () async {
      final rice = ShoppingItem(id: 3, name: 'Rice');
      final controller = buildController([rice]);
      await controller.initialize();

      final saved = await controller.updateShoppingItemDetails(
        item: rice,
        name: ' Brown rice ',
        note: ' 1 kg bag ',
        category: ShoppingCategory.home,
      );

      expect(saved, isTrue);
      expect(rice.name, 'Brown rice');
      expect(rice.note, '1 kg bag');
      expect(rice.category, ShoppingCategory.home);
    });

    test(
      'details refuse empty or duplicate names without changing the item',
      () async {
        final milk = ShoppingItem(id: 1, name: 'Milk');
        final rice = ShoppingItem(id: 2, name: 'Rice');
        final controller = buildController([milk, rice]);
        await controller.initialize();

        final emptySaved = await controller.updateShoppingItemDetails(
          item: rice,
          name: '   ',
          note: 'changed',
          category: ShoppingCategory.home,
        );
        final duplicateSaved = await controller.updateShoppingItemDetails(
          item: rice,
          name: 'milk',
          note: 'changed',
          category: ShoppingCategory.home,
        );

        expect(emptySaved, isFalse);
        expect(duplicateSaved, isFalse);
        expect(rice.name, 'Rice');
        expect(rice.note, isEmpty);
        expect(rice.category, ShoppingCategory.food);
      },
    );
  });
}
