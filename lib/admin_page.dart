import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const _forest = Color(0xFF07382D);
const _green = Color(0xFF07835F);
const _operationalRoles = ['Caja', 'Pasillo'];

enum _AdminSection { overview, users }

class AdminPage extends StatefulWidget {
  const AdminPage({
    required this.user,
    required this.displayName,
    required this.onSignOut,
    required this.unreadCountStream,
    required this.onOpenNotifications,
    this.openUsersInitially = false,
    this.onOpenHome,
    this.onOpenProducts,
    this.onOpenMore,
    super.key,
  });

  final User user;
  final String displayName;
  final Future<void> Function() onSignOut;
  final Stream<int> unreadCountStream;
  final VoidCallback onOpenNotifications;
  final bool openUsersInitially;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenMore;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late _AdminSection _section;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _auditStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _todayAuditStream;

  @override
  void initState() {
    super.initState();
    _section = widget.openUsersInitially
        ? _AdminSection.users
        : _AdminSection.overview;
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final auditLogs = FirebaseFirestore.instance.collection('auditLogs');
    _auditStream = auditLogs
        .orderBy('occurredAt', descending: true)
        .limit(10)
        .snapshots();
    _todayAuditStream = auditLogs
        .where(
          'occurredAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .snapshots();
  }

  Future<void> _signOut() => widget.onSignOut();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final compact = constraints.maxWidth < 600;
        final body = _section == _AdminSection.overview
            ? _AdminOverview(
                usersStream: _usersStream,
                auditStream: _auditStream,
                todayAuditStream: _todayAuditStream,
                displayName: widget.displayName,
                onOpenUsers: () => _select(_AdminSection.users),
              )
            : _AdminUsersPage(user: widget.user, usersStream: _usersStream);

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            automaticallyImplyLeading: !compact,
            leading: wide || compact
                ? null
                : Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Abrir menú',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                  ),
            title: _Brand(compact: compact),
            actions: [
              StreamBuilder<int>(
                stream: widget.unreadCountStream,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return IconButton(
                    tooltip: 'Notificaciones',
                    onPressed: widget.onOpenNotifications,
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text(count > 99 ? '99+' : '$count'),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFFF7CB4A),
                      ),
                    ),
                  );
                },
              ),
              if (!compact) ...[
                const Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: Color(0xFF9ADBC7),
                ),
                const SizedBox(width: 4),
                const Text('Chincha, Perú', style: TextStyle(fontSize: 12)),
              ],
            ],
          ),
          drawer: wide
              ? null
              : _AdminDrawer(
                  selected: _section,
                  onSelected: _select,
                  displayName: widget.displayName,
                  onSignOut: _signOut,
                ),
          body: Row(
            children: [
              if (wide)
                _AdminSideNav(
                  selected: _section,
                  onSelected: _select,
                  displayName: widget.displayName,
                  onSignOut: _signOut,
                ),
              Expanded(
                child: Column(
                  children: [
                    const _ConnectedNotice(),
                    if (!wide && !compact)
                      _AdminTabs(selected: _section, onSelected: _select),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(compact ? 16 : 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: body,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: compact
              ? NavigationBar(
                  selectedIndex: _section == _AdminSection.overview ? 0 : 2,
                  onDestinationSelected: _selectMobileDestination,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: 'Inicio',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Productos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: 'Usuarios',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu),
                      selectedIcon: Icon(Icons.menu_open),
                      label: 'Más',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  void _select(_AdminSection section) {
    setState(() => _section = section);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  void _selectMobileDestination(int index) {
    switch (index) {
      case 0:
        _leaveFor(widget.onOpenHome, _AdminSection.overview);
        break;
      case 1:
        _leaveFor(widget.onOpenProducts, _AdminSection.overview);
        break;
      case 2:
        _select(_AdminSection.users);
        break;
      case 3:
        if (widget.onOpenMore != null) {
          _leaveFor(widget.onOpenMore, _AdminSection.overview);
        } else {
          _scaffoldKey.currentState?.openDrawer();
        }
        break;
    }
  }

  void _leaveFor(VoidCallback? callback, _AdminSection fallback) {
    if (callback == null) {
      _select(fallback);
      return;
    }
    Navigator.of(context).pop();
    callback();
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({
    required this.usersStream,
    required this.auditStream,
    required this.todayAuditStream,
    required this.displayName,
    required this.onOpenUsers,
    super.key,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> usersStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> auditStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> todayAuditStream;
  final String displayName;
  final VoidCallback onOpenUsers;

  @override
  Widget build(BuildContext context) {
    return _AdminOverview(
      usersStream: usersStream,
      auditStream: auditStream,
      todayAuditStream: todayAuditStream,
      displayName: displayName,
      onOpenUsers: onOpenUsers,
    );
  }
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({
    required this.usersStream,
    required this.auditStream,
    required this.todayAuditStream,
    required this.displayName,
    required this.onOpenUsers,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> usersStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> auditStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> todayAuditStream;
  final String displayName;
  final VoidCallback onOpenUsers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_forest, Color(0xFF0D5A45)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A07382D),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF145545),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Color(0xFFF7CB4A),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'PANEL DE ADMINISTRACIÓN',
                      style: TextStyle(
                        color: Color(0xFFD0E4DC),
                        letterSpacing: 1,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _adminDate(DateTime.now()),
                    style: const TextStyle(
                      color: Color(0xFFD0E4DC),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              const Text(
                'Todo bajo control',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: const TextStyle(
                  color: Color(0xFFE5F4ED),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Usuarios, permisos y actividad de tu sede.',
                style: TextStyle(
                  color: Color(0xFFB8D3C9),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: usersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StreamError(
                message: 'No se pudieron cargar las cuentas: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) return const _LoadingCard();

            final users = snapshot.data!.docs;
            final activeCount = users
                .where((doc) => doc.data()['active'] == true)
                .length;

            final sortedUsers =
                users.where((doc) => doc.data()['active'] == true).toList()
                  ..sort(
                    (a, b) => (a.data()['displayName'] as String? ?? '')
                        .compareTo(b.data()['displayName'] as String? ?? ''),
                  );
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Usuarios activos',
                        value: '$activeCount',
                        detail: '${users.length - activeCount} inactivos',
                        icon: Icons.people_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: todayAuditStream,
                        builder: (context, auditSnapshot) {
                          if (auditSnapshot.hasError) {
                            return _MetricError(
                              label: 'Eventos de hoy',
                              error: auditSnapshot.error!,
                            );
                          }
                          return _MetricCard(
                            label: 'Eventos de hoy',
                            value: auditSnapshot.hasData
                                ? '${auditSnapshot.data!.docs.length}'
                                : '…',
                            detail: 'Accesos y cambios registrados',
                            icon: Icons.history,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Equipo de la sede',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5F4ED),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: _green,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$activeCount activos',
                                    style: const TextStyle(
                                      color: Color(0xFF28644F),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (sortedUsers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Aún no hay perfiles registrados en Firestore.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF71847B)),
                            ),
                          )
                        else
                          ...sortedUsers
                              .take(3)
                              .map((user) => _AccountTile(data: user.data())),
                        if (sortedUsers.length > 3) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Mostrando 3 de $activeCount usuarios activos',
                            style: const TextStyle(
                              color: Color(0xFF71847B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: onOpenUsers,
                          icon: const Icon(Icons.manage_accounts_outlined),
                          label: const Text('Administrar usuarios'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const _RolePermissionsCard(),
        const SizedBox(height: 16),
        _AuditList(stream: auditStream, usersStream: usersStream),
        const SizedBox(height: 12),
        const _AdminLimitsNotice(),
      ],
    );
  }
}

class _AdminUsersPage extends StatefulWidget {
  const _AdminUsersPage({required this.user, required this.usersStream});

  final User user;
  final Stream<QuerySnapshot<Map<String, dynamic>>> usersStream;

  @override
  State<_AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<_AdminUsersPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isWorking = false;
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createAccount(_NewAccount account) async {
    setState(() {
      _isWorking = true;
      _feedback = null;
    });

    FirebaseApp? secondaryApp;
    User? createdUser;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'account-${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: account.email,
        password: account.password,
      );
      createdUser = credential.user;
      if (createdUser == null) {
        throw StateError('Firebase no devolvió la cuenta recién creada.');
      }

      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(createdUser.uid);
      final auditRef = firestore.collection('auditLogs').doc();
      final batch = firestore.batch();
      batch.set(userRef, {
        'displayName': account.name,
        'email': account.email,
        'role': account.role,
        'active': true,
        'createdBy': widget.user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(auditRef, {
        'actorUid': widget.user.uid,
        'actorEmail': widget.user.email,
        'action': 'user_created',
        'targetUid': createdUser.uid,
        'targetRole': account.role,
        'occurredAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _feedback = 'Cuenta creada para ${account.name}.';
        _feedbackIsError = false;
      });
    } on FirebaseException catch (error) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } on FirebaseException catch (rollbackError) {
          throw StateError(
            'No se guardó el perfil (${error.code}) y tampoco se pudo retirar la cuenta incompleta (${rollbackError.code}).',
          );
        }
      }
      if (mounted) {
        setState(() {
          _feedback = _firebaseErrorMessage(error);
          _feedbackIsError = true;
        });
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _feedback = error.message;
          _feedbackIsError = true;
        });
      }
    } finally {
      if (secondaryApp != null) await secondaryApp.delete();
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _setAccountActive({
    required String uid,
    required Map<String, dynamic> profile,
    required bool active,
  }) async {
    if (!_operationalRoles.contains(profile['role'])) {
      setState(() {
        _feedback = 'Este perfil no puede desactivar cuentas de Gerencia o Administración.';
        _feedbackIsError = true;
      });
      return;
    }

    setState(() {
      _isWorking = true;
      _feedback = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.update(firestore.collection('users').doc(uid), {
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(firestore.collection('auditLogs').doc(), {
        'actorUid': widget.user.uid,
        'actorEmail': widget.user.email,
        'action': active ? 'user_activated' : 'user_deactivated',
        'targetUid': uid,
        'targetRole': profile['role'],
        'occurredAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (mounted) {
        setState(() {
          _feedback = active ? 'Cuenta activada.' : 'Cuenta desactivada.';
          _feedbackIsError = false;
        });
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _feedback = _firebaseErrorMessage(error);
          _feedbackIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => 'Firebase rechazó la operación. Verifica las reglas y los permisos del perfil.',
      'email-already-in-use' => 'Ese correo ya tiene una cuenta.',
      'invalid-email' => 'El correo ingresado no es válido.',
      'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
      'network-request-failed' =>
        'No hay conexión con Firebase. Revisa internet e inténtalo otra vez.',
      _ => 'No se completó la operación (${error.code}).',
    };
  }

  Future<void> _showCreateAccountDialog() async {
    final account = await showDialog<_NewAccount>(
      context: context,
      builder: (context) => const _CreateAccountDialog(),
    );
    if (account != null && mounted) await _createAccount(account);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeading(
          eyebrow: 'ADMINISTRACIÓN / CONTROL DE ACCESO',
          title: 'Usuarios y permisos',
          subtitle: 'Administra cuentas operativas de la sede principal.',
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    const Text(
                      'Equipo de la sede',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isWorking ? null : _showCreateAccountDialog,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Crear cuenta operativa'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Puedes crear cuentas de Caja y Pasillo. Los roles Gerente y Administrador no se asignan desde este perfil.',
                  style: TextStyle(color: Color(0xFF61756C), fontSize: 13),
                ),
                if (_feedback != null) ...[
                  const SizedBox(height: 12),
                  _FeedbackBanner(
                    message: _feedback!,
                    isError: _feedbackIsError,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nombre, correo o rol',
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.usersStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _StreamError(
                        message:
                            'No se pudieron consultar las cuentas: ${snapshot.error}',
                      );
                    }
                    if (!snapshot.hasData) return const _LoadingCard();

                    final users =
                        snapshot.data!.docs.where((doc) {
                          final data = doc.data();
                          final searchable = [
                            data['displayName'],
                            data['email'],
                            data['role'],
                          ].whereType<String>().join(' ').toLowerCase();
                          return searchable.contains(_query.toLowerCase());
                        }).toList()..sort(
                          (a, b) => (a.data()['displayName'] as String? ?? '')
                              .compareTo(
                                b.data()['displayName'] as String? ?? '',
                              ),
                        );

                    if (users.isEmpty) {
                      return const _EmptyCard(
                        message:
                            'No hay cuentas que coincidan con la búsqueda.',
                      );
                    }

                    return Column(
                      children: users
                          .map(
                            (doc) => _ManagedAccountTile(
                              data: doc.data(),
                              canManage: _operationalRoles.contains(
                                doc.data()['role'],
                              ),
                              onActiveChanged: (active) => _setAccountActive(
                                uid: doc.id,
                                profile: doc.data(),
                                active: active,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                if (_isWorking) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog();

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = _operationalRoles.first;
  bool _showPassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _NewAccount(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear cuenta operativa'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Ingresa el nombre.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo de trabajo',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                        ? null
                        : 'Ingresa un correo válido.';
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: _operationalRoles
                      .map(
                        (role) =>
                            DropdownMenuItem(value: role, child: Text(role)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña temporal',
                    helperText:
                        'Mínimo 6 caracteres; el usuario puede cambiarla.',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      (value?.length ?? 0) < 6 ? 'Mínimo 6 caracteres.' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Crear cuenta')),
      ],
    );
  }
}

class _NewAccount {
  const _NewAccount({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  final String name;
  final String email;
  final String password;
  final String role;
}

class _ManagedAccountTile extends StatelessWidget {
  const _ManagedAccountTile({
    required this.data,
    required this.canManage,
    required this.onActiveChanged,
  });

  final Map<String, dynamic> data;
  final bool canManage;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final active = data['active'] == true;
    final compact = MediaQuery.sizeOf(context).width < 620;
    final title = data['displayName'] as String? ?? 'Cuenta sin nombre';
    final email = data['email'] as String? ?? 'Sin correo';
    final role = data['role'] as String? ?? 'Sin rol';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5ECE8))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE5F4ED),
            child: Text(
              title.split(' ').map((part) => part[0]).take(2).join(),
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  compact ? '$role · $email' : email,
                  style: const TextStyle(
                    color: Color(0xFF71847B),
                    fontSize: 12,
                  ),
                ),
                if (!compact)
                  Text(role, style: const TextStyle(color: Color(0xFF61756C))),
              ],
            ),
          ),
          _StatusBadge(active: active),
          if (canManage) Switch(value: active, onChanged: onActiveChanged),
        ],
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({required this.stream, required this.usersStream});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> usersStream;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F4ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history, color: _green, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auditoría reciente',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Cambios de cuentas registrados',
                        style: TextStyle(
                          color: Color(0xFF71847B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: usersStream,
              builder: (context, snapshot) {
                final userEmails = <String, String>{
                  if (snapshot.hasData)
                    for (final user in snapshot.data!.docs)
                      if (user.data()['email'] case final String email)
                        user.id: email,
                };
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, auditSnapshot) {
                    if (auditSnapshot.hasError) {
                      return _StreamError(
                        message:
                            'No se pudo consultar la auditoría: ${auditSnapshot.error}',
                      );
                    }
                    if (!auditSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (auditSnapshot.data!.docs.isEmpty) {
                      return const _EmptyCard(
                        message: 'Aún no hay eventos de auditoría.',
                      );
                    }
                    return Column(
                      children: auditSnapshot.data!.docs.map((doc) {
                        final data = doc.data();
                        final targetUid = data['targetUid'] as String?;
                        return _AuditTile(
                          data: data,
                          targetEmail:
                              data['targetEmail'] as String? ??
                              (targetUid == null
                                  ? null
                                  : userEmails[targetUid]),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.data, required this.targetEmail});

  final Map<String, dynamic> data;
  final String? targetEmail;

  @override
  Widget build(BuildContext context) {
    final timestamp = data['occurredAt'];
    final date = timestamp is Timestamp ? timestamp.toDate() : null;
    final action = switch (data['action']) {
      'user_created' => 'Cuenta creada',
      'user_activated' => 'Cuenta activada',
      'user_deactivated' => 'Cuenta desactivada',
      _ => 'Operación registrada',
    };
    final icon = switch (data['action']) {
      'user_created' => Icons.person_add_alt_1,
      'user_activated' => Icons.check_circle_outline,
      'user_deactivated' => Icons.person_off_outlined,
      _ => Icons.history,
    };
    final iconColor = data['action'] == 'user_deactivated'
        ? const Color(0xFFAE4545)
        : _green;
    final when = date == null
        ? 'Guardando fecha…'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: iconColor == _green
            ? const Color(0xFFE5F4ED)
            : const Color(0xFFFDEDEE),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        action,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      isThreeLine: true,
      subtitle: Text(
        '${targetEmail ?? 'Correo de la cuenta afectada no disponible'}'
        ' · ${data['targetRole'] ?? ''} · $when\n'
        'Realizado por: ${data['actorEmail'] ?? 'Administrador'}',
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F4ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: _green),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF61756C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF17362D),
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF71847B), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricError extends StatelessWidget {
  const _MetricError({required this.label, required this.error});

  final String label;
  final Object error;

  @override
  Widget build(BuildContext context) =>
      _StreamError(message: 'No se pudieron cargar "$label": $error');
}

class _RolePermissionsCard extends StatelessWidget {
  const _RolePermissionsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F4ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: _green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permisos por perfil',
                        style: TextStyle(
                          color: Color(0xFF17362D),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Accesos definidos para cada función.',
                        style: TextStyle(
                          color: Color(0xFF71847B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _RolePermissionTile(
              icon: Icons.lock_outline,
              title: 'Gerencia y administración',
              detail: 'Acceso a los módulos de operación y gestión.',
            ),
            const Divider(height: 1, indent: 42),
            const _RolePermissionTile(
              icon: Icons.point_of_sale_outlined,
              title: 'Caja',
              detail: 'Ventas, productos e historial propio.',
            ),
            const Divider(height: 1, indent: 42),
            const _RolePermissionTile(
              icon: Icons.inventory_2_outlined,
              title: 'Pasillo',
              detail: 'Existencias, productos e historial propio.',
            ),
            const SizedBox(height: 8),
            Text(
              'Los accesos dependen del rol asignado a cada cuenta.',
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePermissionTile extends StatelessWidget {
  const _RolePermissionTile({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFFE5F4ED),
        child: Icon(icon, size: 17, color: _green),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        detail,
        style: const TextStyle(fontSize: 10, color: Color(0xFF71847B)),
      ),
    );
  }
}

String _adminDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
}

class _AdminLimitsNotice extends StatelessWidget {
  const _AdminLimitsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE7E1)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: _green, size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alcance de administración',
                  style: TextStyle(
                    color: Color(0xFF17362D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Puedes crear y activar cuentas de Caja y Pasillo. Los roles Gerente y Administrador no se asignan desde aquí.',
                  style: TextStyle(
                    color: Color(0xFF61756C),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: _green,
            letterSpacing: 1.1,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF17362D),
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF61756C), fontSize: 14),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['displayName'] as String? ?? 'Cuenta';
    final role = data['role'] as String? ?? 'Sin rol';
    final compact = MediaQuery.sizeOf(context).width < 620;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE5F4ED),
        child: Text(
          name.split(' ').map((part) => part[0]).take(2).join(),
          style: const TextStyle(
            color: _green,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(name),
      subtitle: Text(compact ? '$role · ${data['email'] ?? ''}' : role),
      trailing: _StatusBadge(active: data['active'] == true),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE5F4ED) : const Color(0xFFFDEDEE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          active ? 'Activo' : 'Inactivo',
          style: TextStyle(
            color: active ? const Color(0xFF28644F) : const Color(0xFFAE4545),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    ),
  );
}

class _StreamError extends StatelessWidget {
  const _StreamError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: const TextStyle(color: Color(0xFFAE4545))),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF7CB4A),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            'CH',
            style: TextStyle(
              color: _forest,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          compact ? 'CHATO' : 'IMPORTACIONES CHATO',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
      ],
    );
  }
}

class _ConnectedNotice extends StatelessWidget {
  const _ConnectedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE5F4ED),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_outlined, size: 16, color: _green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sesión autenticada · Información sincronizada con Firebase',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFF28644F), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSideNav extends StatelessWidget {
  const _AdminSideNav({
    required this.selected,
    required this.onSelected,
    required this.displayName,
    required this.onSignOut,
  });

  final _AdminSection selected;
  final ValueChanged<_AdminSection> onSelected;
  final String displayName;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _forest,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: Text(
              'ADMINISTRACIÓN\nSede principal',
              style: TextStyle(
                color: Color(0xFFB8D3C9),
                height: 1.6,
                fontSize: 12,
              ),
            ),
          ),
          _NavButton(
            icon: Icons.dashboard_outlined,
            label: 'Resumen',
            selected: selected == _AdminSection.overview,
            onTap: () => onSelected(_AdminSection.overview),
          ),
          _NavButton(
            icon: Icons.people_outline,
            label: 'Usuarios y permisos',
            selected: selected == _AdminSection.users,
            onTap: () => onSelected(_AdminSection.users),
          ),
          const Spacer(),
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF145545),
              child: Text(
                displayName.split(' ').map((part) => part[0]).take(2).join(),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            title: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            subtitle: const Text(
              'Administrador',
              style: TextStyle(color: Color(0xFFB8D3C9), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? _green : _forest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        child: ListTile(
          selected: selected,
          leading: Icon(icon, size: 20, color: const Color(0xFFD0E4DC)),
          title: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.selected,
    required this.onSelected,
    required this.displayName,
    required this.onSignOut,
  });

  final _AdminSection selected;
  final ValueChanged<_AdminSection> onSelected;
  final String displayName;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selected.index,
      onDestinationSelected: (index) => onSelected(_AdminSection.values[index]),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          child: _Brand(compact: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 16, 8),
          child: Text('ADMINISTRACIÓN · $displayName'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Resumen'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Usuarios y permisos'),
        ),
      ],
    );
  }
}

class _AdminTabs extends StatelessWidget {
  const _AdminTabs({required this.selected, required this.onSelected});

  final _AdminSection selected;
  final ValueChanged<_AdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Row(
        children: [
          _AdminTab(
            label: 'Resumen',
            selected: selected == _AdminSection.overview,
            onTap: () => onSelected(_AdminSection.overview),
          ),
          _AdminTab(
            label: 'Usuarios y permisos',
            selected: selected == _AdminSection.users,
            onTap: () => onSelected(_AdminSection.users),
          ),
        ],
      ),
    );
  }
}

class _AdminTab extends StatelessWidget {
  const _AdminTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: selected ? _green : const Color(0xFF61756C),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    child: Text(label),
  );
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
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
