/// Generates opaque permanent identifiers without exposing an implementation
/// package to domain code.
abstract class IdGenerator {
  String generate();
}
