import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/route_gpx_file_selector_adapter.dart';

/// ROUTE-GPX-ANDROID-PICK-01: on Android the system picker filters by MIME
/// type only and a `.gpx` file is typed `application/octet-stream`, so it was
/// greyed out on the B1-device A34. The filter now offers that type; the name
/// is the next gate and the inspector still decides by the bytes.
void main() {
  test('the picker filter offers the type Android gives a .gpx file', () {
    const group = RouteGpxFileSelectorAdapter.gpxTypeGroup;
    expect(
      group.mimeTypes,
      containsAll(<String>[
        'application/gpx+xml',
        'application/xml',
        'text/xml',
        'application/octet-stream',
      ]),
    );
    expect(group.extensions, <String>['gpx']);
    expect(group.uniformTypeIdentifiers, <String>['com.topografix.gpx']);
    expect(group.mimeTypes, isNot(contains('*/*')), reason: 'never everything');
  });

  test('the Android cache rename by MIME type is undone, nothing else', () {
    // As seen on the A34: Downloads/route.gpx, octet-stream, cached as .bin.
    expect(
      gpxDisplayName('recharge-b1-device.bin', 'application/octet-stream'),
      'recharge-b1-device.gpx',
    );
    expect(gpxDisplayName('Ride.XML', 'text/xml'), 'Ride.gpx');
    expect(gpxDisplayName('ride.xml', 'application/xml'), 'ride.gpx');
    expect(gpxDisplayName('route.gpx', null), 'route.gpx');
    expect(
      gpxDisplayName('route.gpx', 'application/octet-stream'),
      'route.gpx',
    );
    for (final (String name, String? mime) in <(String, String?)>[
      ('photo.jpg', 'image/jpeg'),
      ('route.bin', null),
      ('route.bin', 'application/xml'),
      ('route.xml', 'application/octet-stream'),
      ('route.zip', 'application/zip'),
      ('.bin', 'application/octet-stream'),
      ('route.kml', 'application/vnd.google-earth.kml+xml'),
    ]) {
      expect(gpxDisplayName(name, mime), isNull, reason: '$name $mime');
    }
  });

  test('only a .gpx name passes before any byte is read', () {
    for (final String name in <String>[
      'route.gpx',
      'ROUTE.GPX',
      'Morning ride.Gpx',
      ' trimmed.gpx ',
    ]) {
      expect(isGpxFileName(name), isTrue, reason: name);
    }
    for (final String name in <String>[
      'route.gpx.zip',
      'route.kml',
      'photo.jpg',
      'gpx',
      'route.gpxx',
      '',
    ]) {
      expect(isGpxFileName(name), isFalse, reason: name);
    }
  });
}
