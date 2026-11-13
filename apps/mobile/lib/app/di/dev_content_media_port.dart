import '../../features/booking/data/booking_callable_adapter.dart';

/// N3a.2 compile-time switch, separate from N2c: the dev Place draft with
/// photos against the dev-cloud Content + Media codebase.
/// `--dart-define=N3A2_DEV_PLACE_DRAFT=true` (debug dev flavor only).
const bool n3a2DevPlaceDraftDefined = bool.fromEnvironment(
  'N3A2_DEV_PLACE_DRAFT',
);

/// The authenticated dev transport for the five Content/Media calls of the
/// dev-cloud runtime. Registered only when the dev auth bundle built it.
final class DevContentMediaPort {
  const DevContentMediaPort(this.port);

  final BookingCallablePort port;
}
