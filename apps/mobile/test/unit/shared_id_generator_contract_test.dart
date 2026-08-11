import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart' show UuidV4IdGenerator;
import 'package:recharge/shared/primitives/id/id_generator.dart';

void main() {
  test(
    'domain-facing generator contract has an infrastructure implementation',
    () {
      final IdGenerator generator = UuidV4IdGenerator();

      expect(
        generator.generate(),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    },
  );

  test(
    'tests and domain clients can implement the dependency-free contract',
    () {
      final IdGenerator generator = _SequenceIdGenerator();

      expect(generator.generate(), 'id-1');
      expect(generator.generate(), 'id-2');
    },
  );
}

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'id-${++_next}';
}
