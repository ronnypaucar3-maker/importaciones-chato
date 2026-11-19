import 'package:flutter/material.dart';

class AuthPageHeader extends StatelessWidget {
  const AuthPageHeader({
    required this.compact,
    this.showSecurityIcon = false,
    super.key,
  });

  final bool compact;
  final bool showSecurityIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF07382D),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 32,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF7CB4A),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              'CH',
              style: TextStyle(
                color: Color(0xFF07382D),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'IMPORTACIONES CHATO',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: .6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (showSecurityIcon) const SizedBox(width: 8),
          if (showSecurityIcon)
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF104638),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Color(0xFFF7CB4A),
                size: 20,
              ),
            )
          else if (!compact)
            const SizedBox(width: 12),
          if (!showSecurityIcon && !compact)
            const Text(
              'Chincha, Perú',
              style: TextStyle(color: Color(0xFFB8D3C9), fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class FirebaseSetupBanner extends StatelessWidget {
  const FirebaseSetupBanner({required this.configured, super.key});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: configured ? const Color(0xFFE5F4ED) : const Color(0xFFFFF5D6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        children: [
          Icon(
            configured ? Icons.verified_outlined : Icons.info_outline,
            size: 17,
            color: configured
                ? const Color(0xFF07835F)
                : const Color(0xFF88620B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              configured ? 'Conectado a Firebase · acceso protegido' : 'Configuración pendiente · falta registrar y configurar las apps de Firebase',
              style: TextStyle(
                color: configured
                    ? const Color(0xFF28644F)
                    : const Color(0xFF765711),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
