import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driver_mobile/main.dart';
import 'package:driver_mobile/screens/login_screen.dart';
import 'package:driver_mobile/services/s2r_routing_service.dart';

void main() {
  testWidgets('GuideLankaDriverApp boots to LoginScreen when unauthenticated', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const GuideLankaDriverApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('GuideLanka'), findsOneWidget);
    expect(find.text('DRIVER PORTAL'), findsOneWidget);
  });

  test('S2R routing helpers return valid lifespans and positive distances', () {
    expect(S2RRoutingService.getAnimalMaxLifespan('elephant'), 60.0);
    expect(S2RRoutingService.getAnimalMaxLifespan('leopard'), 30.0);
    expect(S2RRoutingService.getAnimalMaxLifespan('deer'), 15.0);

    final dist = S2RRoutingService.distanceMeters(
      const LatLng(6.5403, 81.3053),
      const LatLng(6.5503, 81.3053),
    );
    expect(dist, greaterThan(1000.0));
    expect(dist, lessThan(1200.0));
  });
}
