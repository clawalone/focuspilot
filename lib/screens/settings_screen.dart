import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/permission_service.dart';
import '../services/database_service.dart';
import '../main.dart'; // For themeNotifier

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsService _settingsService;
  final PermissionService _permissionService = PermissionService();
  final DatabaseService _databaseService = DatabaseService.instance;

  bool _isLoading = true;
  String _appVersion = '';

  // Settings State
  late ThemeMode _themeMode;
  late int _focusDuration;
  late int _dailyGoal;
  late bool _autoBreak;

  // Permissions State
  bool _usagePermission = false;
  bool _overlayPermission = false;
  bool _dndPermission = false; // Note: DND check is tricky on some Androids

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    _settingsService = Provider.of<SettingsService>(context, listen: false);
    final packageInfo = await PackageInfo.fromPlatform();

    // Check permissions
    final usage = await _permissionService.checkUsagePermission();
    final overlay = await _permissionService.checkOverlayPermission();

    if (mounted) {
      setState(() {
        _themeMode = _settingsService.getThemeMode();
        _focusDuration = _settingsService.getFocusDuration();
        _dailyGoal = _settingsService.getDailyGoal();
        _autoBreak = _settingsService.getAutoBreak();
        _appVersion = packageInfo.version;
        _usagePermission = usage;
        _overlayPermission = overlay;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await _settingsService.setThemeMode(mode);
    themeNotifier.value = mode;
  }

  Future<void> _updateFocusDuration(int minutes) async {
    setState(() => _focusDuration = minutes);
    await _settingsService.setFocusDuration(minutes);
  }

  Future<void> _updateDailyGoal(int minutes) async {
    setState(() => _dailyGoal = minutes);
    await _settingsService.setDailyGoal(minutes);
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text(
          'This will permanently delete all your focus sessions. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.clearAllSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                'Settings',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Appearance'),
                  _buildCard([_buildThemeSelector()]),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Focus'),
                  _buildCard([
                    _buildDurationTile(
                      'Default Duration',
                      '$_focusDuration minutes',
                      (val) => _updateFocusDuration(val.toInt()),
                      min: 5,
                      max: 120,
                      value: _focusDuration.toDouble(),
                      divisions: 23,
                    ),
                    const Divider(height: 1),
                    _buildDurationTile(
                      'Daily Goal',
                      '${(_dailyGoal / 60).toStringAsFixed(1)} hours',
                      (val) => _updateDailyGoal(val.toInt()),
                      min: 30,
                      max: 480, // 8 hours
                      value: _dailyGoal.toDouble(),
                      divisions: 15,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Auto-start Break'),
                      subtitle: const Text(
                        'Start break timer automatically after focus',
                      ),
                      value: _autoBreak,
                      onChanged: (val) async {
                        setState(() => _autoBreak = val);
                        await _settingsService.setAutoBreak(val);
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Permissions'),
                  _buildCard([
                    _buildPermissionTile(
                      'Usage Access',
                      'Required to detect running apps',
                      _usagePermission,
                      () async {
                        await _permissionService.requestUsagePermission();
                        // Refresh state
                        final granted = await _permissionService
                            .checkUsagePermission();
                        setState(() => _usagePermission = granted);
                      },
                    ),
                    const Divider(height: 1),
                    _buildPermissionTile(
                      'Overlay Permission',
                      'Required to block apps effectively',
                      _overlayPermission,
                      () async {
                        await _permissionService.requestOverlayPermission();
                        final granted = await _permissionService
                            .checkOverlayPermission();
                        setState(() => _overlayPermission = granted);
                      },
                    ),
                    const Divider(height: 1),
                    _buildPermissionTile(
                      'Do Not Disturb',
                      'Required to silence notifications',
                      _dndPermission,
                      () async {
                        // Placeholder for DND permission request/check
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Data'),
                  _buildCard([
                    ListTile(
                      title: const Text(
                        'Clear History',
                        style: TextStyle(color: Colors.red),
                      ),
                      leading: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      onTap: _clearHistory,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  _buildSectionHeader('About'),
                  _buildCard([
                    ListTile(
                      title: const Text('Version'),
                      trailing: Text(
                        _appVersion,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildThemeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Theme', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildThemeOption(
                ThemeMode.system,
                'System',
                Icons.brightness_auto,
              ),
              const SizedBox(width: 12),
              _buildThemeOption(
                ThemeMode.light,
                'Light',
                Icons.wb_sunny_rounded,
              ),
              const SizedBox(width: 12),
              _buildThemeOption(ThemeMode.dark, 'Dark', Icons.nightlight_round),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(ThemeMode mode, String label, IconData icon) {
    final isSelected = _themeMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => _updateTheme(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : Colors.grey,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationTile(
    String title,
    String valueLabel,
    ValueChanged<double> onChanged, {
    required double min,
    required double max,
    required double value,
    required int divisions,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              Text(
                valueLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(
    String title,
    String subtitle,
    bool isGranted,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isGranted
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isGranted ? 'Granted' : 'Missing',
          style: TextStyle(
            color: isGranted ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      onTap: isGranted ? null : onTap,
    );
  }
}
