import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_widgets.dart';
import 'firebase_config.dart';
import 'password_recovery_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.firebaseConfigured, super.key});

  final bool firebaseConfigured;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberEmail = false;
  bool _showPassword = false;
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _restoreEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreEmail() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final email = preferences.getString('remembered_work_email');
      if (!mounted || email == null) return;
      setState(() {
        _emailController.text = email;
        _rememberEmail = true;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'No se pudo leer la preferencia local: ${error.message}';
        _isError = true;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _message =
            'El almacenamiento local no está disponible en este dispositivo.';
        _isError = true;
      });
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.firebaseConfigured || !FirebaseConfig.isConfigured) {
      setState(() {
        _message = 'El acceso está preparado, pero falta registrar las apps web y Android y cargar su configuración de Firebase.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final preferences = await SharedPreferences.getInstance();
      if (_rememberEmail) {
        await preferences.setString(
          'remembered_work_email',
          _emailController.text.trim(),
        );
      } else {
        await preferences.remove('remembered_work_email');
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _message = _authErrorMessage(error);
        _isError = true;
      });
    } on PlatformException catch (error) {
      setState(() {
        _message = 'No se pudo guardar la preferencia local: ${error.message}';
        _isError = true;
      });
    } on MissingPluginException {
      setState(() {
        _message =
            'Un servicio requerido no está disponible en esta plataforma.';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openPasswordRecovery() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PasswordRecoveryPage(
          firebaseConfigured: widget.firebaseConfigured,
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  String _authErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'El correo no tiene un formato válido.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'El correo o la contraseña no son correctos.',
      'user-disabled' =>
        'Esta cuenta está desactivada. Contacta al Administrador.',
      'too-many-requests' =>
        'Hubo demasiados intentos. Espera un momento e inténtalo otra vez.',
      'network-request-failed' =>
        'No hay conexión con Firebase. Revisa tu conexión a internet.',
      'operation-not-allowed' =>
        'Firebase Authentication aún no tiene habilitado correo y contraseña.',
      _ => 'No se pudo iniciar sesión (${error.code}). Inténtalo otra vez.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    final wide = width >= 1000;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F4),
      body: SafeArea(
        child: Column(
          children: [
            AuthPageHeader(compact: compact),
            FirebaseSetupBanner(configured: widget.firebaseConfigured),
            Expanded(
              child: ColoredBox(
                color: Color(0xFFF2F6F4),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 16 : 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 1120 : 560),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: SizedBox(
                                    height: 520,
                                    child: _WelcomePanel(),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(child: _loginCard(context)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _CompactWelcomePanel(),
                                const SizedBox(height: 16),
                                _loginCard(context),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDCE7E1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 400 ? 20 : 28,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepLabel('ACCESO SEGURO'),
              const SizedBox(height: 14),
              const Text(
                'Iniciar sesión',
                style: TextStyle(
                  color: Color(0xFF17362D),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Ingresa con la cuenta de trabajo asignada por el Administrador.',
                style: TextStyle(color: Color(0xFF61756C)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Correo de trabajo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  hintText: 'nombre@empresa.pe',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Ingresa tu correo.';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Ingresa un correo válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 17),
              const Text(
                'Contraseña',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  hintText: 'Ingresa tu contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _showPassword
                        ? 'Ocultar contraseña'
                        : 'Mostrar contraseña',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Ingresa tu contraseña.'
                    : null,
              ),
              const SizedBox(height: 10),
              if (MediaQuery.sizeOf(context).width < 600)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Recordar correo en este equipo',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _rememberEmail,
                      onChanged: (value) =>
                          setState(() => _rememberEmail = value ?? false),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _openPasswordRecovery,
                      child: const Text('Olvidé mi contraseña'),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Recordar correo en este equipo',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: _rememberEmail,
                        onChanged: (value) =>
                            setState(() => _rememberEmail = value ?? false),
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _openPasswordRecovery,
                      child: const Text('Olvidé mi contraseña'),
                    ),
                  ],
                ),
              if (_message != null) ...[
                const SizedBox(height: 10),
                _FeedbackBanner(message: _message!, isError: _isError),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _signIn,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_isLoading ? 'Conectando…' : 'Ingresar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF07835F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'El acceso es exclusivo para cuentas creadas por la empresa. No hay registro público ni selección de roles.',
                style: TextStyle(
                  color: Color(0xFF71847B),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4ED),
        border: Border.all(color: const Color(0xFFDCE7E1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepLabel('IMPORTACIONES CHATO · CHINCHA'),
          Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF7D24F),
              borderRadius: BorderRadius.all(Radius.circular(17)),
            ),
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(
                Icons.inventory_2_rounded,
                size: 34,
                color: Color(0xFF062F26),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Todo tu negocio,\nen orden.',
            style: TextStyle(
              color: Color(0xFF17362D),
              fontSize: 32,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Inventario, compras y ventas. Información segura y sincronizada para el equipo.',
            style: TextStyle(color: Color(0xFF61756C), height: 1.5),
          ),
          Spacer(),
          Text(
            'SISTEMA DE CONTROL COMERCIAL · 2026',
            style: TextStyle(color: Color(0xFF07835F), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CompactWelcomePanel extends StatelessWidget {
  const _CompactWelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE7E1)),
      ),
      child: const Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF7D24F),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.inventory_2_rounded,
                color: Color(0xFF062F26),
                size: 24,
              ),
            ),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu negocio, en orden.',
                  style: TextStyle(
                    color: Color(0xFF17362D),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Inventario, compras y ventas en un solo lugar.',
                  style: TextStyle(color: Color(0xFF61756C), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF07835F),
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFDEDEE) : const Color(0xFFE5F4ED),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? const Color(0xFFAE4545) : const Color(0xFF28644F),
          fontSize: 13,
        ),
      ),
    );
  }
}
