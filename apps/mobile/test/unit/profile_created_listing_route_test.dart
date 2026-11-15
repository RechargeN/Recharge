import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/features/explore/presentation/pages/profile_page.dart';

/// A34 2026-11-13: in the profile, a draft card opened search instead of its
/// editor. A draft now opens Create; a published card still leads to search.
void main() {
  test('a draft opens its editor, never search', () {
    var searched = false;
    final String route = profileCreatedListingRoute(
      isPublished: false,
      searchRoute: () {
        searched = true;
        return RouteNames.search;
      },
    );
    expect(route, RouteNames.create);
    expect(searched, isFalse);
  });

  test('a published card keeps leading to search', () {
    expect(
      profileCreatedListingRoute(
        isPublished: true,
        searchRoute: () => '${RouteNames.search}?q=x',
      ),
      '${RouteNames.search}?q=x',
    );
  });
}
