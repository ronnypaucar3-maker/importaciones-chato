import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    required this.notificationService,
    required this.notificationInfoMessage,
    super.key,
  });

  final NotificationService notificationService;
  final String? notificationInfoMessage;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final Stream<List<AppNotification>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = widget.notificationService.watchNotifications();
    unawaited(_markAllAsRead());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.notificationInfoMessage case final message?)
            MaterialBanner(
              content: Text(message),
              leading: const Icon(Icons.info_outline),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: _notifications,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron cargar las notificaciones: '
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data!;
                if (notifications.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_outlined,
                            size: 44,
                            color: Color(0xFF61756C),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Aún no tienes notificaciones.',
                            style: TextStyle(
                              color: Color(0xFF17362D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: notification.read
                              ? const Color(0xFFF0F4F2)
                              : const Color(0xFFE7F5EF),
                          child: Icon(
                            _iconFor(notification.type),
                            color: const Color(0xFF07835F),
                          ),
                        ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            [
                              notification.body,
                              if (notification.createdAt case final date?)
                                _formatDate(date),
                            ].join('\n'),
                          ),
                        ),
                        isThreeLine: true,
                        trailing: notification.read
                            ? const Icon(Icons.check, color: Color(0xFF61756C))
                            : const Icon(
                                Icons.circle,
                                color: Color(0xFF07835F),
                                size: 10,
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    try {
      await widget.notificationService.markAllAsRead();
    } on FirebaseException catch (error) {
      _showMarkAllError(error.code);
    } on PlatformException catch (error) {
      _showMarkAllError(error.code);
    } on FormatException {
      _showMarkAllError('historial local inválido');
    }
  }

  void _showMarkAllError(String code) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron marcar todas como leídas ($code). Inténtalo de nuevo.',
          ),
        ),
      );
    });
  }

  static IconData _iconFor(String type) {
    return switch (type) {
      'product_registered' => Icons.add_box_outlined,
      'stock_entry' => Icons.call_received,
      'low_stock' => Icons.warning_amber_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  static String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}
