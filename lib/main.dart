import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_config.dart';
import 'login_page.dart';
import 'loading_page.dart';
import 'operations_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ImportacionesChatoApp());
}

class ImportacionesChatoApp extends StatelessWidget {
  const ImportacionesChatoApp({super.key, this.firebaseConfiguredOverride});

  final bool? firebaseConfiguredOverride;

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF07382D);
    const green = Color(0xFF07835F);

    return MaterialApp(
      title: 'Importaciones Chato',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F6F4),
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          primary: green,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: forest,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFDCE7E1)),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDCE7E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDCE7E1)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
      home: FirebaseBootstrap(
        firebaseConfiguredOverride: firebaseConfiguredOverride,
      ),
    );
  }
}

class FirebaseBootstrap extends StatefulWidget {
  const FirebaseBootstrap({super.key, this.firebaseConfiguredOverride});

  final bool? firebaseConfiguredOverride;

  @override
  State<FirebaseBootstrap> createState() => _FirebaseBootstrapState();
}

class _FirebaseBootstrapState extends State<FirebaseBootstrap> {
  late final Future<FirebaseApp>? _initialization =
      (widget.firebaseConfiguredOverride ?? FirebaseConfig.isConfigured)
      ? _initializeFirebase()
      : null;

  Future<FirebaseApp> _initializeFirebase() async {
    final minimumLoadingDuration = Future<void>.delayed(
      const Duration(milliseconds: 1500),
    );
    final app = await FirebaseConfig.initializeApp();
    await minimumLoadingDuration;
    return app;
  }

  @override
  Widget build(BuildContext context) {
    final configured =
        widget.firebaseConfiguredOverride ?? FirebaseConfig.isConfigured;
    if (!configured) {
      return const LoginPage(firebaseConfigured: false);
    }

    final initialization = _initialization;
    if (initialization == null) {
      return const LoginPage(firebaseConfigured: false);
    }

    return FutureBuilder<FirebaseApp>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SetupErrorPage(
            message: 'No se pudo iniciar Firebase: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingPage(
            message: 'Iniciando servicios seguros...',
          );
        }
        return const AuthenticationGate();
      },
    );
  }
}

class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          return SetupErrorPage(
            message: 'No se pudo comprobar la sesión: ${authSnapshot.error}',
          );
        }
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingPage(message: 'Verificando tu sesión...');
        }
        if (!authSnapshot.hasData) {
          return const LoginPage(firebaseConfigured: true);
        }

        final user = authSnapshot.data!;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              final error = profileSnapshot.error;
              return AccessNoticePage(
                title: 'No se pudo validar tu perfil',
                message: _profileReadErrorMessage(error),
                onSignOut: FirebaseAuth.instance.signOut,
              );
            }
            if (!profileSnapshot.hasData) {
              return const AppLoadingPage(message: 'Cargando tu perfil...');
            }

            final profile = profileSnapshot.data;
            final data = profile?.data();
            final role = data?['role'];
            if (profile == null ||
                !profile.exists ||
                data?['active'] != true ||
                role is! String ||
                !const {
                  'Administrador',
                  'Gerente',
                  'Caja',
                  'Pasillo',
                }.contains(role)) {
              return AccessNoticePage(
                title: 'Tu cuenta aún no tiene acceso operativo',
                message: 'Un responsable debe crear un perfil activo en Firestore y asignar un rol autorizado. No hay registro público ni selección de roles en la aplicación.',
                onSignOut: FirebaseAuth.instance.signOut,
              );
            }

            return OperationsPage(
              user: user,
              role: role,
              displayName:
                  (data?['displayName'] as String?) ?? user.email ?? 'Admin',
            );
          },
        );
      },
    );
  }
}

String _profileReadErrorMessage(Object? error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Firestore no permitió leer tu perfil. Verifica que exista users/{UID} '
            'con el UID de esta cuenta y que las reglas publicadas permitan '
            'a cada usuario leer su propio perfil.',
      'unavailable' =>
        'No se pudo conectar con Firestore. Revisa tu conexión a internet e '
            'inténtalo nuevamente.',
      _ =>
        'Firestore no pudo leer tu perfil (${error.code}). '
            'Revisa la configuración y las reglas de acceso.',
    };
  }
  return 'No se pudo leer tu perfil de Firestore. Revisa tu conexión y las '
      'reglas de acceso, e inténtalo nuevamente.';
}

class SetupErrorPage extends StatelessWidget {
  const SetupErrorPage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 44,
                      color: Color(0xFFAE4545),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudo conectar con Firebase',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    const Text(
                      'Verifica las opciones de la app, el ID del proyecto y la configuración de Authentication.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF61756C)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccessNoticePage extends StatelessWidget {
  const AccessNoticePage({
    required this.title,
    required this.message,
    required this.onSignOut,
    super.key,
  });

  final String title;
  final String message;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importaciones Chato')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 44,
                      color: Color(0xFF07835F),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: onSignOut,
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
