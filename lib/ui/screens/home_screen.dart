import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:focus_detector/focus_detector.dart';

import '../../models/aktivitaet.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../../services/foreground_service_handler.dart';
import '../../services/settings_service.dart';
import '../../utils/permission_helper.dart';
import '../widgets/stay_detail_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  AppLocalizations? _l10n;

  // Active Aktivitaet
  Aktivitaet? _currentAktivitaet;

  // Tracking state
  bool _trackingEnabled = false;

  // Pulse animation for GPS button when tracking is off
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Stay? _activeStay;
  SavedPlace? _activeStayPlace;
  String _trackingStatusText = '';
  // ending stay takes a while so we wait more than one interval to be safe
  int _endingStay = 0;

  // Recent visits
  List<Stay> _recentStays = [];
  Map<String, SavedPlace> _placesByUuid = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Do NOT trust the persisted flag alone — the service may have been killed.
    // Resolve the actual service state asynchronously and correct if needed.
    _checkActualTrackingState();
    _loadCurrentAktivitaet();
    _relaodStays();
  }

  Future<void> _relaodStays() async {
    await _loadActiveStay();
    await _loadRecentStays();
  }

  Future<void> _checkActualTrackingState() async {
    final serviceRunning = await FlutterForegroundTask.isRunningService;
    final storedEnabled = SettingsService.instance.trackingEnabled;

    // If the stored flag claims tracking is on but the service isn't running,
    // reset the flag so the UI reflects reality.
    if (storedEnabled && !serviceRunning) {
      SettingsService.instance.trackingEnabled = false;
    }

    if (mounted) {
      setState(() {
        _trackingEnabled = serviceRunning;
        _trackingStatusText = serviceRunning
            ? (_l10n?.trackingRunning ?? '')
            : (_l10n?.trackingDisabled ?? '');
      });
      if (serviceRunning) {
        _pulseController.stop();
      } else {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onServiceData(Map data) {
    final cmd = data['cmd'] as String?;
    if (cmd == FgTaskKeys.position) {
      if (mounted) setState(() {});
    } else if (cmd == FgTaskKeys.trackingStatus) {
      final statusName = data['status'] as String? ?? 'idle';
      final placeName = data['place_name'] as String?;
      final address = data['address'] as String?;
      String text;
      switch (statusName) {
        case 'haltAtKnown':
          text =
              _l10n?.trackingStatusHaltKnown(
                _cutText(placeName) ?? (_l10n?.unknownPlace ?? ''),
              ) ??
              '';
        case 'haltAtUnknown':
          text = address != null
              ? (_l10n?.trackingStatusHaltUnknownAddress(_cutText(address)!) ??
                    '')
              : (_l10n?.trackingStatusHalt ?? '');
        case 'detectingHalt':
          text = _l10n?.trackingStatusDetecting ?? '';
        case 'moving':
          text = _l10n?.trackingStatusMoving ?? '';
        default:
          text = _l10n?.trackingActive ?? '';
      }
      _relaodStays();
      if (mounted) {
        setState(() {
          _trackingStatusText = text;
          _endingStay--;
        });
      }
    }
  }

  String? _cutText(String? text, {int maxLength = 20}) {
    if (text == null) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }

  Future<void> _loadRecentStays() async {
    final stays = await DatabaseService.instance.loadRecentCompletedStays();
    final allPlaces = await DatabaseService.instance.loadAllPlaces();
    final byUuid = {for (final p in allPlaces) p.uuid: p};
    if (mounted) {
      setState(() {
        _recentStays = stays;
        _placesByUuid = byUuid;
      });
    }
  }

  Future<void> _loadCurrentAktivitaet() async {
    final uuid = SettingsService.instance.activeAktivitaetUuid;
    if (uuid == null) return;
    final a = await DatabaseService.instance.loadAktivitaet(uuid);
    if (mounted) setState(() => _currentAktivitaet = a);
  }

  Future<void> _loadActiveStay() async {
    final stay = await DatabaseService.instance.loadActiveStay();
    SavedPlace? place;
    if (stay?.placeUuid != null) {
      final places = await DatabaseService.instance.loadAllPlaces();
      place = places.where((p) => p.uuid == stay!.placeUuid).firstOrNull;
    }
    if (mounted) {
      setState(() {
        _activeStay = stay;
        _activeStayPlace = place;
      });
    }
  }

  /// Checks battery-optimization status and requests exemption if needed.
  /// Returns false when the user must first grant the exemption manually and
  /// the service start should be aborted.
  Future<bool> _ensureBatteryOptimizationExempt() async {
    final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (ignoring) return true;

    // Ask Android to whitelist this app via the standard system dialog.
    // Requires REQUEST_IGNORE_BATTERY_OPTIMIZATIONS in the manifest.
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();

    // Re-check: on some devices (e.g. Samsung) the API returns a failure even
    // though the user just tapped "Allow" in the system dialog. A second read
    // of the flag gives the correct result.
    final nowIgnoring =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (nowIgnoring) return true;

    // If the direct request failed (e.g. Samsung blocks it), open the
    // battery settings page and tell the user what to do.
    if (!mounted) return false;
    final l10n = _l10n ?? AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.batteryOptTitle),
        content: Text(l10n.batteryOptContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
            },
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _toggleTracking(bool value) async {
    if (value) {
      // All three permissions are required for the foreground service:
      // location (fine), background location, and POST_NOTIFICATIONS (Android 13+).
      final hasPerms = await PermissionHelper.instance.hasAllPermissions();
      if (!hasPerms) {
        await PermissionHelper.instance.requestLocationPermission();
        await PermissionHelper.instance.requestBackgroundLocationPermission();
        await PermissionHelper.instance.requestNotificationPermission();
      }
      final locationGranted = await PermissionHelper.instance
          .hasLocationPermission();
      if (!locationGranted) return;

      final batteryOk = await _ensureBatteryOptimizationExempt();
      if (!batteryOk) return;
    }

    setState(() {
      _trackingEnabled = value;
      _trackingStatusText = value
          ? (_l10n?.trackingCollecting ?? '')
          : (_l10n?.trackingDisabled ?? '');
    });
    if (value) {
      _pulseController.stop();
    } else {
      _pulseController.repeat(reverse: true);
    }
    SettingsService.instance.trackingEnabled = value;

    if (value) {
      final result = await ForegroundServiceManager.startService(
        notificationText:
            _l10n?.trackingNotificationText ?? 'Automatisches Tracking aktiv',
      );
      if (result is ServiceRequestFailure) {
        debugPrint('[Tracking] startService FAILED: ${result.error}');
        // Revert optimistic UI state on failure.
        if (mounted) {
          setState(() => _trackingEnabled = false);
          SettingsService.instance.trackingEnabled = false;
        }
        return;
      }
      debugPrint('[Tracking] startService OK');
    }
    ForegroundServiceManager.sendSetTracking(value);

    if (!value) {
      try {
        await ForegroundServiceManager.stopService();
      } catch (_) {
        // Ignore errors when stopping the service
      }
    }
  }

  Future<void> _confirmToggleTracking() async {
    final l10n = AppLocalizations.of(context)!;
    final newValue = !_trackingEnabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          newValue ? l10n.trackingActivateTitle : l10n.trackingDeactivateTitle,
        ),
        content: Text(
          newValue
              ? l10n.trackingActivateContent
              : l10n.trackingDeactivateContent,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newValue ? l10n.activate : l10n.deactivate),
          ),
        ],
      ),
    );
    if (confirmed == true) await _toggleTracking(newValue);
  }

  @override
  Widget build(BuildContext context) {
    _l10n = AppLocalizations.of(context)!;
    final l10n = _l10n!;
    // Refresh status text if it's empty (first build after init)
    if (_trackingStatusText.isEmpty) {
      _trackingStatusText = _trackingEnabled
          ? l10n.trackingRunning
          : l10n.trackingDisabled;
    }
    return FocusDetector(
      onFocusGained: () {
        ForegroundServiceManager.addDataListener(_onServiceData);
        _loadActiveStay().then((_) {
          if (mounted) {
            _loadRecentStays().then((_) {
              if (mounted) {
                setState(() {}); // Refresh to show tracking points if enabled.
              }
            });
          }
        });
      },
      onFocusLost: () =>
          ForegroundServiceManager.removeDataListener(_onServiceData),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = _trackingEnabled ? 1.0 : _pulseAnimation.value;
                return Transform.scale(scale: scale, child: child);
              },
              child: IconButton(
                icon: Icon(
                  _trackingEnabled
                      ? Icons.my_location
                      : Icons.location_disabled,
                  color: _trackingEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                tooltip: _trackingEnabled
                    ? l10n.trackingActiveTooltip
                    : l10n.trackingInactiveTooltip,
                onPressed: _confirmToggleTracking,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Active Aktivitaet banner ───────────────────────────
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: InkWell(
                onTap: () async {
                  await Navigator.pushNamed(context, '/settings');
                  _loadCurrentAktivitaet();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentAktivitaet?.name ?? 'Aktivität laden…',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 7, width: 6),
            // Tracking status row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.sensors,
                    size: 16,
                    color: _trackingEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _trackingStatusText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _trackingEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            // ── Aktueller Aufenthalt ───────────────────────────────
            if (_activeStay != null) ...[
              Card(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                elevation: 3,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => StayDetailSheet(
                        stay: _activeStay!,
                        onUpdated: _loadActiveStay,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _activeStayPlace != null
                            ? CircleAvatar(
                                backgroundColor: _activeStayPlace!
                                    .placeType
                                    .dotColor
                                    .withValues(alpha: 0.2),
                                child: Icon(
                                  _activeStayPlace!.placeType.icon,
                                  color: _activeStayPlace!.placeType.dotColor,
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.15),
                                child: Icon(
                                  Icons.location_on,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _activeStayPlace?.name ??
                                    _activeStay!.address ??
                                    l10n.unknownPlace,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Builder(
                                builder: (ctx) {
                                  final dur = _activeStay!.duration;
                                  final h = dur.inHours;
                                  final m = dur.inMinutes % 60;
                                  return Text(
                                    h > 0
                                        ? 'Seit ${h}h ${m}min'
                                        : 'Seit ${m}min',
                                    style: Theme.of(ctx).textTheme.bodySmall,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                  icon: _endingStay > 0
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.call_split, size: 18),
                  label: Text(
                    _endingStay > 0 ? l10n.endStayEnding : l10n.endStayNow,
                  ),
                  onPressed: _endingStay > 0
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.endStayTitle),
                              content: Text(l10n.endStayContent),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n.cancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(l10n.end),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          setState(() => _endingStay = 2);
                          ForegroundServiceManager.sendForceEndStay();
                          await Future<void>.delayed(
                            const Duration(milliseconds: 300),
                          );
                          await _loadActiveStay();
                          await _loadRecentStays();
                        },
                ),
              ),
            ],
            const Divider(height: 1),
            // ── Letzte Besuche ─────────────────────────────────────
            Expanded(
              child: _recentStays.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noVisitsYet,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRecentStays,
                      child: ListView.builder(
                        itemCount: _recentStays.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                l10n.recentVisits,
                                style: Theme.of(ctx).textTheme.titleSmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            );
                          }
                          final stay = _recentStays[i - 1];
                          final place = stay.placeUuid != null
                              ? _placesByUuid[stay.placeUuid]
                              : null;
                          final name =
                              place?.name ?? stay.address ?? l10n.unknownPlace;
                          final dur = stay.duration;
                          final h = dur.inHours;
                          final m = dur.inMinutes % 60;
                          final durText = h > 0 ? '${h}h ${m}min' : '${m}min';
                          final start = DateTime.fromMillisecondsSinceEpoch(
                            stay.startTime,
                          );
                          final dateText =
                              '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}.${start.year}  '
                              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                          return ListTile(
                            dense: true,
                            leading: place != null
                                ? Icon(
                                    place.placeType.icon,
                                    color: place.placeType.dotColor,
                                    size: 22,
                                  )
                                : const Icon(
                                    Icons.location_on,
                                    size: 22,
                                    color: Colors.grey,
                                  ),
                            title: Text(name),
                            subtitle: Text('$dateText · $durText'),
                            onTap: () {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => StayDetailSheet(
                                  stay: stay,
                                  onUpdated: _loadRecentStays,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
