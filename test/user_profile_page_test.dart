import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/user_profile_page.dart';

void main() {
  Widget profileFor(String role) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: UserProfilePage(
            displayName: 'María Chato',
            email: 'maria@chato.demo.pe',
            role: role,
            lastSignIn: DateTime(2026, 10, 31, 8),
            onSignOut: () async {},
          ),
        ),
      ),
    );
  }

  testWidgets('profile shows permissions specific to each role', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rolePermissions = {
      'Administrador': 'Usuarios y permisos',
      'Gerente': 'Supervisión de operaciones',
      'Caja': 'Caja y ventas',
      'Pasillo': 'Control de existencias',
    };

    for (final entry in rolePermissions.entries) {
      await tester.pumpWidget(profileFor(entry.key));
      await tester.pumpAndSettle();

      expect(find.text('Mi perfil'), findsOneWidget);
      expect(find.text(entry.key), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('profile shows account details and opens role-specific help', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(profileFor('Caja'));
    await tester.pumpAndSettle();

    expect(find.text('maria@chato.demo.pe'), findsOneWidget);
    expect(find.text('Chincha · Sede principal'), findsOneWidget);
    expect(find.text('31/10/2026 · 08:00'), findsOneWidget);

    await tester.ensureVisible(find.text('Ayuda y guía de recorridos'));
    await tester.tap(find.text('Ayuda y guía de recorridos'));
    await tester.pumpAndSettle();

    expect(find.text('Ayuda para tu perfil'), findsOneWidget);
    expect(
      find.textContaining('Usa Inicio para revisar tu turno'),
      findsOneWidget,
    );
  });
}
