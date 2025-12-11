import 'package:flutter/material.dart';

import 'package:installed_apps/app_info.dart';
import 'package:provider/provider.dart';
import '../services/app_service.dart';
import 'timer_screen.dart';

class AppLimiterScreen extends StatefulWidget {
  final String category;
  final int durationInMinutes;

  const AppLimiterScreen({
    super.key,
    this.category = 'Focus',
    this.durationInMinutes = 25,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'select apps to limit',
                              style: TextStyle(
                                fontSize: 24, // Reduced slightly to fit button
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            TextButton(
                              onPressed: _toggleSelectAll,
                              child: Text(
                                _isAllSelected ? 'deselect all' : 'select all',
                                style: const TextStyle(
                                  // color: AppTheme.primaryColor, // Ensure visibility, maybe use a specific color or default
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'stop apps from sending notifications\nwhile you\'re focusing',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Search Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade900
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              icon: Icon(
                                Icons.search,
                                color: Colors.grey.shade400,
                              ),
                              border: InputBorder.none,
                              hintText: 'search',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
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
                          // Grid for "other" apps to be space efficient?
                          // Or horizontal too? Image implies horizontal lists.
                          // Let's stick to horizontal for consistency, or vertical list for "all".
                          // Given "All Apps" can be huge, a vertical list or grid inside the scroll view is better.
                          // But to match the "clean" look, let's try a grid.
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
                          const SizedBox(
                            height: 100,
                          ), // Space for bottom button
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom Button
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TimerScreen(
                              category: widget.category,
                              durationInMinutes: widget.durationInMinutes,
                              selectedApps: _selectedApps.toList(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'start',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _toggleAppSelection(app.packageName),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEADDFF) // Light purple for selection
                  : (isDark ? Colors.grey.shade900 : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF6750A4) // Purple border
                    : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: app.icon != null
                ? Image.memory(app.icon!)
                : const Icon(Icons.android, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
