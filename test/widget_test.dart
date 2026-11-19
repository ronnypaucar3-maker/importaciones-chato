import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/loading_page.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/password_recovery_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> showSignIn(WidgetTester tester, bool configured) async {
    await tester.pumpWidget(
      ImportacionesChatoApp(firebaseConfiguredOverride: configured),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('startup loading screen shows brand and progress, not sign-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AppLoadingPage()));
    await tester.pump();

    expect(find.text('IMPORTACIONES'), findsOneWidget);
    expect(find.text('CHATO'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('CARGANDO APLICACIÓN'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup loading screen remains usable in landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AppLoadingPage()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('unconfigured app goes directly to sign-in', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showSignIn(tester, false);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Preparando tu espacio de trabajo...'), findsNothing);
    expect(
      find.text(
        'Configuración pendiente · falta registrar y configurar las apps de Firebase',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('No hay registro público'), findsOneWidget);
  });

  testWidgets('sign-in explains missing Firebase configuration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showSignIn(tester, false);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'nombre@empresa.pe'),
      'admin@importacioneschato.pe',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ingresa tu contraseña'),
      'password123',
    );
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('falta registrar las apps web y Android'),
      findsOneWidget,
    );
    expect(find.text('El equipo, bajo control'), findsNothing);
  });

  testWidgets('login uses the original light background and green action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showSignIn(tester, false);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(scaffold.backgroundColor, const Color(0xFFF2F6F4));
    expect(
      button.style?.backgroundColor?.resolve(const {}),
      const Color(0xFF07835F),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('login layout remains usable on a browser viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showSignIn(tester, false);

    expect(find.text('Todo tu negocio,\nen orden.'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login layout remains usable on a rotated phone', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showSignIn(tester, false);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forgot password opens the recovery page with the email', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showSignIn(tester, false);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'nombre@empresa.pe'),
      'ana@empresa.pe',
    );
    await tester.ensureVisible(find.text('Olvidé mi contraseña'));
    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('Recupera tu acceso'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      'ana@empresa.pe',
    );
    expect(find.text('Enviar instrucciones'), findsOneWidget);
    await tester.ensureVisible(find.text('Volver al inicio de sesión'));
    await tester.tap(find.text('Volver al inicio de sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('recovery validates the email before sending', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var wasRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PasswordRecoveryPage(
          firebaseConfigured: true,
          onSendPasswordReset: (_) async {
            wasRequested = true;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'correo-invalido');
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
    expect(wasRequested, isFalse);
  });

  testWidgets('recovery sends a generic confirmation for unknown accounts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? requestedEmail;

    await tester.pumpWidget(
      MaterialApp(
        home: PasswordRecoveryPage(
          firebaseConfigured: true,
          onSendPasswordReset: (email) async {
            requestedEmail = email;
            throw FirebaseAuthException(code: 'user-not-found');
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'ana@empresa.pe');
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(requestedEmail, 'ana@empresa.pe');
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.textContaining('Si el correo está registrado'), findsOneWidget);
    expect(find.text('CORREO INDICADO'), findsOneWidget);
    expect(find.text('Volver a iniciar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery confirmation can resend and edit the email', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PasswordRecoveryPage(
          firebaseConfigured: true,
          onSendPasswordReset: (_) async {
            requests++;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'ana@empresa.pe');
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.text('ana@empresa.pe'), findsOneWidget);
    expect(find.text('Reenviar instrucciones'), findsOneWidget);

    await tester.ensureVisible(find.text('Reenviar instrucciones'));
    await tester.tap(find.text('Reenviar instrucciones'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Revisa tu correo'), findsOneWidget);

    await tester.ensureVisible(
      find.text('¿El correo es incorrecto? Revisar dirección'),
    );
    await tester.tap(find.text('¿El correo es incorrecto? Revisar dirección'));
    await tester.pumpAndSettle();
    expect(find.text('Recupera tu acceso'), findsOneWidget);
    expect(find.text('Enviar instrucciones'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      'ana@empresa.pe',
    );
  });

  testWidgets('recovery confirmation returns to sign-in', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => PasswordRecoveryPage(
                        firebaseConfigured: true,
                        onSendPasswordReset: (_) async {},
                      ),
                    ),
                  );
                },
                child: const Text('Iniciar sesión'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'ana@empresa.pe');
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Volver a iniciar sesión'));
    await tester.tap(find.text('Volver a iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('recovery page remains usable on a rotated phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PasswordRecoveryPage(
          firebaseConfigured: true,
          onSendPasswordReset: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Recupera tu acceso'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'ana@empresa.pe');
    await tester.ensureVisible(find.text('Enviar instrucciones'));
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
