import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;

import 'admin_page.dart';
import 'cashier_pages.dart';
import 'models/cash_payment.dart';
import 'models/cash_shift.dart';
import 'models/product.dart';
import 'notifications_page.dart';
import 'services/cash_shift_service.dart';
import 'services/inventory_service.dart';
import 'services/notification_service.dart';
import 'user_profile_page.dart';

const _forest = Color(0xFF07382D);
const _green = Color(0xFF07835F);
const _ink = Color(0xFF17362D);
const _muted = Color(0xFF61756C);
const _gold = Color(0xFFF7CB4A);

enum _Section {
  overview,
  products,
  inventory,
  purchases,
  sales,
  reports,
  history,
  profile,
}

class OperationsPage extends StatefulWidget {
  const OperationsPage({
    required this.user,
    required this.displayName,
    required this.role,
    super.key,
  });

  final User user;
  final String displayName;
  final String role;

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final NotificationService _notificationService = NotificationService(
    userId: widget.user.uid,
  );
  late final InventoryService _inventory = InventoryService(
    user: widget.user,
    displayName: widget.displayName,
  );
  late final CashShiftService _cashShifts = CashShiftService(
    user: widget.user,
    displayName: widget.displayName,
  );
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _adminUsersStream =
      FirebaseFirestore.instance.collection('users').snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _adminAuditStream =
      FirebaseFirestore.instance
          .collection('auditLogs')
          .orderBy('occurredAt', descending: true)
          .limit(10)
          .snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _todayAuditStream =
      FirebaseFirestore.instance
          .collection('auditLogs')
          .where(
            'occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              ),
            ),
          )
          .snapshots();
  late final List<_Section> _sections = _sectionsFor(widget.role);
  final List<_Section> _sectionHistory = [];
  late final StreamSubscription<void> _notificationOpenSubscription;
  late final StreamSubscription<String> _notificationErrorSubscription;
  _Section? _selected;
  String? _notificationSetupError;
  String? _notificationInfoMessage;

  bool get _isManager =>
      widget.role == 'Administrador' || widget.role == 'Gerente';

  static List<_Section> _sectionsFor(String role) {
    return switch (role) {
      'Administrador' || 'Gerente' => const [
        _Section.overview,
        _Section.products,
        _Section.inventory,
        _Section.purchases,
        _Section.sales,
        _Section.reports,
        _Section.history,
        _Section.profile,
      ],
      'Caja' => const [
        _Section.overview,
        _Section.products,
        _Section.sales,
        _Section.history,
        _Section.profile,
      ],
      'Pasillo' => const [
        _Section.inventory,
        _Section.products,
        _Section.history,
        _Section.profile,
      ],
      _ => const [],
    };
  }

  @override
  void initState() {
    super.initState();
    _notificationOpenSubscription = _notificationService.opened.listen((_) {
      if (mounted) _openNotifications();
    });
    _notificationErrorSubscription = _notificationService.errors.listen((
      message,
    ) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
    if (_isManager || widget.role == 'Caja') {
      unawaited(_initializeNotifications());
    }
  }

  @override
  void dispose() {
    unawaited(_notificationOpenSubscription.cancel());
    unawaited(_notificationErrorSubscription.cancel());
    unawaited(_notificationService.dispose());
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
      if (mounted) {
        setState(
          () =>
              _notificationInfoMessage = _notificationService.permissionMessage,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('No se pudieron configurar las notificaciones: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(
          () => _notificationSetupError =
              'No se pudieron configurar los avisos locales: $error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Importaciones Chato')),
        body: const Center(
          child: Text('Tu perfil no tiene un rol operativo asignado.'),
        ),
      );
    }
    final selected = _selected ?? _sections.first;
    return PopScope<Object?>(
      canPop: _sectionHistory.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
        } else {
          _goBackToPreviousSection();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final compact = constraints.maxWidth < 600;
          final gerenciaMobile = widget.role == 'Gerente' && compact;
          final adminMobile = widget.role == 'Administrador' && compact;
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              automaticallyImplyLeading: !(gerenciaMobile || adminMobile),
              leading: wide || gerenciaMobile || adminMobile
                  ? null
                  : IconButton(
                      tooltip: 'Abrir menú',
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
              title: _Brand(compact: compact),
              actions: [
                if (_isManager || widget.role == 'Caja')
                  StreamBuilder<int>(
                    stream: _notificationService.watchUnreadCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return IconButton(
                        tooltip: 'Notificaciones',
                        onPressed: _openNotifications,
                        icon: Badge(
                          isLabelVisible: count > 0,
                          label: Text(count > 99 ? '99+' : '$count'),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: _gold,
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
                  const Text(
                    'Chincha · Sede principal',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
            drawer: wide
                ? null
                : _OperationsDrawer(
                    sections: _sections,
                    selected: selected,
                    role: widget.role,
                    displayName: widget.displayName,
                    showNotifications: widget.role == 'Pasillo',
                    onSelected: _select,
                    onOpenNotifications: _openNotifications,
                    onSignOut: _signOut,
                    onManageUsers: widget.role == 'Administrador'
                        ? () => _openUsers(openUsersInitially: true)
                        : null,
                  ),
            body: Row(
              children: [
                if (wide)
                  _OperationsSideNav(
                    sections: _sections,
                    selected: selected,
                    role: widget.role,
                    displayName: widget.displayName,
                    onSelected: _select,
                    onSignOut: _signOut,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      const _OnlineNotice(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(compact ? 16 : 24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: _buildSection(selected),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: adminMobile
                ? NavigationBar(
                    selectedIndex: switch (selected) {
                      _Section.overview => 0,
                      _Section.products => 1,
                      _ => 3,
                    },
                    onDestinationSelected: (index) {
                      switch (index) {
                        case 0:
                          _select(_Section.overview);
                          break;
                        case 1:
                          _select(_Section.products);
                          break;
                        case 2:
                          unawaited(_openUsers(openUsersInitially: true));
                          break;
                        case 3:
                          _scaffoldKey.currentState?.openDrawer();
                          break;
                      }
                    },
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
                : widget.role == 'Caja' && compact
                ? NavigationBar(
                    selectedIndex: switch (selected) {
                      _Section.overview => 0,
                      _Section.products => 1,
                      _Section.sales || _Section.history => 2,
                      _Section.profile => 3,
                      _ => 0,
                    },
                    onDestinationSelected: (index) {
                      switch (index) {
                        case 0:
                          _select(_Section.overview);
                          break;
                        case 1:
                          _select(_Section.products);
                          break;
                        case 2:
                          _select(_Section.sales);
                          break;
                        case 3:
                          _select(_Section.profile);
                          break;
                      }
                    },
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
                        icon: Icon(Icons.point_of_sale_outlined),
                        selectedIcon: Icon(Icons.point_of_sale),
                        label: 'Ventas',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: 'Perfil',
                      ),
                    ],
                  )
                : gerenciaMobile
                ? NavigationBar(
                    selectedIndex: switch (selected) {
                      _Section.overview => 0,
                      _Section.products => 1,
                      _Section.inventory => 2,
                      _ => 3,
                    },
                    onDestinationSelected: (index) {
                      switch (index) {
                        case 0:
                          _select(_Section.overview);
                          break;
                        case 1:
                          _select(_Section.products);
                          break;
                        case 2:
                          _select(_Section.inventory);
                          break;
                        case 3:
                          _scaffoldKey.currentState?.openDrawer();
                          break;
                      }
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded),
                        selectedIcon: Icon(Icons.grid_view_rounded),
                        label: 'Resumen',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2),
                        label: 'Productos',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.swap_horiz_rounded),
                        selectedIcon: Icon(Icons.swap_horiz_rounded),
                        label: 'Existencias',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.menu),
                        selectedIcon: Icon(Icons.menu_open),
                        label: 'Más',
                      ),
                    ],
                  )
                : !wide && compact && _sections.length <= 4
                ? NavigationBar(
                    selectedIndex: _sections.indexOf(selected),
                    onDestinationSelected: (index) => _select(_sections[index]),
                    destinations: _sections.map(_destination).toList(),
                  )
                : null,
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(
          notificationService: _notificationService,
          notificationInfoMessage:
              _notificationSetupError ?? _notificationInfoMessage,
        ),
      ),
    );
  }

  Widget _buildSection(_Section section) {
    return switch (section) {
      _Section.overview when widget.role == 'Administrador' => AdminDashboard(
        usersStream: _adminUsersStream,
        auditStream: _adminAuditStream,
        todayAuditStream: _todayAuditStream,
        displayName: widget.displayName,
        onOpenUsers: () => unawaited(_openUsers(openUsersInitially: true)),
      ),
      _Section.overview when widget.role == 'Caja' => CashierHomePage(
        inventory: _inventory,
        cashShifts: _cashShifts,
        displayName: widget.displayName,
        onOpenProducts: () => _select(_Section.products),
        onOpenSales: () => _select(_Section.sales),
        onOpenHistory: () => _select(_Section.history),
      ),
      _Section.overview => _OverviewPage(
        inventory: _inventory,
        displayName: widget.displayName,
        role: widget.role,
        onSelect: _select,
      ),
      _Section.products => _ProductsPage(
        inventory: _inventory,
        canEdit: _isManager,
      ),
      _Section.inventory => _InventoryPage(
        inventory: _inventory,
        canManage: _isManager || widget.role == 'Pasillo',
      ),
      _Section.purchases => _PurchasesPage(inventory: _inventory),
      _Section.sales when widget.role == 'Caja' => _CashierSalesGate(
        inventory: _inventory,
        cashShifts: _cashShifts,
        onOpenHome: () => _select(_Section.overview),
      ),
      _Section.sales => _SalesPage(inventory: _inventory),
      _Section.reports => _ReportsPage(inventory: _inventory),
      _Section.history when widget.role == 'Caja' => CashierSalesHistoryPage(
        inventory: _inventory,
      ),
      _Section.history => _HistoryPage(inventory: _inventory),
      _Section.profile => UserProfilePage(
        displayName: widget.displayName,
        email: widget.user.email ?? '',
        role: widget.role,
        lastSignIn: widget.user.metadata.lastSignInTime,
        onSignOut: _signOut,
      ),
    };
  }

  void _select(_Section section) {
    final current = _selected ?? _sections.first;
    if (current != section) {
      setState(() {
        _sectionHistory.add(current);
        _selected = section;
      });
    }
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  void _goBackToPreviousSection() {
    if (_sectionHistory.isEmpty) return;
    setState(() => _selected = _sectionHistory.removeLast());
  }

  Future<void> _openUsers({bool openUsersInitially = false}) async {
    _scaffoldKey.currentState?.closeDrawer();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminPage(
          user: widget.user,
          displayName: widget.displayName,
          onSignOut: _signOut,
          unreadCountStream: _notificationService.watchUnreadCount(),
          onOpenNotifications: _openNotifications,
          openUsersInitially: openUsersInitially,
          onOpenHome: () => _select(_Section.overview),
          onOpenProducts: () => _select(_Section.products),
          onOpenMore: _openDrawerAfterRoute,
        ),
      ),
    );
  }

  void _openDrawerAfterRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scaffoldKey.currentState?.openDrawer();
    });
  }
}

class _OperationsDrawer extends StatelessWidget {
  const _OperationsDrawer({
    required this.sections,
    required this.selected,
    required this.role,
    required this.displayName,
    required this.showNotifications,
    required this.onSelected,
    required this.onManageUsers,
    required this.onOpenNotifications,
    this.onSignOut,
  });

  final List<_Section> sections;
  final _Section selected;
  final String role;
  final String displayName;
  final bool showNotifications;
  final ValueChanged<_Section> onSelected;
  final VoidCallback? onManageUsers;
  final VoidCallback onOpenNotifications;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: sections.indexOf(selected),
      onDestinationSelected: (index) => onSelected(sections[index]),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 18, 16, 8),
          child: _Brand(compact: true),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 16, 10),
          child: Text('SEDE PRINCIPAL · $displayName'),
        ),
        for (final section in sections) _drawerDestination(section),
        if (showNotifications)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Divider(),
          ),
        if (showNotifications)
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificaciones'),
            onTap: onOpenNotifications,
          ),
        if (onManageUsers != null || onSignOut != null)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Divider(),
          ),
        if (onManageUsers != null)
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Usuarios y permisos'),
            onTap: onManageUsers,
          ),
        if (onSignOut != null)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: onSignOut,
          ),
      ],
    );
  }
}

class _OperationsSideNav extends StatelessWidget {
  const _OperationsSideNav({
    required this.sections,
    required this.selected,
    required this.role,
    required this.displayName,
    required this.onSelected,
    required this.onSignOut,
  });

  final List<_Section> sections;
  final _Section selected;
  final String role;
  final String displayName;
  final ValueChanged<_Section> onSelected;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 238,
      color: _forest,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, 20),
                      child: Text(
                        'Chincha · Sede principal\nInventario / Operaciones',
                        style: TextStyle(color: Color(0xFFB8D3C9), height: 1.6),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, 10),
                      child: Text(
                        'ESPACIO DE TRABAJO',
                        style: TextStyle(
                          color: Color(0xFFB8D3C9),
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final section in sections)
                      _NavButton(
                        section: section,
                        selected: selected == section,
                        onTap: () => onSelected(section),
                      ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF145545),
                        child: Text(
                          _initials(displayName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      title: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        role,
                        style: const TextStyle(
                          color: Color(0xFFB8D3C9),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.logout,
                        color: Color(0xFFD0E4DC),
                      ),
                      title: const Text(
                        'Cerrar sesión',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      onTap: onSignOut,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _Section section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final destination = _destination(section);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? _green : _forest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        child: ListTile(
          selected: selected,
          leading: Icon(
            (destination.icon as Icon).icon,
            size: 20,
            color: const Color(0xFFD0E4DC),
          ),
          title: Text(
            destination.label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

NavigationDestination _destination(_Section section) {
  final (icon, label) = switch (section) {
    _Section.overview => (Icons.dashboard_outlined, 'Resumen'),
    _Section.products => (Icons.inventory_2_outlined, 'Productos'),
    _Section.inventory => (Icons.swap_horiz, 'Existencias'),
    _Section.purchases => (Icons.local_shipping_outlined, 'Compras'),
    _Section.sales => (Icons.point_of_sale_outlined, 'Caja y ventas'),
    _Section.reports => (Icons.bar_chart_outlined, 'Reportes'),
    _Section.history => (Icons.history, 'Mi historial'),
    _Section.profile => (Icons.person_outline, 'Perfil'),
  };
  return NavigationDestination(
    icon: Icon(icon),
    selectedIcon: Icon(icon),
    label: label,
  );
}

NavigationDrawerDestination _drawerDestination(_Section section) {
  final (icon, label) = switch (section) {
    _Section.overview => (Icons.dashboard_outlined, 'Resumen'),
    _Section.products => (Icons.inventory_2_outlined, 'Productos'),
    _Section.inventory => (Icons.swap_horiz, 'Existencias'),
    _Section.purchases => (Icons.local_shipping_outlined, 'Compras'),
    _Section.sales => (Icons.point_of_sale_outlined, 'Caja y ventas'),
    _Section.reports => (Icons.bar_chart_outlined, 'Reportes'),
    _Section.history => (Icons.history, 'Mi historial'),
    _Section.profile => (Icons.person_outline, 'Perfil'),
  };
  return NavigationDrawerDestination(
    icon: Icon(icon),
    selectedIcon: Icon(icon),
    label: Text(label),
  );
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    required this.inventory,
    required this.displayName,
    required this.role,
    required this.onSelect,
  });

  final InventoryService inventory;
  final String displayName;
  final String role;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) {
    if (role == 'Gerente' && MediaQuery.sizeOf(context).width < 600) {
      return _GerenciaMobileDashboard(
        inventory: inventory,
        displayName: displayName,
        onSelect: onSelect,
      );
    }

    final canSeeBusiness = role == 'Administrador' || role == 'Gerente';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(
          eyebrow: canSeeBusiness
              ? 'CONTROL GENERAL / $role'.toUpperCase()
              : 'OPERACIÓN / $role'.toUpperCase(),
          title: canSeeBusiness
              ? 'Buenos días, $displayName'
              : role == 'Caja'
              ? 'Tu caja, lista para atender'
              : 'Cada producto, en su lugar',
          subtitle: canSeeBusiness
              ? 'Tu operación de hoy, de un vistazo. Sede principal de Chincha.'
              : role == 'Caja'
              ? 'Registra ventas y consulta los precios vigentes.'
              : 'Consulta existencias y registra movimientos autorizados.',
        ),
        const SizedBox(height: 18),
        StreamBuilder<List<Product>>(
          stream: inventory.watchProducts(),
          builder: (context, productSnapshot) {
            if (productSnapshot.hasError) {
              return _ErrorCard(
                message:
                    'No se pudieron cargar los productos: '
                    '${productSnapshot.error}',
              );
            }
            if (!productSnapshot.hasData) return const _LoadingCard();
            final products = productSnapshot.data!;
            final active = products.where((product) => product.active).toList();
            final lowStock = active
                .where((product) => product.isLowStock)
                .toList();
            return _MetricGrid(
              children: [
                _MetricCard(
                  label: 'Productos activos',
                  value: '${active.length}',
                  detail: '${_categoryCount(active)} categorías',
                  icon: Icons.inventory_2_outlined,
                ),
                _MetricCard(
                  label: 'Productos con stock bajo',
                  value: '${lowStock.length}',
                  detail: 'Requieren revisión o reposición',
                  icon: Icons.warning_amber_outlined,
                ),
                if (canSeeBusiness)
                  StreamBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  >(
                    stream: inventory.watchSales(),
                    builder: (context, salesSnapshot) {
                      if (salesSnapshot.hasError) {
                        return _MetricCard(
                          label: 'Ventas registradas',
                          value: '—',
                          detail: 'No se pudieron consultar',
                          icon: Icons.point_of_sale_outlined,
                        );
                      }
                      final sales = salesSnapshot.data ?? [];
                      final today = DateTime.now();
                      final todaySales = sales.where((sale) {
                        final timestamp = sale.data()['occurredAt'];
                        if (timestamp is! Timestamp) return false;
                        final date = timestamp.toDate();
                        return date.year == today.year &&
                            date.month == today.month &&
                            date.day == today.day;
                      });
                      final total = todaySales.fold<double>(
                        0,
                        (subtotal, sale) =>
                            subtotal + _double(sale.data()['total']),
                      );
                      return _MetricCard(
                        label: 'Ventas de hoy',
                        value: _money(total),
                        detail: '${todaySales.length} comprobantes',
                        icon: Icons.point_of_sale_outlined,
                      );
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Productos por revisar',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onSelect(_Section.inventory),
              child: const Text('Abrir existencias'),
            ),
          ],
        ),
        StreamBuilder<List<Product>>(
          stream: inventory.watchProducts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}');
            }
            if (!snapshot.hasData) return const _LoadingCard();
            final low = snapshot.data!
                .where((product) => product.active && product.isLowStock)
                .take(5)
                .toList();
            if (low.isEmpty) {
              return const _EmptyCard(
                message: 'No hay productos por debajo del stock mínimo.',
              );
            }
            return Card(
              child: Column(
                children: low.map((product) {
                  return ListTile(
                    leading: const Icon(
                      Icons.inventory_2_outlined,
                      color: _green,
                    ),
                    title: Text(product.name),
                    subtitle: Text('${product.sku} · ${product.category}'),
                    trailing: Text(
                      '${product.stock} / mín. ${product.minStock}',
                      style: const TextStyle(
                        color: Color(0xFF88620B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GerenciaMobileDashboard extends StatelessWidget {
  const _GerenciaMobileDashboard({
    required this.inventory,
    required this.displayName,
    required this.onSelect,
  });

  final InventoryService inventory;
  final String displayName;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: inventory.watchProducts(),
      builder: (context, productSnapshot) {
        if (productSnapshot.hasError) {
          return _ErrorCard(
            message:
                'No se pudieron cargar los productos: '
                '${productSnapshot.error}',
          );
        }
        if (!productSnapshot.hasData) return const _LoadingCard();

        final products = productSnapshot.data!
            .where((product) => product.active)
            .toList();
        final lowStock =
            products.where((product) => product.isLowStock).toList()
              ..sort((a, b) => a.stock.compareTo(b.stock));

        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: inventory.watchSales(),
          builder: (context, salesSnapshot) {
            return StreamBuilder<
              List<QueryDocumentSnapshot<Map<String, dynamic>>>
            >(
              stream: inventory.watchRecentMovements(includeTeam: true),
              builder: (context, movementsSnapshot) {
                return StreamBuilder<Map<String, double>>(
                  stream: inventory.watchProductCosts(),
                  builder: (context, costsSnapshot) {
                    return _GerenciaDashboardContent(
                      displayName: displayName,
                      products: products,
                      lowStock: lowStock,
                      sales: salesSnapshot.data ?? const [],
                      salesError: salesSnapshot.error,
                      movements: movementsSnapshot.data ?? const [],
                      movementsError: movementsSnapshot.error,
                      costs: costsSnapshot.data ?? const {},
                      costsError: costsSnapshot.error,
                      onSelect: onSelect,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GerenciaDashboardContent extends StatelessWidget {
  const _GerenciaDashboardContent({
    required this.displayName,
    required this.products,
    required this.lowStock,
    required this.sales,
    required this.salesError,
    required this.movements,
    required this.movementsError,
    required this.costs,
    required this.costsError,
    required this.onSelect,
  });

  final String displayName;
  final List<Product> products;
  final List<Product> lowStock;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> sales;
  final Object? salesError;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> movements;
  final Object? movementsError;
  final Map<String, double> costs;
  final Object? costsError;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final weeklySales = sales.where((sale) {
      final timestamp = sale.data()['occurredAt'];
      if (timestamp is! Timestamp) return false;
      final date = timestamp.toDate();
      return !date.isBefore(weekStart) &&
          date.isBefore(DateTime(now.year, now.month, now.day + 1));
    }).toList();
    final weeklyTotal = weeklySales.fold<double>(
      0,
      (total, sale) => total + _double(sale.data()['total']),
    );
    final inventoryValue = products.fold<double>(
      0,
      (total, product) => total + (costs[product.id] ?? 0) * product.stock,
    );
    final stockUnits = products.fold<int>(
      0,
      (total, product) => total + product.stock,
    );
    final categories = _categoryCount(products);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GerenciaWelcomeCard(displayName: displayName, date: _mobileDate(now)),
        const SizedBox(height: 14),
        _GerenciaPriorityCard(
          lowStockCount: lowStock.length,
          onReview: () => onSelect(_Section.inventory),
          onPurchase: () => onSelect(_Section.purchases),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _GerenciaMetricCard(
                label: 'Productos activos',
                value: '${products.length}',
                detail: '$categories categorías',
                icon: Icons.inventory_2_outlined,
                tint: const Color(0xFFE7F5EF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GerenciaMetricCard(
                label: 'Stock bajo',
                value: '${lowStock.length}',
                detail: 'Por reponer',
                icon: Icons.warning_amber_outlined,
                tint: const Color(0xFFFFF3D0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GerenciaMetricCard(
                label: 'Valor al costo',
                value: costsError != null ? '—' : _money(inventoryValue),
                detail: costsError != null
                    ? 'No se pudieron cargar los costos'
                    : 'Inventario actual',
                icon: Icons.payments_outlined,
                tint: const Color(0xFFEAF1FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GerenciaMetricCard(
                label: 'Unidades en stock',
                value: '$stockUnits',
                detail: 'En productos activos',
                icon: Icons.warehouse_outlined,
                tint: const Color(0xFFF0EAFE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (salesError != null)
          _ErrorCard(message: 'No se pudieron cargar las ventas: $salesError')
        else
          _GerenciaWeeklySales(
            sales: sales,
            total: weeklyTotal,
            onOpen: () => onSelect(_Section.reports),
          ),
        const SizedBox(height: 12),
        _GerenciaSectionHeader(
          title: 'Atención al stock',
          actionLabel: 'Ver todo',
          onAction: () => onSelect(_Section.inventory),
          count: lowStock.length,
        ),
        const SizedBox(height: 6),
        if (lowStock.isEmpty)
          const _EmptyCard(message: 'No hay productos por debajo del mínimo.')
        else
          _GerenciaLowStockList(products: lowStock.take(4).toList()),
        const SizedBox(height: 12),
        _GerenciaSectionHeader(
          title: 'Historial reciente',
          actionLabel: 'Ver todo',
          onAction: () => onSelect(_Section.history),
        ),
        const SizedBox(height: 6),
        if (movementsError != null)
          _ErrorCard(message: 'No se pudo cargar el historial: $movementsError')
        else if (movements.isEmpty)
          const _EmptyCard(message: 'Aún no hay movimientos registrados.')
        else
          _GerenciaMovementList(movements: movements),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _GerenciaWelcomeCard extends StatelessWidget {
  const _GerenciaWelcomeCard({required this.displayName, required this.date});

  final String displayName;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE7E1)),
        borderRadius: BorderRadius.circular(18),
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
                  color: const Color(0xFFE7F5EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.space_dashboard_outlined,
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
                      'PANEL DE GERENCIA',
                      style: TextStyle(
                        color: _green,
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'SEDE PRINCIPAL · CHINCHA',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Buenos días, $displayName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tu operación de hoy, de un vistazo.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: _green,
              ),
              const SizedBox(width: 6),
              Text(
                date,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GerenciaPriorityCard extends StatelessWidget {
  const _GerenciaPriorityCard({
    required this.lowStockCount,
    required this.onReview,
    required this.onPurchase,
  });

  final int lowStockCount;
  final VoidCallback onReview;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final needsAttention = lowStockCount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_forest, Color(0xFF0D5944)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A07382D),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ESTADO DE EXISTENCIAS',
                  style: TextStyle(
                    color: Color(0xFFB8D3C9),
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: needsAttention
                      ? const Color(0xFFFFE6A4)
                      : const Color(0xFFCCF1E1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  needsAttention ? '$lowStockCount por revisar' : 'Al día',
                  style: const TextStyle(
                    color: _forest,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            needsAttention
                ? 'Revisa tu stock con tiempo.'
                : 'Todo está en orden.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            needsAttention
                ? '$lowStockCount productos están en el mínimo o por debajo.'
                : 'No hay productos que requieran reposición inmediata.',
            style: const TextStyle(
              color: Color(0xFFB8D3C9),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onReview,
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.fact_check_outlined, size: 17),
                  label: const Text(
                    'Revisar stock',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPurchase,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE0F3E9),
                    side: const BorderSide(color: Color(0xFF7FAF9D)),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.local_shipping_outlined, size: 17),
                  label: const Text('Compras', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GerenciaMetricCard extends StatelessWidget {
  const _GerenciaMetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 122),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: tint,
                    child: Icon(icon, size: 17, color: _green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GerenciaWeeklySales extends StatelessWidget {
  const _GerenciaWeeklySales({
    required this.sales,
    required this.total,
    required this.onOpen,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> sales;
  final double total;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
    final totals = days.map((day) {
      return sales
          .where((sale) {
            final timestamp = sale.data()['occurredAt'];
            if (timestamp is! Timestamp) return false;
            final date = timestamp.toDate();
            return date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
          })
          .fold<double>(
            0,
            (subtotal, sale) => subtotal + _double(sale.data()['total']),
          );
    }).toList();
    final maxValue = totals.fold<double>(
      0,
      (maximum, value) => math.max(maximum, value).toDouble(),
    );
    const weekdayLabels = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ventas de la semana',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'ÚLTIMOS 7 DÍAS',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 9,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F5EF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _money(total),
                    style: const TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Abrir reportes',
                  onPressed: onOpen,
                  visualDensity: VisualDensity.standard,
                  icon: const Icon(Icons.chevron_right, size: 19),
                ),
              ],
            ),
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < days.length; index++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 62,
                              width: 26,
                              alignment: Alignment.bottomCenter,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F5F2),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Container(
                                height: maxValue == 0
                                    ? 6
                                    : math
                                          .max(6, totals[index] / maxValue * 62)
                                          .toDouble(),
                                decoration: BoxDecoration(
                                  color: index == days.length - 1
                                      ? const Color(0xFF57B58C)
                                      : _green,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              weekdayLabels[days[index].weekday % 7],
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GerenciaSectionHeader extends StatelessWidget {
  const _GerenciaSectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.count,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F5EF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.only(left: 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _GerenciaLowStockList extends StatelessWidget {
  const _GerenciaLowStockList({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < products.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 12, endIndent: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              visualDensity: const VisualDensity(vertical: -1),
              leading: const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFFFF3D0),
                child: Icon(
                  Icons.warning_amber_outlined,
                  size: 18,
                  color: Color(0xFFAD7900),
                ),
              ),
              title: Text(
                products[index].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${products[index].sku} · ${products[index].category}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D0),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${products[index].stock} / ${products[index].minStock}',
                  style: const TextStyle(
                    color: Color(0xFF88620B),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GerenciaMovementList extends StatelessWidget {
  const _GerenciaMovementList({required this.movements});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> movements;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < movements.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 12, endIndent: 12),
            Builder(
              builder: (context) {
                final data = movements[index].data();
                final type = data['type'] as String? ?? '';
                final description = switch (type) {
                  'sale' => 'Venta',
                  'entry' => 'Entrada de stock',
                  'exit' => 'Salida de stock',
                  'adjustment' => 'Ajuste de inventario',
                  'purchase' => 'Compra recibida',
                  _ => 'Movimiento',
                };
                final timestamp = data['occurredAt'];
                final when = timestamp is Timestamp
                    ? _formatDateTime(timestamp.toDate())
                    : 'Registrando…';
                final isOutgoing = type == 'sale' || type == 'exit';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: const VisualDensity(vertical: -1),
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor: isOutgoing
                        ? const Color(0xFFFFF3D0)
                        : const Color(0xFFE7F5EF),
                    child: Icon(
                      isOutgoing
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      size: 15,
                      color: isOutgoing ? const Color(0xFFAD7900) : _green,
                    ),
                  ),
                  title: Text(
                    '$description · ${data['productName'] ?? 'Producto'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${data['actorName'] ?? ''} · $when',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isOutgoing
                          ? const Color(0xFFFFF3D0)
                          : const Color(0xFFE7F5EF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${isOutgoing ? '-' : '+'}${data['quantity'] ?? 0}',
                      style: TextStyle(
                        color: isOutgoing ? const Color(0xFF88620B) : _green,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

String _mobileDate(DateTime date) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${date.day} de ${months[date.month - 1]} de ${date.year}';
}

class _ProductsPage extends StatefulWidget {
  const _ProductsPage({required this.inventory, required this.canEdit});

  final InventoryService inventory;
  final bool canEdit;

  @override
  State<_ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<_ProductsPage> {
  final _search = TextEditingController();
  String _query = '';
  String _category = 'Todas';
  bool _showArchived = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(
          eyebrow:
              'CATÁLOGO / ${widget.canEdit ? 'ADMINISTRACIÓN' : 'CONSULTA'}',
          title: 'Productos y categorías',
          subtitle: 'Busca artículos, precios y disponibilidad en tiempo real.',
          action: widget.canEdit
              ? FilledButton.icon(
                  onPressed: _editProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo producto'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _ErrorCard(message: _error!),
          const SizedBox(height: 12),
        ],
        StreamBuilder<List<Product>>(
          stream: widget.inventory.watchProducts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorCard(
                message:
                    'No se pudieron cargar los productos: '
                    '${snapshot.error}',
              );
            }
            if (!snapshot.hasData) return const _LoadingCard();
            final products = snapshot.data!
                .where(
                  (product) => _showArchived ? !product.active : product.active,
                )
                .toList();
            final categories =
                products
                    .map((product) => product.category.trim())
                    .where(
                      (category) => category.isNotEmpty && category != 'Todas',
                    )
                    .toSet()
                    .toList()
                  ..sort();
            final selectedCategory =
                _category == 'Todas' || categories.contains(_category)
                ? _category
                : 'Todas';
            final filtered = products.where((product) {
              final query = _query.toLowerCase();
              final matchesQuery =
                  query.isEmpty ||
                  product.name.toLowerCase().contains(query) ||
                  product.sku.toLowerCase().contains(query);
              return matchesQuery &&
                  (selectedCategory == 'Todas' ||
                      product.category.trim() == selectedCategory);
            }).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 600;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: compact ? constraints.maxWidth : 300,
                          child: TextField(
                            controller: _search,
                            onChanged: (value) =>
                                setState(() => _query = value.trim()),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Buscar por nombre o código',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: compact ? constraints.maxWidth : 220,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Categoría',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'Todas',
                                child: Text('Todas'),
                              ),
                              ...categories.map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(
                                    category,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _category = value ?? 'Todas'),
                          ),
                        ),
                        if (widget.canEdit)
                          FilterChip(
                            label: const Text('Archivados'),
                            selected: _showArchived,
                            onSelected: (value) =>
                                setState(() => _showArchived = value),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  _EmptyCard(
                    message: _showArchived ? 'No hay productos archivados.' : 'No se encontraron productos. Agrega el primer artículo al catálogo.',
                  )
                else
                  Card(
                    child: Column(
                      children: filtered
                          .map(
                            (product) => _ProductTile(
                              product: product,
                              canEdit: widget.canEdit,
                              onEdit: () => _editProduct(product),
                              onArchive: () =>
                                  _toggleActive(product, !product.active),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _editProduct([Product? product]) async {
    var cost = 0.0;
    late final List<String> categories;
    try {
      categories = await widget.inventory.getProductCategories();
      if (product != null) {
        cost = await widget.inventory.getProductCost(product.id);
      }
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _error = _firebaseMessage(error));
      return;
    }
    if (!mounted) return;
    final input = await showDialog<_ProductInput>(
      context: context,
      builder: (_) =>
          _ProductDialog(product: product, cost: cost, categories: categories),
    );
    if (input == null || !mounted) return;
    try {
      await widget.inventory.saveProduct(
        id: product?.id,
        sku: input.sku,
        name: input.name,
        description: input.description,
        category: input.category,
        cost: input.cost,
        price: input.price,
        minStock: input.minStock,
        initialStock: input.initialStock,
      );
      if (mounted) _showMessage('Producto guardado.');
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _error = _firebaseMessage(error));
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _toggleActive(Product product, bool active) async {
    try {
      await widget.inventory.setProductActive(product, active);
      if (mounted) {
        _showMessage(active ? 'Producto restaurado.' : 'Producto archivado.');
      }
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _error = _firebaseMessage(error));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.canEdit,
    required this.onEdit,
    required this.onArchive,
  });

  final Product product;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE5F4ED),
        child: Icon(
          product.isLowStock
              ? Icons.warning_amber_outlined
              : Icons.inventory_2_outlined,
          color: product.isLowStock ? const Color(0xFF88620B) : _green,
        ),
      ),
      title: Text(product.name),
      subtitle: Text(
        [
          if (product.description.trim().isNotEmpty) product.description.trim(),
          '${product.sku} · ${product.category} · Stock ${product.stock}',
        ].join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _money(product.price),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (canEdit) ...[
            IconButton(
              tooltip: 'Editar producto',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: product.active
                  ? 'Archivar producto'
                  : 'Restaurar producto',
              onPressed: onArchive,
              icon: Icon(
                product.active
                    ? Icons.archive_outlined
                    : Icons.unarchive_outlined,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({
    required this.product,
    required this.cost,
    required this.categories,
  });

  final Product? product;
  final double cost;
  final List<String> categories;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _sku = TextEditingController(text: widget.product?.sku ?? '');
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _description = TextEditingController(
    text: widget.product?.description ?? '',
  );
  final _newCategory = TextEditingController();
  late final _cost = TextEditingController(
    text: widget.product == null ? '' : widget.cost.toStringAsFixed(2),
  );
  late final _price = TextEditingController(
    text: widget.product?.price.toStringAsFixed(2) ?? '',
  );
  late final _minStock = TextEditingController(
    text: widget.product?.minStock.toString() ?? '',
  );
  late final _initialStock = TextEditingController();
  final _costFocus = FocusNode();
  final _minStockFocus = FocusNode();
  final _initialStockFocus = FocusNode();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _costFocus.addListener(_onNumericFieldFocusChanged);
    _minStockFocus.addListener(_onNumericFieldFocusChanged);
    _initialStockFocus.addListener(_onNumericFieldFocusChanged);
    final category = widget.product?.category.trim();
    _selectedCategory = category == null || category.isEmpty ? null : category;
  }

  void _onNumericFieldFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _costFocus.removeListener(_onNumericFieldFocusChanged);
    _minStockFocus.removeListener(_onNumericFieldFocusChanged);
    _initialStockFocus.removeListener(_onNumericFieldFocusChanged);
    _costFocus.dispose();
    _minStockFocus.dispose();
    _initialStockFocus.dispose();
    _sku.dispose();
    _name.dispose();
    _description.dispose();
    _newCategory.dispose();
    _cost.dispose();
    _price.dispose();
    _minStock.dispose();
    _initialStock.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio.' : null;

  String? _skuValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    return RegExp(r'^\d+$').hasMatch(value!.trim())
        ? null
        : 'El código solo puede contener números.';
  }

  String? _number(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || number < 0 ? 'Ingresa un número válido.' : null;
  }

  String? _numberOrZero(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _number(value);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final category = _selectedCategory == ''
        ? _newCategory.text.trim()
        : _selectedCategory!.trim();
    Navigator.pop(
      context,
      _ProductInput(
        sku: _sku.text.trim(),
        name: _name.text.trim(),
        description: _description.text.trim(),
        category: category,
        cost: double.tryParse(_cost.text.trim()) ?? 0,
        price: double.parse(_price.text.trim()),
        minStock: int.tryParse(_minStock.text.trim()) ?? 0,
        initialStock: widget.product == null
            ? int.tryParse(_initialStock.text.trim()) ?? 0
            : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.product != null;
    final categories = widget.categories.toSet();
    final currentCategory = widget.product?.category.trim();
    if (currentCategory != null && currentCategory.isNotEmpty) {
      categories.add(currentCategory);
    }
    final sortedCategories = categories.toList()..sort();
    return AlertDialog(
      title: Text(existing ? 'Editar producto' : 'Nuevo producto'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _sku,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Código / SKU'),
                  validator: _skuValidator,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    helperText: 'Elige una existente o crea una nueva.',
                  ),
                  items: [
                    ...sortedCategories.map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Crear categoría nueva'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                  validator: (value) =>
                      value == null ? 'Selecciona una categoría.' : null,
                ),
                if (_selectedCategory == '') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _newCategory,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la nueva categoría',
                    ),
                    validator: _required,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cost,
                        focusNode: _costFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Costo (S/)',
                          hintText: _costFocus.hasFocus ? null : '0.00',
                        ),
                        validator: _numberOrZero,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio de venta',
                        ),
                        validator: _number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minStock,
                        focusNode: _minStockFocus,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Stock mínimo',
                          hintText: _minStockFocus.hasFocus ? null : '0',
                        ),
                        validator: (value) {
                          final input = value?.trim() ?? '';
                          if (input.isEmpty) return null;
                          final parsed = int.tryParse(input);
                          return parsed == null || parsed < 0
                              ? 'Ingresa un entero válido.'
                              : null;
                        },
                      ),
                    ),
                    if (!existing) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _initialStock,
                          focusNode: _initialStockFocus,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Stock inicial',
                            hintText: _initialStockFocus.hasFocus ? null : '0',
                          ),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            if (input.isEmpty) return null;
                            final parsed = int.tryParse(input);
                            return parsed == null || parsed < 0
                                ? 'Ingresa un entero válido.'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _ProductInput {
  const _ProductInput({
    required this.sku,
    required this.name,
    required this.description,
    required this.category,
    required this.cost,
    required this.price,
    required this.minStock,
    required this.initialStock,
  });

  final String sku;
  final String name;
  final String description;
  final String category;
  final double cost;
  final double price;
  final int minStock;
  final int initialStock;
}

class _InventoryPage extends StatefulWidget {
  const _InventoryPage({required this.inventory, required this.canManage});

  final InventoryService inventory;
  final bool canManage;

  @override
  State<_InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<_InventoryPage> {
  String _query = '';
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(
          eyebrow: 'OPERACIÓN DE PISO / EXISTENCIAS',
          title: 'Cada producto, en su lugar',
          subtitle: 'Consulta stock y registra entradas, salidas o ajustes.',
        ),
        const SizedBox(height: 16),
        if (_error != null) _ErrorCard(message: _error!),
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar producto o SKU',
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Product>>(
          stream: widget.inventory.watchProducts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}');
            }
            if (!snapshot.hasData) return const _LoadingCard();
            final products = snapshot.data!
                .where((product) => product.active)
                .where((product) {
                  final query = _query.toLowerCase();
                  return product.name.toLowerCase().contains(query) ||
                      product.sku.toLowerCase().contains(query);
                })
                .toList();
            if (products.isEmpty) {
              return const _EmptyCard(
                message: 'No hay productos para mostrar.',
              );
            }
            return Card(
              child: Column(
                children: products
                    .map(
                      (product) => ListTile(
                        leading: Icon(
                          product.isLowStock
                              ? Icons.warning_amber_outlined
                              : Icons.inventory_2_outlined,
                          color: product.isLowStock
                              ? const Color(0xFF88620B)
                              : _green,
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.sku} · ${product.category} · '
                          'Mínimo ${product.minStock}',
                        ),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${product.stock} u.',
                              style: TextStyle(
                                color: product.isLowStock
                                    ? const Color(0xFF88620B)
                                    : _ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (widget.canManage)
                              IconButton(
                                tooltip: 'Registrar movimiento',
                                onPressed: () => _movement(product),
                                icon: const Icon(Icons.add_box_outlined),
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _movement(Product product) async {
    final input = await showDialog<_MovementInput>(
      context: context,
      builder: (_) => const _MovementDialog(),
    );
    if (input == null || !mounted) return;
    try {
      await widget.inventory.adjustStock(
        product: product,
        operation: input.operation,
        quantity: input.quantity,
        reason: input.reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimiento de stock registrado.')),
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _error = _firebaseMessage(error));
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog();

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  String _operation = 'entry';

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_operation) {
      'entry' => 'Cantidad que ingresa',
      'exit' => 'Cantidad que sale',
      _ => 'Nuevo stock total',
    };
    return AlertDialog(
      title: const Text('Registrar movimiento'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _operation,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'entry', child: Text('Entrada')),
                DropdownMenuItem(value: 'exit', child: Text('Salida')),
                DropdownMenuItem(
                  value: 'adjustment',
                  child: Text('Ajuste de inventario'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _operation = value ?? 'entry'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _quantity,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: label),
              validator: (value) {
                final number = int.tryParse(value?.trim() ?? '');
                return number == null ||
                        number < 0 ||
                        (_operation != 'adjustment' && number == 0)
                    ? 'Ingresa una cantidad válida.'
                    : null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Motivo'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Indica el motivo del movimiento.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _MovementInput(
                operation: _operation,
                quantity: int.parse(_quantity.text.trim()),
                reason: _reason.text.trim(),
              ),
            );
          },
          child: const Text('Guardar movimiento'),
        ),
      ],
    );
  }
}

class _MovementInput {
  const _MovementInput({
    required this.operation,
    required this.quantity,
    required this.reason,
  });

  final String operation;
  final int quantity;
  final String reason;
}

class _CashierSalesGate extends StatelessWidget {
  const _CashierSalesGate({
    required this.inventory,
    required this.cashShifts,
    required this.onOpenHome,
  });

  final InventoryService inventory;
  final CashShiftService cashShifts;
  final VoidCallback onOpenHome;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CashShift?>(
      stream: cashShifts.watchCurrentShift(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorCard(
            message: 'No se pudo validar el turno de caja: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        final shift = snapshot.data;
        if (shift == null || !shift.isOpen) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PageHeading(
                eyebrow: 'PUNTO DE VENTA / CAJA',
                title: 'Abre tu turno para vender',
                subtitle: 'El turno abierto vincula las ventas, el efectivo y el arqueo de caja.',
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_clock_outlined,
                        color: _green,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No hay un turno abierto',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ve a Inicio y registra el fondo inicial antes de cobrar.',
                        style: TextStyle(color: _muted, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: onOpenHome,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Ir a Inicio'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return _SalesPage(inventory: inventory, cashShiftId: shift.id);
      },
    );
  }
}

class _SalesPage extends StatefulWidget {
  const _SalesPage({required this.inventory, this.cashShiftId});

  final InventoryService inventory;
  final String? cashShiftId;

  @override
  State<_SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<_SalesPage> {
  final _search = TextEditingController();
  final _amountReceived = TextEditingController();
  final Map<String, int> _cart = {};
  String _query = '';
  String _paymentMethod = 'Efectivo';
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _amountReceived.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: widget.inventory.watchProducts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorCard(message: '${snapshot.error}');
        }
        if (!snapshot.hasData) return const _LoadingCard();
        final products = snapshot.data!
            .where((product) => product.active)
            .where((product) {
              final query = _query.toLowerCase();
              return product.name.toLowerCase().contains(query) ||
                  product.sku.toLowerCase().contains(query);
            })
            .toList();
        final allProducts = snapshot.data!
            .where((product) => product.active)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PageHeading(
              eyebrow: 'PUNTO DE VENTA / CAJA',
              title: 'Tu caja, lista para atender',
              subtitle:
                  'Agrega productos, verifica el total y registra el pago.',
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              _ErrorCard(message: _error!),
              const SizedBox(height: 10),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                final catalog = _salesCatalog(products);
                final cart = _cartPanel(allProducts);
                if (!wide) {
                  return Column(
                    children: [catalog, const SizedBox(height: 14), cart],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: catalog),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: cart),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _salesCatalog(List<Product> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar producto o escanear código',
          ),
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          const _EmptyCard(message: 'No se encontraron productos disponibles.')
        else
          Card(
            child: Column(
              children: products.take(80).map((product) {
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    '${product.sku} · ${product.stock} disponibles',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _money(product.price),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        tooltip: 'Agregar a la venta',
                        onPressed: product.stock <= (_cart[product.id] ?? 0)
                            ? null
                            : () => setState(
                                () => _cart.update(
                                  product.id,
                                  (quantity) => quantity + 1,
                                  ifAbsent: () => 1,
                                ),
                              ),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _cartPanel(List<Product> products) {
    final byId = {for (final product in products) product.id: product};
    final lines = _cart.entries
        .where((entry) => byId.containsKey(entry.key))
        .toList();
    final totalCents = lines.fold<int>(
      0,
      (subtotal, entry) =>
          subtotal + moneyToCents(byId[entry.key]!.price) * entry.value,
    );
    final total = totalCents / 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Venta actual',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Agrega productos para comenzar.'),
              )
            else
              ...lines.map((entry) {
                final product = byId[entry.key]!;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(product.name),
                  subtitle: Text('${entry.value} × ${_money(product.price)}'),
                  trailing: IconButton(
                    tooltip: 'Quitar una unidad',
                    onPressed: () => setState(() {
                      if (entry.value <= 1) {
                        _cart.remove(entry.key);
                      } else {
                        _cart[entry.key] = entry.value - 1;
                      }
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                );
              }),
            const Divider(),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Medio de pago'),
              items: const [
                DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                DropdownMenuItem(
                  value: 'Transferencia',
                  child: Text('Transferencia'),
                ),
              ],
              onChanged: (value) => setState(() {
                _paymentMethod = value ?? 'Efectivo';
                _amountReceived.clear();
              }),
            ),
            if (_paymentMethod == 'Efectivo') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _amountReceived,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Efectivo recibido',
                  prefixText: 'S/ ',
                  suffixIcon: IconButton(
                    tooltip: 'Pagar monto exacto',
                    onPressed: () => setState(
                      () => _amountReceived.text = total.toStringAsFixed(2),
                    ),
                    icon: const Icon(Icons.done),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              _cashChangeSummary(total),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  _money(total),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: lines.isEmpty || _working
                    ? null
                    : () => _checkout(lines, byId),
                icon: _working
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.point_of_sale_outlined),
                label: Text(_working ? 'Registrando…' : 'Cobrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cashChangeSummary(double total) {
    final received = _parseReceivedAmount();
    if (received == null) {
      return const Text(
        'Ingresa el efectivo recibido para calcular el vuelto.',
        style: TextStyle(color: _muted, fontSize: 12),
      );
    }
    final difference = received - total;
    return Row(
      children: [
        Expanded(
          child: Text(
            difference >= 0 ? 'Vuelto' : 'Falta recibir',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        Text(
          _money(difference.abs()),
          style: TextStyle(
            color: difference >= 0 ? _green : const Color(0xFFAE4545),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  double? _parseReceivedAmount() {
    final amount = double.tryParse(
      _amountReceived.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || !amount.isFinite || amount < 0) return null;
    return (amount * 100).round() / 100;
  }

  Future<void> _checkout(
    List<MapEntry<String, int>> lines,
    Map<String, Product> byId,
  ) async {
    final displayedTotalCents = lines.fold<int>(
      0,
      (subtotal, line) =>
          subtotal + moneyToCents(byId[line.key]!.price) * line.value,
    );
    final displayedTotal = displayedTotalCents / 100;
    final amountReceived = _paymentMethod == 'Efectivo'
        ? _parseReceivedAmount()
        : displayedTotal;
    if (amountReceived == null || amountReceived < displayedTotal) {
      setState(
        () => _error = 'El efectivo recibido debe cubrir el total de la venta.',
      );
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final receipt = await widget.inventory.registerSale(
        lines: [
          for (final line in lines)
            SaleLine(product: byId[line.key]!, quantity: line.value),
        ],
        paymentMethod: _paymentMethod,
        amountReceived: amountReceived,
        cashShiftId: widget.cashShiftId,
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _amountReceived.clear();
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: _green, size: 36),
          title: const Text('Venta registrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comprobante #${receipt.id.substring(0, 8).toUpperCase()}'),
              const SizedBox(height: 12),
              _receiptAmountRow('Total', receipt.total),
              if (_paymentMethod == 'Efectivo') ...[
                _receiptAmountRow('Recibido', receipt.amountReceived),
                _receiptAmountRow('Vuelto', receipt.changeDue),
              ],
              const SizedBox(height: 8),
              Text('Pago: $_paymentMethod'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nueva venta'),
            ),
          ],
        ),
      );
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _error = _firebaseMessage(error));
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _receiptAmountRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            _money(amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PurchasesPage extends StatelessWidget {
  const _PurchasesPage({required this.inventory});

  final InventoryService inventory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(
          eyebrow: 'ABASTECIMIENTO / ALMACÉN',
          title: 'Compras y recepción',
          subtitle: 'Registra mercadería recibida y actualiza existencias.',
          action: FilledButton.icon(
            onPressed: () => _createPurchase(context),
            icon: const Icon(Icons.add),
            label: const Text('Registrar compra'),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: inventory.watchPurchases(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorCard(
                message:
                    'No se pudieron cargar las compras: '
                    '${snapshot.error}',
              );
            }
            if (!snapshot.hasData) return const _LoadingCard();
            final purchases = snapshot.data!.toList()
              ..sort(
                (a, b) =>
                    _timestamp(b.data()['occurredAt'])
                        .compareTo(_timestamp(a.data()['occurredAt'])),
              );
            if (purchases.isEmpty) {
              return const _EmptyCard(
                message: 'Aún no se han registrado compras.',
              );
            }
            return Card(
              child: Column(
                children: purchases.map((purchase) {
                  final data = purchase.data();
                  return ListTile(
                    leading: const Icon(
                      Icons.local_shipping_outlined,
                      color: _green,
                    ),
                    title: Text(data['productName'] as String? ?? 'Producto'),
                    subtitle: Text(
                      '${data['supplier'] ?? 'Proveedor sin nombre'} · '
                      '${data['quantity'] ?? 0} u. · '
                      '${data['reference'] ?? 'Sin referencia'}',
                    ),
                    trailing: Text(_money(_double(data['total']))),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _createPurchase(BuildContext context) async {
    final products = await inventory.watchProducts().first;
    if (!context.mounted) return;
    final active = products.where((product) => product.active).toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero registra un producto activo.')),
      );
      return;
    }
    final input = await showDialog<_PurchaseInput>(
      context: context,
      builder: (_) => _PurchaseDialog(products: active),
    );
    if (input == null || !context.mounted) return;
    try {
      await inventory.recordPurchase(
        product: input.product,
        quantity: input.quantity,
        unitCost: input.unitCost,
        supplier: input.supplier,
        reference: input.reference,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra recibida y stock actualizado.')),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_firebaseMessage(error))));
      }
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({required this.products});

  final List<Product> products;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _cost = TextEditingController();
  final _supplier = TextEditingController();
  final _reference = TextEditingController();
  late String _productId = widget.products.first.id;

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    _supplier.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar compra recibida'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _productId,
                  decoration: const InputDecoration(labelText: 'Producto'),
                  items: widget.products
                      .map(
                        (product) => DropdownMenuItem(
                          value: product.id,
                          child: Text('${product.sku} · ${product.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _productId = value ?? _productId),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Unidades',
                        ),
                        validator: (value) {
                          final number = int.tryParse(value?.trim() ?? '');
                          return number == null || number <= 0
                              ? 'Cantidad inválida.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _cost,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Costo unitario',
                        ),
                        validator: (value) {
                          final number = double.tryParse(value?.trim() ?? '');
                          return number == null || number < 0
                              ? 'Costo inválido.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _supplier,
                  decoration: const InputDecoration(labelText: 'Proveedor'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reference,
                  decoration: const InputDecoration(
                    labelText: 'N.º de comprobante',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _PurchaseInput(
                product: widget.products.firstWhere(
                  (item) => item.id == _productId,
                ),
                quantity: int.parse(_quantity.text.trim()),
                unitCost: double.parse(_cost.text.trim()),
                supplier: _supplier.text.trim(),
                reference: _reference.text.trim(),
              ),
            );
          },
          child: const Text('Guardar recepción'),
        ),
      ],
    );
  }
}

class _PurchaseInput {
  const _PurchaseInput({
    required this.product,
    required this.quantity,
    required this.unitCost,
    required this.supplier,
    required this.reference,
  });

  final Product product;
  final int quantity;
  final double unitCost;
  final String supplier;
  final String reference;
}

class _ReportsPage extends StatelessWidget {
  const _ReportsPage({required this.inventory});

  final InventoryService inventory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeading(
          eyebrow: 'CONTROL GENERAL / GERENCIA',
          title: 'Reportes de operación',
          subtitle: 'Ventas, existencias y productos que necesitan reposición.',
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Product>>(
          stream: inventory.watchProducts(),
          builder: (context, productSnapshot) {
            if (productSnapshot.hasError) {
              return _ErrorCard(message: '${productSnapshot.error}');
            }
            if (!productSnapshot.hasData) return const _LoadingCard();
            final active = productSnapshot.data!.where(
              (product) => product.active,
            );
            final low = active.where((product) => product.isLowStock).toList();
            return StreamBuilder<Map<String, double>>(
              stream: inventory.watchProductCosts(),
              builder: (context, costSnapshot) {
                if (costSnapshot.hasError) {
                  return _ErrorCard(
                    message:
                        'No se pudieron cargar los costos: '
                        '${costSnapshot.error}',
                  );
                }
                if (!costSnapshot.hasData) return const _LoadingCard();
                final inventoryValue = active.fold<double>(
                  0,
                  (subtotal, product) =>
                      subtotal +
                      (costSnapshot.data![product.id] ?? 0) * product.stock,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricGrid(
                      children: [
                        _MetricCard(
                          label: 'Valor de inventario al costo',
                          value: _money(inventoryValue),
                          detail: '${active.length} productos activos',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        _MetricCard(
                          label: 'Productos bajo mínimo',
                          value: '${low.length}',
                          detail: 'Stock actual menor o igual al mínimo',
                          icon: Icons.warning_amber_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Reposición prioritaria',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (low.isEmpty)
                      const _EmptyCard(
                        message: 'No hay productos bajo el stock mínimo.',
                      )
                    else
                      Card(
                        child: Column(
                          children: low
                              .map(
                                (product) => ListTile(
                                  title: Text(product.name),
                                  subtitle: Text(
                                    '${product.sku} · ${product.category}',
                                  ),
                                  trailing: Text(
                                    '${product.stock} / ${product.minStock} u.',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _SalesReport(inventory: inventory),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.inventory});

  final InventoryService inventory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeading(
          eyebrow: 'ACTIVIDAD / USUARIO',
          title: 'Mi historial',
          subtitle:
              'Consulta las ventas y movimientos registrados por tu cuenta.',
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: inventory.watchMyMovements(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorCard(
                message: 'No se pudo cargar tu historial: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) return const _LoadingCard();
            final movements = snapshot.data!.toList()
              ..sort(
                (a, b) =>
                    _timestamp(b.data()['occurredAt'])
                        .compareTo(_timestamp(a.data()['occurredAt'])),
              );
            if (movements.isEmpty) {
              return const _EmptyCard(
                message: 'Todavía no tienes operaciones registradas.',
              );
            }
            return Card(
              child: Column(
                children: movements.map((movement) {
                  final data = movement.data();
                  final type = data['type'] as String? ?? '';
                  final label = switch (type) {
                    'sale' => 'Venta',
                    'entry' => 'Entrada de stock',
                    'exit' => 'Salida de stock',
                    'adjustment' => 'Ajuste de inventario',
                    'purchase' => 'Compra recibida',
                    _ => 'Movimiento',
                  };
                  final rawTimestamp = data['occurredAt'];
                  final date = rawTimestamp is Timestamp
                      ? _formatDateTime(rawTimestamp.toDate())
                      : 'Registrando…';
                  final before = (data['beforeStock'] as num?)?.toInt() ?? 0;
                  final after = (data['afterStock'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    leading: Icon(
                      type == 'sale' || type == 'exit'
                          ? Icons.south_west
                          : Icons.north_east,
                      color: type == 'sale' || type == 'exit'
                          ? const Color(0xFF88620B)
                          : _green,
                    ),
                    title: Text(
                      '$label · ${data['productName'] ?? 'Producto'}',
                    ),
                    subtitle: Text(
                      '${data['reason'] ?? ''} · $date · $before → $after u.',
                    ),
                    trailing: Text(
                      '${data['quantity'] ?? 0} u.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SalesReport extends StatelessWidget {
  const _SalesReport({required this.inventory});

  final InventoryService inventory;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: inventory.watchSales(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorCard(
            message:
                'No se pudieron cargar las ventas: '
                '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) return const _LoadingCard();
        final sales = snapshot.data!;
        final now = DateTime.now();
        final today = sales.where((sale) {
          final timestamp = sale.data()['occurredAt'];
          if (timestamp is! Timestamp) return false;
          final date = timestamp.toDate();
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        });
        final total = today.fold<double>(
          0,
          (subtotal, sale) => subtotal + _double(sale.data()['total']),
        );
        return Card(
          child: ListTile(
            leading: const Icon(Icons.point_of_sale_outlined, color: _green),
            title: const Text('Ventas de hoy'),
            subtitle: Text('${today.length} ventas registradas'),
            trailing: Text(
              _money(total),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        );
      },
    );
  }
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
          width: compact ? 36 : 42,
          height: compact ? 36 : 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            'CH',
            style: TextStyle(
              color: _forest,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'IMPORTACIONES\nCHATO',
          style: TextStyle(
            color: Colors.white,
            height: 1.05,
            letterSpacing: 1,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OnlineNotice extends StatelessWidget {
  const _OnlineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF5D6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_outlined, size: 16, color: Color(0xFF88620B)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sesión segura · Información sincronizada con Firebase',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFF765711), fontSize: 12),
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
    this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
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
                color: _ink,
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 14)),
          ],
        );
        if (action == null) return heading;
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 12), action!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            action!,
          ],
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(color: _muted)),
                ),
                Icon(icon, size: 19, color: _green),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(color: Color(0xFF71847B), fontSize: 12),
            ),
          ],
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
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAE4545)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

String _initials(String value) => value
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0])
    .take(2)
    .join()
    .toUpperCase();

int _categoryCount(Iterable<Product> products) =>
    products.map((product) => product.category).toSet().length;

double _double(Object? value) => value is num ? value.toDouble() : 0;

String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

String _formatDateTime(DateTime timestamp) =>
    '${timestamp.day.toString().padLeft(2, '0')}/'
    '${timestamp.month.toString().padLeft(2, '0')}/'
    '${timestamp.year} · '
    '${timestamp.hour.toString().padLeft(2, '0')}:'
    '${timestamp.minute.toString().padLeft(2, '0')}';

DateTime _timestamp(Object? value) => value is Timestamp
    ? value.toDate()
    : DateTime.fromMillisecondsSinceEpoch(0);

String _firebaseMessage(FirebaseException error) {
  return switch (error.code) {
    'permission-denied' => 'La operación no está permitida. Verifica las reglas publicadas de Firestore.',
    'unavailable' =>
      'No se pudo conectar con Firebase. Revisa internet e inténtalo otra vez.',
    'already-exists' => 'Ya existe un registro con esos datos.',
    _ => 'No se completó la operación (${error.code}).',
  };
}
