import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MuzikYokApp());

class BrandColors {
  static const ink = Color(0xFF142019);
  static const black = Color(0xFF0B110D);
  static const darkSurface = Color(0xFF18231B);
  static const green = Color(0xFF47E37F);
  static const deepGreen = Color(0xFF197F42);
  static const lightCanvas = Color(0xFFF4F8F3);
  static const softGreen = Color(0xFFDDF5E4);
  static const darkText = Color(0xFFF3FFF5);
}

class MuzikYokApp extends StatefulWidget {
  const MuzikYokApp({super.key});

  @override
  State<MuzikYokApp> createState() => _MuzikYokAppState();
}

class _MuzikYokAppState extends State<MuzikYokApp> {
  static const settings = MethodChannel('muzik_yok/settings');
  bool darkMode = true;

  @override
  void initState() {
    super.initState();
    loadAppearance();
  }

  Future<void> loadAppearance() async {
    if (!Platform.isIOS) return;
    try {
      final saved = await settings.invokeMethod<bool>('getDarkMode');
      if (mounted && saved != null) setState(() => darkMode = saved);
    } on PlatformException {
      // Varsayılan koyu tema kullanılabilir.
    }
  }

  Future<void> toggleAppearance() async {
    final next = !darkMode;
    setState(() => darkMode = next);
    if (!Platform.isIOS) return;
    try {
      await settings.invokeMethod<void>('setDarkMode', next);
    } on PlatformException {
      // Tema bu oturumda yine değişir.
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Müzik Yok',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: BrandColors.deepGreen,
        primary: BrandColors.deepGreen,
        surface: BrandColors.lightCanvas,
      ),
      scaffoldBackgroundColor: BrandColors.lightCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.lightCanvas,
        foregroundColor: BrandColors.ink,
        centerTitle: false,
      ),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: BrandColors.green,
        brightness: Brightness.dark,
        primary: BrandColors.green,
        surface: BrandColors.darkSurface,
      ),
      scaffoldBackgroundColor: BrandColors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.black,
        foregroundColor: BrandColors.darkText,
        centerTitle: false,
      ),
    ),
    themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
    home: ThinkingScreen(darkMode: darkMode, onToggleTheme: toggleAppearance),
  );
}

class ThinkingScreen extends StatefulWidget {
  const ThinkingScreen({super.key, this.darkMode = false, this.onToggleTheme});
  final bool darkMode;
  final VoidCallback? onToggleTheme;
  @override
  State<ThinkingScreen> createState() => _ThinkingScreenState();
}

class _ThinkingScreenState extends State<ThinkingScreen>
    with WidgetsBindingObserver {
  static const monitor = MethodChannel('muzik_yok/ambient_music');
  static const screenTime = MethodChannel('muzik_yok/screen_time');
  final apps = <String>['Müzik', 'Video', 'Sosyal medya', 'Oyunlar'];
  final selected = <String>{'Müzik', 'Video'};
  int minutes = 30;
  int remaining = 0;
  bool active = false;
  bool nativeMonitoring = false;
  bool shieldActive = false;
  bool screenTimeAvailable = true;
  int suppressedSeconds = 0;
  int selectedCount = 0;
  int lastSeenDetection = 0;
  int sessionMinutes = 30;
  String sessionIntention = '';
  bool completionHandled = false;
  bool exiting = false;
  bool musicDialogOpen = false;
  final songMessage = ValueNotifier<String>('');
  List<Map<String, dynamic>> recentSessions = [];
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isIOS) restoreScreenTime();
    if (Platform.isIOS) loadRecentSessions();
    if (Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) => syncSessionStatus());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isIOS) {
      syncSessionStatus();
    }
  }

  Future<bool> syncSessionStatus() async {
    if (!Platform.isIOS) return false;
    try {
      final session = await monitor.invokeMapMethod<String, dynamic>(
        'sessionStatus',
      );
      if (!mounted || session == null) return false;
      sessionIntention = session['intention'] as String? ?? '';
      sessionMinutes = session['minutes'] as int? ?? 30;
      final isCompleted = session['completed'] as bool? ?? false;
      if (isCompleted) {
        timer?.cancel();
        if (nativeMonitoring) {
          await monitor.invokeMethod<void>('stop');
          nativeMonitoring = false;
        }
        if (!mounted) return true;
        setState(() {
          active = false;
          remaining = 0;
        });
        await onSessionCompleted();
        return true;
      }
      final seconds = session['remainingSeconds'] as int? ?? 0;
      if (!active) {
        setState(() {
          active = true;
          remaining = seconds;
        });
        beginTicker();
      } else {
        setState(() => remaining = seconds);
      }
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> loadRecentSessions() async {
    try {
      final items = await monitor.invokeListMethod<dynamic>('recentSessions');
      if (!mounted) return;
      setState(
        () => recentSessions =
            items
                ?.whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList() ??
            [],
      );
    } on PlatformException {
      // Diğer platformlarda oturum geçmişi henüz yoktur.
    }
  }

  Future<void> restoreScreenTime() async {
    try {
      final status = await screenTime.invokeMapMethod<String, dynamic>(
        'status',
      );
      if (!mounted || status == null) return;
      setState(() {
        screenTimeAvailable = status['available'] as bool? ?? false;
        selectedCount = status['selectedCount'] as int? ?? 0;
        shieldActive = status['shieldActive'] as bool? ?? false;
        if (shieldActive) {
          active = true;
          remaining = status['remainingSeconds'] as int? ?? 0;
        }
      });
      if (shieldActive) beginTicker();
    } on PlatformException {
      // Ekran Süresi yetkisi bu cihazda kullanılamayabilir.
    }
  }

  Future<void> pickApplications() async {
    try {
      final status = await screenTime.invokeMapMethod<String, dynamic>(
        'pickApplications',
      );
      if (!mounted || status == null) return;
      setState(() => selectedCount = status['selectedCount'] as int? ?? 0);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Uygulama seçimi açılamadı.')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    if (nativeMonitoring) monitor.invokeMethod<void>('stop');
    songMessage.dispose();
    super.dispose();
  }

  String get clock {
    final hours = remaining ~/ 3600;
    final minutesPart = (remaining % 3600) ~/ 60;
    final secondsPart = remaining % 60;
    if (hours > 0) {
      return '$hours:${minutesPart.toString().padLeft(2, '0')}:${secondsPart.toString().padLeft(2, '0')}';
    }
    return '${minutesPart.toString().padLeft(2, '0')}:${secondsPart.toString().padLeft(2, '0')}';
  }

  String durationLabel(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final rest = totalMinutes % 60;
    if (hours == 0) return '$rest dk';
    return rest == 0 ? '$hours sa' : '$hours sa $rest dk';
  }

  String songDescription(Map<String, dynamic> status) {
    final title = status['songTitle'] as String? ?? '';
    final artist = status['songArtist'] as String? ?? '';
    if (title.isNotEmpty) {
      return artist.isEmpty ? 'Çalan: $title' : 'Çalan: $title — $artist';
    }
    switch (status['songState']) {
      case 'searching':
        return 'Parça tanınıyor…';
      case 'unavailable':
        return 'Parça adı bulunamadı.';
      case 'error':
        return 'Parça tanıma şu anda kullanılamıyor.';
      default:
        return '';
    }
  }

  bool get usesAppBlock =>
      Platform.isIOS && screenTimeAvailable && minutes >= 15;

  Future<void> chooseCustomDuration() async {
    var hoursInput = '${minutes ~/ 60}';
    var minutesInput = '${minutes % 60}';
    String? error;
    final chosen = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Özel süre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('customHours'),
                      initialValue: hoursInput,
                      onChanged: (value) => hoursInput = value,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Saat'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('customMinutes'),
                      initialValue: minutesInput,
                      onChanged: (value) => minutesInput = value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Dakika'),
                    ),
                  ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final hours = int.tryParse(
                  hoursInput.isEmpty ? '0' : hoursInput,
                );
                final minutePart = int.tryParse(
                  minutesInput.isEmpty ? '0' : minutesInput,
                );
                const maxSafeMinutes = 9223372036854775807 ~/ 60000;
                if (hours == null ||
                    minutePart == null ||
                    minutePart > 59 ||
                    hours > (maxSafeMinutes - minutePart) ~/ 60 ||
                    hours * 60 + minutePart == 0) {
                  updateDialog(
                    () => error = 'Geçerli bir saat ve 0–59 dakika gir.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, hours * 60 + minutePart);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => minutes = chosen);
  }

  Future<void> chooseDuration() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Süre seç', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final value in [1, 5, 15, 30, 45, 60])
                    ChoiceChip(
                      label: Text('$value dk'),
                      selected: minutes == value,
                      onSelected: (_) => Navigator.pop(sheetContext, value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                key: const Key('customDuration'),
                onPressed: () => Navigator.pop(sheetContext, -1),
                icon: const Icon(Icons.add),
                label: const Text('Özel süre'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    if (chosen == -1) {
      await chooseCustomDuration();
    } else {
      setState(() => minutes = chosen);
    }
  }

  Future<void> openNotes() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (notesContext, updateNotes) => Scaffold(
            appBar: AppBar(
              title: const Text('Notlarım'),
              actions: [
                if (savedNotes.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await clearSessions();
                      if (notesContext.mounted) updateNotes(() {});
                    },
                    child: const Text('Tümünü sil'),
                  ),
              ],
            ),
            body: savedNotes.isEmpty
                ? const Center(child: Text('Henüz not yok.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: savedNotes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = savedNotes[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        title: Text(item['reflection'] as String),
                        subtitle: Text(
                          '${durationLabel(item['minutes'] as int? ?? 0)} · ${sessionDate(item)}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Notu sil',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await deleteNote(item);
                            if (notesContext.mounted) updateNotes(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  String sessionDate(Map<String, dynamic> item) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      item['dateMs'] as int? ?? 0,
    );
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  List<Map<String, dynamic>> get savedNotes => recentSessions
      .where(
        (item) => (item['reflection'] as String?)?.trim().isNotEmpty == true,
      )
      .toList();

  Future<void> clearSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notları sil?'),
        content: const Text(
          'Kaydettiğin düşünme notları bu iPhone’dan kaldırılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await monitor.invokeMethod<void>('clearSessions');
      if (mounted) setState(() => recentSessions = []);
    } on PlatformException {
      // Silme işlemi başarısız olursa mevcut liste korunur.
    }
  }

  Future<void> deleteNote(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notu sil?'),
        content: const Text('Bu not iPhone’daki geçmişinden kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final deleted = await monitor.invokeMethod<bool>('deleteSession', item);
      if (deleted != true) throw StateError('Not bulunamadı.');
      await loadRecentSessions();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not silinemedi. Tekrar deneyebilirsin.')),
      );
    }
  }

  Future<void> addNote() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ReflectionDialog(
        intention: '',
        title: 'Not ekle',
        allowSkip: false,
        onSave: (reflection) async {
          final saved = await monitor.invokeMapMethod<String, dynamic>(
            'saveNote',
            {'reflection': reflection},
          );
          if (saved == null) throw StateError('Not kaydedilemedi.');
          if (!mounted) return;
          setState(() => recentSessions.insert(0, saved));
        },
      ),
    );
  }

  Future<void> exitSession() async {
    if (exiting) return;
    setState(() => exiting = true);
    try {
      if (Platform.isIOS && screenTimeAvailable) {
        await screenTime.invokeMapMethod<String, dynamic>('stopShield');
      }
      if (Platform.isIOS) await monitor.invokeMethod<void>('cancelSession');
      if (nativeMonitoring) await monitor.invokeMethod<void>('stop');
      timer?.cancel();
      if (!mounted) return;
      setState(() {
        active = false;
        shieldActive = false;
        nativeMonitoring = false;
        remaining = 0;
        completionHandled = true;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Oturum kapatılamadı.')),
      );
    } finally {
      if (mounted) setState(() => exiting = false);
    }
  }

  Future<void> start() async {
    var notificationsAuthorized = true;
    if (usesAppBlock && selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce engellenecek uygulamaları seç.')),
      );
      return;
    }
    if (Platform.isIOS) {
      try {
        final monitorStatus = await monitor.invokeMapMethod<String, dynamic>(
          'start',
          {'durationSeconds': minutes * 60},
        );
        notificationsAuthorized =
            monitorStatus?['notificationsAuthorized'] as bool? ?? true;
        nativeMonitoring = true;
      } on PlatformException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Mikrofon başlatılamadı.')),
        );
        return;
      }
    }
    if (usesAppBlock) {
      try {
        final status = await screenTime.invokeMapMethod<String, dynamic>(
          'startShield',
          {'durationSeconds': minutes * 60},
        );
        shieldActive = status?['shieldActive'] as bool? ?? false;
      } on PlatformException catch (error) {
        if (nativeMonitoring) {
          await monitor.invokeMethod<void>('stop');
          nativeMonitoring = false;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Uygulama engeli başlatılamadı.'),
          ),
        );
        return;
      }
    }
    if (Platform.isIOS) {
      try {
        await monitor.invokeMethod<void>('beginSession', {
          'durationSeconds': minutes * 60,
          'minutes': minutes,
          'intention': '',
        });
      } on PlatformException catch (error) {
        if (nativeMonitoring) await monitor.invokeMethod<void>('stop');
        nativeMonitoring = false;
        if (shieldActive) {
          await screenTime.invokeMapMethod<String, dynamic>('stopShield');
          shieldActive = false;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Oturum başlatılamadı.')),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      remaining = minutes * 60;
      active = true;
      lastSeenDetection = 0;
      sessionMinutes = minutes;
      sessionIntention = '';
      completionHandled = false;
    });
    songMessage.value = '';
    beginTicker();
    if (Platform.isIOS && !notificationsAuthorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kilit ekranı uyarıları için Ayarlar > Bildirimler > Müzik Yok bölümünden bildirimlere izin ver.',
          ),
        ),
      );
    }
  }

  void beginTicker() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (await syncSessionStatus()) return;
      if (Platform.isIOS && shieldActive) {
        try {
          final shield = await screenTime.invokeMapMethod<String, dynamic>(
            'status',
          );
          if (!mounted) return;
          setState(() {
            shieldActive = shield?['shieldActive'] as bool? ?? false;
            remaining = shield?['remainingSeconds'] as int? ?? remaining;
            if (!shieldActive) active = false;
          });
          if (!shieldActive) {
            if (nativeMonitoring) await monitor.invokeMethod<void>('stop');
            nativeMonitoring = false;
            timer.cancel();
            onSessionCompleted();
            return;
          }
        } on PlatformException {
          // Zamanlayıcı sonraki turda yeniden sorgular.
        }
      }
      if (nativeMonitoring) {
        try {
          final status = await monitor.invokeMapMethod<String, dynamic>(
            'status',
          );
          if (!mounted || status == null) return;
          songMessage.value = songDescription(status);
          final detected = status['lastDetectionMs'] as int? ?? 0;
          if (detected > lastSeenDetection) {
            lastSeenDetection = detected;
            if (status['lastDetectionNotifiedInBackground'] != true) {
              musicAlert();
            }
          }
          setState(() {
            suppressedSeconds = status['suppressedSeconds'] as int? ?? 0;
            if (!shieldActive) {
              remaining = status['remainingSeconds'] as int? ?? 0;
            }
            if (!shieldActive) active = status['running'] as bool? ?? false;
          });
          if (!active) {
            nativeMonitoring = false;
            timer.cancel();
            if (status['completed'] == true) onSessionCompleted();
          }
        } on PlatformException {
          if (!shieldActive) setState(() => active = false);
          nativeMonitoring = false;
          if (!shieldActive) timer.cancel();
        }
        return;
      }
      if (!shieldActive) {
        setState(() {
          remaining--;
          if (remaining <= 0) {
            active = false;
            timer.cancel();
            onSessionCompleted();
          }
        });
      }
    });
  }

  Future<void> onSessionCompleted() async {
    if (completionHandled || !Platform.isIOS || !mounted) return;
    completionHandled = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReflectionDialog(
        intention: sessionIntention,
        onSave: (reflection) async {
          final saved = await monitor.invokeMapMethod<String, dynamic>(
            'saveSession',
            {
              'intention': sessionIntention,
              'reflection': reflection,
              'minutes': sessionMinutes,
            },
          );
          if (saved == null) throw StateError('Not kaydedilemedi.');
          if (!mounted) return;
          setState(() => recentSessions.insert(0, saved));
        },
      ),
    );
  }

  void permissions() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Başlamadan önce',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (Platform.isIOS) ...[
            const PermissionInfo(
              Icons.mic_none,
              'Mikrofon',
              'Çevredeki müziği algılamak ve çalan parçayı tanımak için.',
            ),
            const PermissionInfo(
              Icons.notifications_none,
              'Bildirim',
              'Ekran kilitliyken müzik uyarısı göndermek için.',
            ),
          ],
          if (usesAppBlock)
            const PermissionInfo(
              Icons.lock_outline,
              'Ekran Süresi',
              'Seçtiğin uygulamaları oturum bitene veya sen çıkana kadar engellemek için.',
            ),
          const SizedBox(height: 12),
          Text(
            usesAppBlock
                ? 'Ses kaydedilmez. Parça tanıma için ses imzası Shazam kataloğunda aranır. Çık düğmesi engeli hemen kaldırır.'
                : 'Bu sürede uygulama engeli kullanılmaz. Ses kaydedilmez; parça tanıma için ses imzası Shazam kataloğunda aranır.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await start();
              },
              child: const Text('Düşünme Modu’nu başlat'),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> markFalsePositive(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    if (!Platform.isIOS) return;
    try {
      final status = await monitor.invokeMapMethod<String, dynamic>(
        'markFalsePositive',
      );
      if (!mounted || status == null) return;
      setState(() {
        suppressedSeconds = status['suppressedSeconds'] as int? ?? 120;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yanlış algılama kaydedildi. Uyarılar 2 dakika duraklatıldı.',
          ),
        ),
      );
    } on PlatformException {
      // Kullanıcıya yeni bir uyarı gösterilmez.
    }
  }

  Future<void> musicAlert() async {
    if (musicDialogOpen || !mounted) return;
    musicDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.graphic_eq, size: 36),
          title: const Text('Yakında müzik olabilir'),
          content: ValueListenableBuilder<String>(
            valueListenable: songMessage,
            builder: (_, song, _) => Text(
              song.isEmpty
                  ? 'Daha sessiz bir yere geçmek ister misin?'
                  : '$song\n\nDaha sessiz bir yere geçmek ister misin?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => markFalsePositive(dialogContext),
              child: const Text('Yanlış algılama'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } finally {
      musicDialogOpen = false;
    }
  }

  Widget activeScreen(BuildContext context) => Scaffold(
    backgroundColor: widget.darkMode
        ? BrandColors.black
        : BrandColors.lightCanvas,
    body: Container(
      color: widget.darkMode ? BrandColors.black : BrandColors.lightCanvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Text(
                clock,
                key: const Key('thinkingClock'),
                style: TextStyle(
                  color: widget.darkMode
                      ? BrandColors.darkText
                      : BrandColors.ink,
                  fontSize: 76,
                  fontWeight: FontWeight.w300,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: songMessage,
                builder: (_, song, _) => song.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        song,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.darkMode
                              ? const Color(0xFFB7CDBB)
                              : BrandColors.ink,
                          fontSize: 16,
                        ),
                      ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: addNote,
                  icon: const Icon(Icons.add),
                  label: const Text('Not ekle'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: BrandColors.green,
                    foregroundColor: BrandColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: exiting ? null : exitSession,
                  style: TextButton.styleFrom(
                    foregroundColor: widget.darkMode
                        ? BrandColors.darkText
                        : BrandColors.ink,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(exiting ? 'Çıkılıyor...' : 'Çık'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => active
      ? activeScreen(context)
      : Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CustomPaint(
                    painter: BrandMarkPainter(darkMode: widget.darkMode),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'müzik yok',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: widget.darkMode ? 'Açık moda geç' : 'Koyu moda geç',
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  widget.darkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'DÜŞÜNME SÜRESİ',
                        style: TextStyle(
                          color: widget.darkMode
                              ? BrandColors.green
                              : BrandColors.deepGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        key: const Key('durationPicker'),
                        onTap: chooseDuration,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              durationLabel(minutes),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 68,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: chooseDuration,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Süreyi değiştir'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 64),
                if (Platform.isIOS && minutes >= 15)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Uygulama sınırı'),
                    subtitle: Text(
                      screenTimeAvailable
                          ? selectedCount == 0
                                ? 'Uygulama seç'
                                : '$selectedCount uygulama seçili'
                          : 'Bu iPhone’da kullanılamıyor',
                    ),
                    trailing: screenTimeAvailable
                        ? const Icon(Icons.chevron_right)
                        : null,
                    onTap: screenTimeAvailable ? pickApplications : null,
                  ),
                if (!Platform.isIOS && minutes >= 15)
                  ...apps.map(
                    (app) => CheckboxListTile(
                      title: Text(app),
                      value: selected.contains(app),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          selected.add(app);
                        } else {
                          selected.remove(app);
                        }
                      }),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: permissions,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Başlat'),
                ),
                if (Platform.isIOS && savedNotes.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notes_outlined),
                    title: const Text('Notlarım'),
                    subtitle: Text('${savedNotes.length} not'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: openNotes,
                  ),
                ],
              ],
            ),
          ),
        );
}

class PermissionInfo extends StatelessWidget {
  const PermissionInfo(this.icon, this.title, this.description, {super.key});
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(description),
            ],
          ),
        ),
      ],
    ),
  );
}

class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({this.darkMode = true});
  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(side);

    final note = Paint()
      ..color = darkMode ? BrandColors.darkText : BrandColors.ink;
    canvas.drawOval(const Rect.fromLTWH(0.327, 0.600, 0.273, 0.161), note);

    final noteStroke = Paint()
      ..color = darkMode ? BrandColors.darkText : BrandColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.076
      ..strokeCap = StrokeCap.round;
    final stem = Path()
      ..moveTo(0.574, 0.673)
      ..lineTo(0.574, 0.272)
      ..cubicTo(0.708, 0.282, 0.774, 0.360, 0.762, 0.451);
    canvas.drawPath(stem, noteStroke);

    final mute = Paint()
      ..color = darkMode ? BrandColors.green : BrandColors.deepGreen
      ..strokeWidth = 0.072
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(0.266, 0.253),
      const Offset(0.746, 0.746),
      mute,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BrandMarkPainter oldDelegate) =>
      oldDelegate.darkMode != darkMode;
}

class ReflectionDialog extends StatefulWidget {
  const ReflectionDialog({
    super.key,
    required this.intention,
    required this.onSave,
    this.title = 'Düşünme süren tamamlandı',
    this.allowSkip = true,
  });
  final String intention;
  final Future<void> Function(String reflection) onSave;
  final String title;
  final bool allowSkip;

  @override
  State<ReflectionDialog> createState() => _ReflectionDialogState();
}

class _ReflectionDialogState extends State<ReflectionDialog> {
  final controller = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save(String text) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Not kaydedilemedi. Tekrar deneyebilirsin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.intention.isNotEmpty) Text('Konun: ${widget.intention}'),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Aklına ne geldi?',
            hintText: 'İstersen kısa bir not bırak',
            border: OutlineInputBorder(),
          ),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      if (widget.allowSkip)
        TextButton(
          onPressed: saving ? null : () => save(''),
          child: const Text('Atla'),
        ),
      if (!widget.allowSkip)
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      FilledButton(
        onPressed:
            saving || (!widget.allowSkip && controller.text.trim().isEmpty)
            ? null
            : () => save(controller.text.trim()),
        child: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
      ),
    ],
  );
}
