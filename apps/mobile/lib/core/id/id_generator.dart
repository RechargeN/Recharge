import 'package:uuid/uuid.dart';

abstract class IdGenerator {
  String generate();
}

class UuidV4IdGenerator implements IdGenerator {
  UuidV4IdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() => _uuid.v4();
}
