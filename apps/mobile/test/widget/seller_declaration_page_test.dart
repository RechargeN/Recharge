import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/identity/data/seller_declaration_gateway.dart';
import 'package:recharge/features/identity/domain/entities/seller_declaration.dart';
import 'package:recharge/features/identity/domain/repositories/seller_declaration_repository.dart';
import 'package:recharge/features/identity/presentation/pages/seller_declaration_page.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

/// ADR 0023 (2026-11-08, DSA Art. 30): the seller details form and gateway.
final class _ScriptedPort implements SellerDeclarationPort {
  final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
  Map<String, Object?>? stored;
  String? refuse;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async {
    expect(callableName, 'sellerDeclarationV1');
    commands.add(command);
    if (refuse != null) {
      return <String, Object?>{
        'schemaVersion': 1,
        'kind': 'rejected',
        'code': refuse,
      };
    }
    if (command['commandType'] == 'declareSeller') {
      stored = <String, Object?>{
        'schemaVersion': 1,
        'userId': 'server-user',
        'declaration': command['declaration'],
        'revision': ((command['expectedRevision'] as int?) ?? 0) + 1,
        'declaredAtUtc': '2026-11-08T12:00:00.000Z',
      };
    }
    return <String, Object?>{
      'schemaVersion': 1,
      'kind': 'succeeded',
      'data': stored,
    };
  }
}

Widget _app(SellerDeclarationRepository? gateway) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SellerDeclarationPage(
    gateway: Future<SellerDeclarationRepository?>.value(gateway),
  ),
);

void main() {
  test('a private declaration never carries trader data on the wire', () {
    const SellerDeclaration declaration = SellerDeclaration(
      status: SellerStatus.private,
      email: ' me@example.com ',
      trader: TraderDetails(
        legalName: 'X SIA',
        registrationNumber: '40003000000',
        address: SellerAddress(
          line1: 'a',
          city: 'b',
          postalCode: 'LV-1',
          countryCode: 'lv',
        ),
      ),
      dac7ActivityTypes: <Dac7ActivityType>{Dac7ActivityType.rentalOfGoods},
    );
    expect(declaration.toJson(), <String, Object?>{
      'status': 'private',
      'contact': <String, Object?>{'email': 'me@example.com'},
      'dac7ActivityTypes': <String>['rentalOfGoods'],
    });
  });

  test(
    'gateway: refusals become typed failures; empty read is revision 0',
    () async {
      final _ScriptedPort port = _ScriptedPort();
      final SellerDeclarationGateway gateway = SellerDeclarationGateway(
        port,
        requestId: () => 'req',
      );
      final SellerDeclarationRecord empty = await gateway.read();
      expect(empty.revision, 0);
      expect(empty.declaration, isNull);
      port.refuse = 'revision_conflict';
      await expectLater(
        gateway.declare(
          const SellerDeclaration(
            status: SellerStatus.private,
            email: 'a@b.lv',
          ),
          expectedRevision: 0,
        ),
        throwsA(
          isA<SellerDeclarationFailure>().having(
            (SellerDeclarationFailure f) => f.code,
            'code',
            'revision_conflict',
          ),
        ),
      );
      // The payload never names the user: the server takes it from the Session.
      expect(port.commands.every((c) => !c.containsKey('userId')), isTrue);
    },
  );

  testWidgets('saves a private seller and shows the trader fields on demand', (
    WidgetTester tester,
  ) async {
    final _ScriptedPort port = _ScriptedPort();
    await tester.pumpWidget(_app(SellerDeclarationGateway(port)));
    await tester.pumpAndSettle();
    expect(find.text('Seller details'), findsOneWidget);
    // No contact yet: saving is not possible.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('seller-save')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('seller-email')),
      'me@example.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('seller-save')));
    await tester.pumpAndSettle();
    expect(find.text('Seller details saved.'), findsOneWidget);
    final Map<String, Object?> sent = port.commands.last;
    expect(sent['commandType'], 'declareSeller');
    expect(sent['expectedRevision'], 0);
    expect((sent['declaration']! as Map)['status'], 'private');

    expect(
      find.byKey(const ValueKey<String>('seller-legalName')),
      findsNothing,
    );
    await tester.tap(find.text('Business (trader)'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('seller-legalName')),
      findsOneWidget,
    );
    // A trader without registration data is stopped before sending.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('seller-save')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey<String>('seller-save')));
    await tester.pumpAndSettle();
    expect(
      port.commands.where((c) => c['commandType'] == 'declareSeller'),
      hasLength(1),
    );
  });

  testWidgets(
    'without a bound backend the page says the details are unavailable',
    (WidgetTester tester) async {
      await tester.pumpWidget(_app(null));
      await tester.pumpAndSettle();
      expect(
        find.text('Seller details are not available right now.'),
        findsOneWidget,
      );
    },
  );
}
