import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_widgets.dart';
import 'firebase_config.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    required this.firebaseConfigured,
    this.initialEmail = '',
    this.onSendPasswordReset,
    super.key,
  });

  final bool firebaseConfigured;
  final String initialEmail;
  final Future<void> Function(String email)? onSendPasswordReset;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  bool _isSending = false;
  bool _sent = false;
  String? _feedback;
  bool _isError = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInstructions() async {
    if (!_sent && _formKey.currentState?.validate() != true) return;

    final request = widget.onSendPasswordReset;
    if (!widget.firebaseConfigured ||
        (request == null && !FirebaseConfig.isConfigured)) {
      setState(() {
        _feedback = 'La recuperación requiere que Firebase Authentication esté configurado.';
        _isError = true;
      });
      return;
    }

    final email = _emailController.text.trim();
    setState(() {
      _isSending = true;
      _feedback = null;
      _isError = false;
    });

    try {
      if (request == null) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      } else {
        await request(email);
      }
      if (!mounted) return;
      _showSentConfirmation();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'user-not-found' || error.code == 'user-disabled') {
        _showSentConfirmation();
      } else {
        setState(() {
          _feedback = _resetErrorMessage(error);
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSentConfirmation() {
    setState(() {
      _sent = true;
      _feedback = null;
      _isError = false;
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _resetErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'El correo no tiene un formato válido.',
      'too-many-requests' =>
        'Hubo varios intentos. Espera un momento antes de volver a intentarlo.',
      'network-request-failed' =>
        'No hay conexión con Firebase. Revisa internet e inténtalo otra vez.',
      'operation-not-allowed' => 'La recuperación por correo no está habilitada en Firebase Authentication.',
      _ => 'No se pudo enviar el enlace. Inténtalo nuevamente.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F4),
      body: SafeArea(
        child: Column(
          children: [
            AuthPageHeader(compact: compact, showSecurityIcon: true),
            FirebaseSetupBanner(configured: widget.firebaseConfigured),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.all(compact ? 18 : 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _sent
                        ? _confirmationContent(context)
                        : _requestContent(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _isSending ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Volver al inicio de sesión'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF07835F),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 22),
        _recoveryIcon(Icons.key_outlined),
        const SizedBox(height: 18),
        const Text(
          'ACCESO SEGURO',
          style: TextStyle(
            color: Color(0xFF07835F),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Recupera tu acceso',
          style: TextStyle(
            color: Color(0xFF17362D),
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Indica tu correo de trabajo y te enviaremos un enlace para restablecer tu contraseña.',
          style: TextStyle(color: Color(0xFF61756C), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 22),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Correo de trabajo *',
                style: TextStyle(
                  color: Color(0xFF17362D),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                enabled: !_isSending,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _sendInstructions(),
                onChanged: (_) {
                  if (_feedback != null) {
                    setState(() {
                      _feedback = null;
                      _isError = false;
                    });
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'nombre@empresa.pe',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Ingresa tu correo de trabajo.';
                  }
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Ingresa un correo válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Usa el correo asignado por tu empresa.',
                style: TextStyle(color: Color(0xFF71847B), fontSize: 12),
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 16),
                _RecoveryFeedback(message: _feedback!, isError: _isError),
              ],
              const SizedBox(height: 20),
              _sendButton('Enviar instrucciones'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDCE7E1)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿No recuerdas tu correo?',
                style: TextStyle(
                  color: Color(0xFF17362D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Comunícate con el Administrador de tu sede. Nunca compartas tu contraseña ni códigos de acceso.',
                style: TextStyle(
                  color: Color(0xFF61756C),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _confirmationContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _recoveryIcon(Icons.mark_email_read_outlined),
        const SizedBox(height: 22),
        const Text(
          'ESTADO DE SOLICITUD',
          style: TextStyle(
            color: Color(0xFF07835F),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Revisa tu correo',
          style: TextStyle(
            color: Color(0xFF17362D),
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña.',
          style: TextStyle(color: Color(0xFF61756C), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDCE7E1)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CORREO INDICADO',
                style: TextStyle(
                  color: Color(0xFF61756C),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _emailController.text.trim(),
                style: const TextStyle(
                  color: Color(0xFF17362D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'El enlace tiene una vigencia limitada. Revisa también tu bandeja de spam.',
                style: TextStyle(
                  color: Color(0xFF61756C),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE5F4ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Color(0xFF07835F),
                size: 19,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Solicitud procesada. Por seguridad, no confirmamos si la dirección está asociada a una cuenta.',
                  style: TextStyle(
                    color: Color(0xFF28644F),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 14),
          _RecoveryFeedback(message: _feedback!, isError: _isError),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isSending ? null : _sendInstructions,
          icon: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(_isSending ? 'Enviando…' : 'Reenviar instrucciones'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF07835F),
            side: const BorderSide(color: Color(0xFF07835F)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSending ? null : () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF07835F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Volver a iniciar sesión'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _isSending
                ? null
                : () {
                    setState(() {
                      _sent = false;
                      _feedback = null;
                      _isError = false;
                    });
                    _scrollToTop();
                  },
            child: const Text('¿El correo es incorrecto? Revisar dirección'),
          ),
        ),
      ],
    );
  }

  Widget _recoveryIcon(IconData icon) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE5F4ED),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: const Color(0xFF07835F), size: 31),
      ),
    );
  }

  Widget _sendButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSending ? null : _sendInstructions,
        icon: _isSending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.email_outlined),
        label: Text(_isSending ? 'Enviando…' : label),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF07835F),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _RecoveryFeedback extends StatelessWidget {
  const _RecoveryFeedback({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final foreground = isError
        ? const Color(0xFFAE4545)
        : const Color(0xFF28644F);
    final background = isError
        ? const Color(0xFFFDEDEE)
        : const Color(0xFFE5F4ED);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: foreground,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foreground, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
