import 'package:uuid/uuid.dart';

import '../../shared/primitives/id/id_generator.dart';

export '../../shared/primitives/id/id_generator.dart';

class UuidV4IdGenerator implements IdGenerator {
  UuidV4IdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() => _uuid.v4();
}
