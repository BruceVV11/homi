import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/developer_notification_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';

class DeveloperNotificationsPage extends StatefulWidget {
  const DeveloperNotificationsPage({
    required this.service,
    super.key,
  });

  final DeveloperNotificationService service;

  @override
  State<DeveloperNotificationsPage> createState() =>
      _DeveloperNotificationsPageState();
}

class _DeveloperNotificationsPageState
    extends State<DeveloperNotificationsPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _category = 'update';
  String _route = 'overview';
  String _audience = 'self';
  String _priority = 'normal';
  bool _busy = false;
  String? _error;

  static const _categories = <String>[
    'update',
    'service',
    'security',
  ];
  static const _routes = <String>[
    'overview',
    'tasks',
    'routines',
    'home',
    'supplies',
    'people',
    'account',
  ];
  static const _audiences = <String>['self', 'all'];
  static const _priorities = <String>['normal', 'important'];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String _categoryLabel(String value) => switch (value) {
        'service' => 'Service / maintenance',
        'security' => 'Security',
        _ => 'Homi update',
      };

  String _routeLabel(String value) => switch (value) {
        'tasks' => 'Tasks',
        'routines' => 'Routines',
        'home' => 'Home',
        'supplies' => 'Supplies',
        'people' => 'People',
        'account' => 'Homi & account',
        _ => 'Overview',
      };

  String _audienceLabel(String value) =>
      value == 'all' ? 'All enabled Homi devices' : 'Just this account (test)';

  void _selectCategory(String value) {
    setState(() {
      _category = value;
      if (value == 'update') _priority = 'normal';
    });
  }

  Future<void> _send() async {
    if (_busy) return;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'Add both a title and message.');
      return;
    }

    if (_audience == 'all') {
      final confirmed = await showHomiConfirmSheet(
        context,
        title: 'Send to all enabled Homi devices?',
        message:
            'This is a real push notification campaign. Homi only sends it to devices that allow the selected Homi Updates or Service & Security category.',
        confirmLabel: 'Send notification',
        cancelLabel: 'Review message',
        icon: Icons.campaign_outlined,
      );
      if (!confirmed) return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.queueCampaign(
        title: title,
        body: body,
        category: _category,
        route: _route,
        audience: _audience,
        priority: _category == 'update' ? 'normal' : _priority,
      );
      if (!mounted) return;
      _titleController.clear();
      _bodyController.clear();
      await _showQueued();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('StateError: ', '')
              .replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showQueued() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: HomiColors.coral),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Notification queued',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _audience == 'all'
                    ? 'Homi will hand the broadcast to Firebase Cloud Messaging for devices subscribed to this notification category. The history below records whether the broadcast was accepted for delivery.'
                    : 'Homi will send this test directly to your enabled signed-in devices and record the direct send result below.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiColors.cream,
      appBar: AppBar(
        title: const Text('Developer notifications'),
        backgroundColor: HomiColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HomiColors.peach.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'This is the live Homi push composer. Send a test to your own account first. Broad campaigns respect each device’s Homi Updates or Service & Security preference.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Planned Homi maintenance',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyController,
              maxLength: 280,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText:
                    'Keep it useful, specific and short enough to read from the notification shade.',
              ),
            ),
            const SizedBox(height: 16),
            _ChoiceSection(
              title: 'Type',
              child: HomiChoiceGroup<String>(
                values: _categories,
                selected: _category,
                labelFor: _categoryLabel,
                onSelected: _selectCategory,
                compact: true,
              ),
            ),
            _ChoiceSection(
              title: 'Audience',
              child: HomiChoiceGroup<String>(
                values: _audiences,
                selected: _audience,
                labelFor: _audienceLabel,
                onSelected: (value) => setState(() => _audience = value),
              ),
            ),
            _ChoiceSection(
              title: 'Open when tapped',
              child: HomiChoiceGroup<String>(
                values: _routes,
                selected: _route,
                labelFor: _routeLabel,
                onSelected: (value) => setState(() => _route = value),
                compact: true,
              ),
            ),
            _ChoiceSection(
              title: 'Delivery urgency',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomiChoiceGroup<String>(
                    values: _priorities,
                    selected: _category == 'update' ? 'normal' : _priority,
                    labelFor: (value) =>
                        value == 'important' ? 'Important' : 'Normal',
                    onSelected: _category == 'update'
                        ? (_) {}
                        : (value) => setState(() => _priority = value),
                    compact: true,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _category == 'update'
                        ? 'Homi updates always use normal delivery so product news never wakes a sleeping device unnecessarily.'
                        : 'Important asks Android for faster delivery when the notice is genuinely time-sensitive. It does not bypass the user’s notification or Do Not Disturb settings.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HomiColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HomiColors.peach.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(_error!),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  _busy
                      ? 'Queueing…'
                      : (_audience == 'all'
                          ? 'Send to enabled users'
                          : 'Send test to me'),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text('Recent sends', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            StreamBuilder<List<HomiNotificationCampaign>>(
              stream: widget.service.watchRecentCampaigns(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _EmptyHistory(
                    text: 'Homi could not load notification history right now.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final campaigns = snapshot.data!;
                if (campaigns.isEmpty) {
                  return const _EmptyHistory(
                    text: 'Your developer notification sends appear here.',
                  );
                }
                return Column(
                  children: campaigns
                      .map((campaign) => _CampaignCard(campaign: campaign))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});

  final HomiNotificationCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final status = switch (campaign.status) {
      'sent' => 'Sent',
      'failed' => 'Failed',
      'sending' => 'Sending',
      _ => 'Queued',
    };
    final when = campaign.createdAt == null
        ? 'Just now'
        : DateFormat('d MMM · HH:mm').format(campaign.createdAt!.toLocal());
    final delivery = campaign.isBroadcast
        ? (campaign.status == 'sent'
            ? 'Broadcast accepted by FCM'
            : 'All enabled devices')
        : '${campaign.sentCount} direct device${campaign.sentCount == 1 ? '' : 's'} sent${campaign.failureCount > 0 ? ' · ${campaign.failureCount} failed' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: campaign.status == 'failed'
                          ? Theme.of(context).colorScheme.error
                          : HomiColors.coral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(campaign.body,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                '$when · $delivery',
                style: const TextStyle(fontSize: 11.5, color: HomiColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomiColors.border),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
