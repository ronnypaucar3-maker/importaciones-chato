import 'package:flutter/material.dart';

const _profileGreen = Color(0xFF07835F);
const _profileInk = Color(0xFF17362D);
const _profileMuted = Color(0xFF61756C);

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    required this.displayName,
    required this.email,
    required this.role,
    required this.lastSignIn,
    required this.onSignOut,
    super.key,
  });

  final String displayName;
  final String email;
  final String role;
  final DateTime? lastSignIn;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final permissions = _permissionsFor(role);
    final initials = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CUENTA · ${role.toUpperCase()}',
          style: const TextStyle(
            color: _profileGreen,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Mi perfil',
          style: TextStyle(
            color: _profileInk,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tu identidad y alcance de acceso.',
          style: TextStyle(color: _profileMuted),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFFE5F4ED),
                      child: Text(
                        initials.isEmpty ? '?' : initials,
                        style: const TextStyle(
                          color: _profileGreen,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: _profileInk,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F4ED),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              child: Text(
                                role,
                                style: const TextStyle(
                                  color: _profileGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 25),
                _ProfileInfoRow(
                  icon: Icons.mail_outline,
                  title: 'Correo de trabajo',
                  detail: email.isEmpty ? 'Correo no disponible' : email,
                ),
                const Divider(height: 1, indent: 44),
                const _ProfileInfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Sede asignada',
                  detail: 'Chincha · Sede principal',
                ),
                const Divider(height: 1, indent: 44),
                _ProfileInfoRow(
                  icon: Icons.access_time,
                  title: 'Último acceso',
                  detail: lastSignIn == null
                      ? 'Aún no hay un registro disponible'
                      : _formatDateTime(lastSignIn!.toLocal()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis permisos',
                  style: TextStyle(
                    color: _profileInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (var index = 0; index < permissions.length; index++) ...[
                  if (index > 0) const Divider(height: 1, indent: 44),
                  _PermissionTile(permission: permissions[index]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showGuide(context),
          icon: const Icon(Icons.help_outline),
          label: const Text('Ayuda y guía de recorridos'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _profileGreen,
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFFDCE7E1)),
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _profileGreen,
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFFDCE7E1)),
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _showGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayuda para tu perfil'),
        content: Text(
          '${_guideFor(role)}\n\n'
          'Tu acceso depende del rol asignado a tu cuenta. Para solicitar '
          'cambios, comunícate con Administración. Nunca compartas tu '
          'contraseña ni códigos de acceso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F0),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: _profileGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _profileInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(color: _profileMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Permission {
  const _Permission(this.icon, this.title, this.detail);

  final IconData icon;
  final String title;
  final String detail;
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({required this.permission});

  final _Permission permission;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 34,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5F0),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(permission.icon, size: 18, color: _profileGreen),
      ),
      title: Text(
        permission.title,
        style: const TextStyle(
          color: _profileInk,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        permission.detail,
        style: const TextStyle(color: _profileMuted, fontSize: 11),
      ),
    );
  }
}

List<_Permission> _permissionsFor(String role) {
  return switch (role) {
    'Administrador' => const [
      _Permission(
        Icons.dashboard_outlined,
        'Control de la operación',
        'Gestiona productos, existencias, compras, ventas y reportes.',
      ),
      _Permission(
        Icons.manage_accounts_outlined,
        'Usuarios y permisos',
        'Crea y activa cuentas operativas de Caja y Pasillo.',
      ),
      _Permission(
        Icons.history,
        'Actividad de la sede',
        'Consulta movimientos e historial de operaciones.',
      ),
    ],
    'Gerente' => const [
      _Permission(
        Icons.dashboard_outlined,
        'Supervisión de operaciones',
        'Gestiona productos, inventario, compras, ventas y reportes.',
      ),
      _Permission(
        Icons.inventory_2_outlined,
        'Control de existencias',
        'Administra el catálogo y los movimientos de inventario.',
      ),
      _Permission(
        Icons.history,
        'Actividad de la sede',
        'Consulta el historial y los indicadores de operación.',
      ),
    ],
    'Caja' => const [
      _Permission(
        Icons.point_of_sale_outlined,
        'Caja y ventas',
        'Registra ventas y administra tu turno.',
      ),
      _Permission(
        Icons.inventory_2_outlined,
        'Consulta de productos',
        'Consulta precios y existencias; no edita el catálogo ni ve costos.',
      ),
      _Permission(
        Icons.history,
        'Mi historial',
        'Consulta tus ventas registradas.',
      ),
    ],
    'Pasillo' => const [
      _Permission(
        Icons.inventory_2_outlined,
        'Control de existencias',
        'Registra entradas, salidas y ajustes de inventario.',
      ),
      _Permission(
        Icons.search,
        'Consulta operativa',
        'Consulta productos y movimientos de inventario.',
      ),
      _Permission(
        Icons.history,
        'Mi historial',
        'Consulta tus movimientos registrados.',
      ),
    ],
    _ => const [
      _Permission(
        Icons.info_outline,
        'Acceso limitado',
        'Comunícate con Administración para revisar tu rol.',
      ),
    ],
  };
}

String _guideFor(String role) {
  return switch (role) {
    'Administrador' =>
      'Desde el menú puedes gestionar el catálogo, las operaciones y las '
          'cuentas de Caja y Pasillo.',
    'Gerente' =>
      'Desde el menú puedes supervisar productos, existencias, compras, '
          'ventas, reportes e historial.',
    'Caja' =>
      'Usa Inicio para revisar tu turno, Ventas para registrar operaciones '
          'y Productos para consultar precios y existencias.',
    'Pasillo' =>
      'Usa Existencias para registrar movimientos de inventario y Productos '
          'para consultar el catálogo.',
    _ => 'Comunícate con Administración para recibir orientación sobre tu rol.',
  };
}

String _formatDateTime(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} · '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
