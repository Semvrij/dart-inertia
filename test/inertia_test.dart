import 'package:inertia/inertia.dart';
import 'package:test/test.dart';

void main() {
  group('Inertia', () {
    test('Lazy prop', () {
      final lazy = Inertia.lazy(() => 123);

      expect(lazy(), 123);
    });
  });
}
