import 'package:uuid/uuid.dart';
import 'dart:math';

import '../../shared/primitives/id/id_generator.dart';

export '../../shared/primitives/id/id_generator.dart';

class UuidV4IdGenerator implements IdGenerator {
  UuidV4IdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() => _uuid.v4();
}

/// Scenario creation uses ULID without changing other aggregates' ID policy.
class UlidIdGenerator implements IdGenerator {
  final Random _random = Random.secure();
  @override
  String generate() {
    const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    var value = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    for (var i = 0; i < 10; i++) {
      value = (value << 8) | BigInt.from(_random.nextInt(256));
    }
    final chars = List.filled(26, '0');
    for (var i = 25; i >= 0; i--) {
      chars[i] = alphabet[(value & BigInt.from(31)).toInt()];
      value >>= 5;
    }
    return chars.join();
  }
}
