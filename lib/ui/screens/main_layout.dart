import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import 'dashboard_screen.dart';
import 'patient_registration_screen.dart';
import 'results_entry_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'patients_management_screen.dart';
import 'backup_management_screen.dart';
import 'admin_requests_screen.dart';
import '../../services/user_service.dart';
import '../../core/localization/app_localizations.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _navigationData;
  bool _isSidebarCollapsed = false;

  final GlobalKey<DashboardScreenState> _dashboardScreenKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<PatientsManagementScreenState> _patientsScreenKey = GlobalKey<PatientsManagementScreenState>();
  final GlobalKey<ResultsEntryScreenState> _resultsScreenKey = GlobalKey<ResultsEntryScreenState>();
  final GlobalKey<ReportsScreenState> _reportsScreenKey = GlobalKey<ReportsScreenState>();
  final GlobalKey<InventoryScreenState> _inventoryScreenKey = GlobalKey<InventoryScreenState>();

  void _onTabSelected(int index, {Map<String, dynamic>? data}) async {
    if (_selectedIndex == index) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    if (appProvider.hasUnsavedChanges) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تنبيه: تغييرات غير محفوظة'),
          content: const Text(
            'هناك بيانات أو نتائج غير محفوظة في الصفحة الحالية. هل تود تجاهلها والمتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('البقاء هنا'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('تجاهل والانتقال'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
      appProvider.setHasUnsavedChanges(false);
    }

    setState(() {
      _selectedIndex = index;
      _navigationData = data;
    });

    // Dynamic data refresh when switching tabs without destroying state
    if (index == 0) {
      _dashboardScreenKey.currentState?.refreshData();
    } else if (index == 1) {
      _patientsScreenKey.currentState?.refreshData();
    } else if (index == 3) {
      _resultsScreenKey.currentState?.refreshData();
    } else if (index == 4) {
      _inventoryScreenKey.currentState?.refreshData();
    } else if (index == 5) {
      _reportsScreenKey.currentState?.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Provider.of<AppProvider>(context).isAdmin;

    final List<Widget> screens = [
      DashboardScreen(
        key: _dashboardScreenKey,
        onNavigate: (index, {data}) => _onTabSelected(index, data: data),
      ),
      PatientsManagementScreen(
        key: _patientsScreenKey,
        onNavigate: (index, {data}) => _onTabSelected(index, data: data),
      ),
      PatientRegistrationScreen(
        key: const ValueKey('reg_screen'),
        editPatientId: _selectedIndex == 2 && _navigationData != null
            ? _navigationData!['patient_id']
            : null,
        onNavigate: (index) => _onTabSelected(index),
      ),
      ResultsEntryScreen(
        key: _resultsScreenKey,
        navigationData: _navigationData,
        onNavigationConsumed: () => setState(() => _navigationData = null),
      ),
      InventoryScreen(
        key: _inventoryScreenKey,
      ),
      ReportsScreen(
        key: _reportsScreenKey,
      ),
      const BackupManagementScreen(),
      const SettingsScreen(),
      const AdminRequestsScreen(),
    ];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;
          final effectiveCollapsed = _isSidebarCollapsed || isNarrow;
          final sidebarWidth = effectiveCollapsed ? 80.0 : 280.0;
          final loc = AppLocalizations.of(context);
          final currentLocale = Provider.of<AppProvider>(context).locale;
          final isArabic = currentLocale.languageCode == 'ar';

          return Row(
            children: [
              // Navigation Panel
              Material(
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                color: Theme.of(context).colorScheme.surface,
                child: ClipRect(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: sidebarWidth,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: effectiveCollapsed ? 80.0 : 280.0,
                        height: constraints.maxHeight,
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: effectiveCollapsed
                                ? Center(
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.biotech,
                                        size: 32,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      tooltip: isNarrow ? 'MLMS' : (isArabic ? 'توسيع القائمة' : 'Expand Sidebar'),
                                      onPressed: isNarrow
                                          ? null
                                          : () {
                                              setState(() {
                                                _isSidebarCollapsed = !_isSidebarCollapsed;
                                              });
                                            },
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.biotech,
                                            size: 34,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'MLMS',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!isNarrow)
                                        IconButton(
                                          icon: Icon(
                                            isArabic ? Icons.chevron_right : Icons.chevron_left,
                                            size: 20,
                                          ),
                                          tooltip: isArabic ? 'طي القائمة' : 'Collapse Sidebar',
                                          onPressed: () {
                                            setState(() {
                                              _isSidebarCollapsed = !_isSidebarCollapsed;
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                            _buildNavItem(
                              0,
                              loc?.dashboard ?? (isArabic ? 'لوحة التحكم' : 'Dashboard'),
                              Icons.dashboard_outlined,
                              Icons.dashboard,
                              effectiveCollapsed,
                            ),
                            _buildNavItem(
                              1,
                              loc?.patients ?? (isArabic ? 'إدارة المرضى' : 'Patients'),
                              Icons.people_alt_outlined,
                              Icons.people_alt,
                              effectiveCollapsed,
                            ),
                            _buildNavItem(
                              2,
                              loc?.registration ?? (isArabic ? 'تسجيل مريض' : 'Register Patient'),
                              Icons.person_add_outlined,
                              Icons.person_add,
                              effectiveCollapsed,
                            ),
                            _buildNavItem(
                              3,
                              loc?.resultsEntry ?? (isArabic ? 'إدخال النتائج' : 'Results Entry'),
                              Icons.assignment_outlined,
                              Icons.assignment,
                              effectiveCollapsed,
                            ),
                            _buildNavItem(
                              4,
                              loc?.inventory ?? (isArabic ? 'المخزون' : 'Inventory'),
                              Icons.inventory_2_outlined,
                              Icons.inventory_2,
                              effectiveCollapsed,
                            ),
                            _buildNavItem(
                              5,
                              isArabic ? 'التقارير' : 'Reports',
                              Icons.bar_chart_outlined,
                              Icons.bar_chart,
                              effectiveCollapsed,
                            ),
                            _buildNavItem(
                              6,
                              isArabic ? 'النسخ الاحتياطي' : 'Backups',
                              Icons.backup_outlined,
                              Icons.backup,
                              effectiveCollapsed,
                            ),
                            _buildNavItem(
                              7,
                              loc?.settings ?? (isArabic ? 'الإعدادات' : 'Settings'),
                              Icons.settings_outlined,
                              Icons.settings,
                              effectiveCollapsed,
                            ),
                            if (isAdmin)
                              _buildNavItem(
                                8,
                                isArabic ? 'طلبات الإدارة' : 'Admin Requests',
                                Icons.admin_panel_settings_outlined,
                                Icons.admin_panel_settings,
                                effectiveCollapsed,
                              ),
                          ],
                        ),
                      ),
                      // Language Switcher
                      _buildBottomActionTile(
                        icon: Icons.language,
                        title: isArabic ? 'English (EN)' : 'العربية (AR)',
                        tooltip: isArabic ? 'English' : 'العربية',
                        collapsed: effectiveCollapsed,
                        onTap: () {
                          final newLocale = isArabic ? const Locale('en') : const Locale('ar');
                          Provider.of<AppProvider>(context, listen: false).setLocale(newLocale);
                        },
                      ),
                      // Theme Switcher
                      _buildBottomActionTile(
                        icon: Provider.of<AppProvider>(context).themeMode == ThemeMode.dark
                            ? Icons.light_mode
                            : Icons.dark_mode,
                        title: Provider.of<AppProvider>(context).themeMode == ThemeMode.dark
                            ? (isArabic ? 'الوضع الفاتح' : 'Light Mode')
                            : (isArabic ? 'الوضع الداكن' : 'Dark Mode'),
                        tooltip: Provider.of<AppProvider>(context).themeMode == ThemeMode.dark
                            ? (isArabic ? 'الوضع الفاتح' : 'Light Mode')
                            : (isArabic ? 'الوضع الداكن' : 'Dark Mode'),
                        collapsed: effectiveCollapsed,
                        onTap: () {
                          Provider.of<AppProvider>(context, listen: false).toggleTheme();
                        },
                      ),
                      // Change Password
                      _buildBottomActionTile(
                        icon: Icons.lock_reset,
                        title: isArabic ? 'تغيير كلمة المرور' : 'Change Password',
                        tooltip: isArabic ? 'تغيير كلمة المرور' : 'Change Password',
                        collapsed: effectiveCollapsed,
                        onTap: _showChangePasswordDialog,
                      ),
                      // Logout
                      _buildBottomActionTile(
                        icon: Icons.logout,
                        title: loc?.logout ?? (isArabic ? 'تسجيل الخروج' : 'Logout'),
                        tooltip: loc?.logout ?? (isArabic ? 'خروج' : 'Logout'),
                        collapsed: effectiveCollapsed,
                        textColor: Theme.of(context).colorScheme.error,
                        iconColor: Theme.of(context).colorScheme.error,
                        onTap: () => _confirmLogout(context, loc, isArabic),
                      ),
                      const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: screens,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppLocalizations? loc, bool isArabic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc?.logout ?? (isArabic ? 'تسجيل الخروج' : 'Logout')),
        content: Text(isArabic ? 'هل أنت متأكد من تسجيل الخروج؟' : 'Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc?.cancel ?? (isArabic ? 'إلغاء' : 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AppProvider>(context, listen: false).logout();
            },
            child: Text(
              loc?.logout ?? (isArabic ? 'خروج' : 'Logout'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String title,
    IconData icon,
    IconData activeIcon,
    bool collapsed,
  ) {
    bool isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: title,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTabSelected(index),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? primaryColor : Theme.of(context).iconTheme.color,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onTabSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? primaryColor : Theme.of(context).iconTheme.color,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionTile({
    required IconData icon,
    required String title,
    required String tooltip,
    required bool collapsed,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.primary;
    final effectiveTextColor = textColor ?? Theme.of(context).textTheme.bodyMedium?.color;

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                color: effectiveIconColor,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: effectiveIconColor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: effectiveTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;
    String? errorMessage;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentUser = appProvider.currentUser;

    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.lock_reset, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('تغيير كلمة المرور'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'يرجى إدخال كلمة المرور الحالية';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        prefixIcon: const Icon(Icons.key),
                        helperText: '8 أحرف على الأقل، ويمنع استخدام كلمة admin',
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'يرجى إدخال كلمة المرور الجديدة';
                        }
                        if (val.length < 8) {
                          return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                        }
                        if (val.trim().toLowerCase() == 'admin') {
                          return 'لا يمكن تعيين كلمة المرور كـ admin لأسباب أمنية';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                      validator: (val) {
                        if (val != newPasswordController.text) {
                          return 'كلمات المرور غير متطابقة';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.pop(dialogCtx);
                        currentPasswordController.dispose();
                        newPasswordController.dispose();
                        confirmPasswordController.dispose();
                      },
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });

                        try {
                          // Verify current password
                          final verifyUser = await UserService().login(
                            currentUser.username,
                            currentPasswordController.text,
                          );

                          if (verifyUser == null) {
                            setDialogState(() {
                              isLoading = false;
                              errorMessage = 'كلمة المرور الحالية غير صحيحة';
                            });
                            return;
                          }

                          // Update password
                          final updatedUser = currentUser.copyWith(
                            password: newPasswordController.text,
                            forcePasswordChange: false,
                          );
                          await UserService().updateUser(
                            updatedUser,
                            isPasswordAlreadyHashed: false,
                          );

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          currentPasswordController.dispose();
                          newPasswordController.dispose();
                          confirmPasswordController.dispose();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تغيير كلمة المرور بنجاح'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = 'حدث خطأ أثناء تغيير كلمة المرور: $e';
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ التغيير'),
              ),
            ],
          );
        },
      ),
    );
  }
}
