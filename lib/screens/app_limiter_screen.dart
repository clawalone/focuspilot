import 'package:flutter/material.dart';

import 'package:installed_apps/app_info.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/app_service.dart';
import '../theme/app_theme.dart';
import 'timer_screen.dart';

class AppLimiterScreen extends StatefulWidget {
  final String category;
  final int workMinutes;
  final int reviseMinutes;
  final int breakMinutes;
  final int sessionsCount;
  final bool isReviseBefore;
  final String? note;

  const AppLimiterScreen({
    super.key,
    this.category = 'Focus',
    this.workMinutes = 25,
    this.reviseMinutes = 10,
    this.breakMinutes = 5,
    this.sessionsCount = 1,
    this.isReviseBefore = true,
    this.note,
  });

  @override
  State<AppLimiterScreen> createState() => _AppLimiterScreenState();
}

class _AppLimiterScreenState extends State<AppLimiterScreen> {
  final Set<String> _selectedApps = {};
  // Local state for apps is replaced by getters from service
  final TextEditingController _searchController = TextEditingController();

  // Package lists moved to service

  @override
  void initState() {
    super.initState();
    // Apps fetching is now handled by AppService and triggered in previous screen
    // We just need to ensure we have the data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadApps();
    });
  }

  void _checkAndLoadApps() {
    final appService = Provider.of<AppService>(context, listen: false);
    if (!appService.isLoaded && !appService.isLoading) {
      appService.loadApps();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to get apps from service
  List<AppInfo> get _socialApps => Provider.of<AppService>(context).socialApps;
  List<AppInfo> get _messengerApps =>
      Provider.of<AppService>(context).messengerApps;
  List<AppInfo> get _otherApps => Provider.of<AppService>(context).otherApps;
  bool get _isLoading => Provider.of<AppService>(context).isLoading;

  bool get _isAllSelected {
    final allApps = _getAllPackages();
    return allApps.isNotEmpty && _selectedApps.length == allApps.length;
  }

  List<String> _getAllPackages() {
    return [
      ..._socialApps.map((a) => a.packageName),
      ..._messengerApps.map((a) => a.packageName),
      ..._otherApps.map((a) => a.packageName),
    ];
  }

  void _toggleSelectAll() {
    final appService = Provider.of<AppService>(context, listen: false);
    final allPackages = [
      ...appService.socialApps.map((a) => a.packageName),
      ...appService.messengerApps.map((a) => a.packageName),
      ...appService.otherApps.map((a) => a.packageName),
    ];

    setState(() {
      // Check if all are currently selected
      bool allSelected =
          allPackages.isNotEmpty && _selectedApps.length == allPackages.length;

      if (allSelected) {
        _selectedApps.clear();
      } else {
        _selectedApps.addAll(allPackages);
      }
    });
  }

  void _toggleAppSelection(String packageName) {
    setState(() {
      if (_selectedApps.contains(packageName)) {
        _selectedApps.remove(packageName);
      } else {
        _selectedApps.add(packageName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.statsDarkBackground,
      body: Stack(
        children: [
          // Base Background
          Container(color: AppTheme.statsDarkBackground),

          // Background Blobs (Mesh Gradient)
          Positioned(
            top: -100,
            right: -100,
            child:
                Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.4),
                            AppTheme.primaryColor.withOpacity(0),
                          ],
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .move(
                      begin: const Offset(0, 0),
                      end: const Offset(-50, 40),
                      duration: 10.seconds,
                      curve: Curves.easeInOut,
                    )
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.2, 1.2),
                      duration: 12.seconds,
                      curve: Curves.easeInOut,
                    ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child:
                Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.secondaryColor.withOpacity(0.3),
                            AppTheme.secondaryColor.withOpacity(0),
                          ],
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .move(
                      begin: const Offset(0, 0),
                      end: const Offset(40, -50),
                      duration: 12.seconds,
                      curve: Curves.easeInOut,
                    )
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 14.seconds,
                      curve: Curves.easeInOut,
                    ),
          ),
          Positioned(
            top: 200,
            left: -150,
            child:
                Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.2),
                            AppTheme.primaryColor.withOpacity(0),
                          ],
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .move(
                      begin: const Offset(0, 0),
                      end: const Offset(30, 30),
                      duration: 15.seconds,
                      curve: Curves.easeInOut,
                    ),
          ),

          // Content
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'select apps to limit',
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _toggleSelectAll,
                                    child: Text(
                                      _isAllSelected
                                          ? 'deselect all'
                                          : 'select all',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'stop apps from sending notifications while you\'re focusing',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  color: Colors.white38,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Search Bar
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    icon: const Icon(
                                      Icons.search,
                                      color: Colors.white38,
                                    ),
                                    border: InputBorder.none,
                                    hintText: 'search',
                                    hintStyle: GoogleFonts.outfit(
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              if (_socialApps.isNotEmpty) ...[
                                _buildSectionHeader('social media'),
                                const SizedBox(height: 16),
                                _buildHorizontalList(_socialApps),
                                const SizedBox(height: 24),
                              ],

                              if (_messengerApps.isNotEmpty) ...[
                                _buildSectionHeader('messengers'),
                                const SizedBox(height: 16),
                                _buildHorizontalList(_messengerApps),
                                const SizedBox(height: 24),
                              ],

                              if (_otherApps.isNotEmpty) ...[
                                _buildSectionHeader('all apps'),
                                const SizedBox(height: 16),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        childAspectRatio: 0.75,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                  itemCount: _otherApps.length,
                                  itemBuilder: (context, index) =>
                                      _buildAppItem(_otherApps[index]),
                                ),
                                const SizedBox(height: 100),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Bottom Button
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          border: Border(
                            top: BorderSide(color: Colors.white10),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TimerScreen(
                                    category: widget.category,
                                    workMinutes: widget.workMinutes,
                                    reviseMinutes: widget.reviseMinutes,
                                    breakMinutes: widget.breakMinutes,
                                    sessionsCount: widget.sessionsCount,
                                    isReviseBefore: widget.isReviseBefore,
                                    note: widget.note,
                                    selectedApps: _selectedApps.toList(),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Start sessions',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildHorizontalList(List<AppInfo> apps) {
    return SizedBox(
      height: 110, // Adjust based on item height
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: apps.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildAppItem(apps[index]),
      ),
    );
  }

  Widget _buildAppItem(AppInfo app) {
    final isSelected = _selectedApps.contains(app.packageName);

    return GestureDetector(
      onTap: () => _toggleAppSelection(app.packageName),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.white10,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: app.icon != null
                ? Image.memory(app.icon!)
                : const Icon(Icons.android, color: Colors.white10),
          ),
        ],
      ),
    );
  }
}
