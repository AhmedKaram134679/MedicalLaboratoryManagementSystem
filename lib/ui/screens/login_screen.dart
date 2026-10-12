import 'package:flutter/material.dart';
import 'package:lab_managment_system/models/user_model.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/user_service.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final user = await UserService().login(
        _usernameController.text,
        _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        if (!mounted) return;
        if (user.forcePasswordChange) {
          _showForcePasswordChangeDialog(user);
        } else {
          Provider.of<AppProvider>(context, listen: false).login(user);
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في اسم المستخدم أو كلمة المرور'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on AccountLockedException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('LoginScreen Authentication Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تسجيل الدخول في الوقت الحالي. يرجى التحقق من الاتصال بالخادم والمحاولة مجدداً.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Branding Side
          Expanded(
            child: Container(
              color: Theme.of(context).primaryColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.science, size: 100, color: Colors.white),
                  const SizedBox(height: 24),
                  Text(
                    'نظام إدارة المختبرات الطبية',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Login Form Side
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(64.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تسجيل الدخول',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('دخول', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForcePasswordChangeDialog(UserModel user) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isUpdating = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 8),
              Text('تغيير كلمة المرور إلزامي'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'لأسباب أمنية، يجب عليك تغيير كلمة المرور الافتراضية قبل الدخول إلى النظام.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating
                  ? null
                  : () {
                      newPasswordController.dispose();
                      confirmPasswordController.dispose();
                      Navigator.pop(dialogContext);
                    },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isUpdating
                  ? null
                  : () async {
                      final newPass = newPasswordController.text;
                      final confirmPass = confirmPasswordController.text;

                      if (newPass.length < 8) {
                        setDialogState(() {
                          errorMessage = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                        });
                        return;
                      }

                      if (newPass.toLowerCase().trim() == 'admin') {
                        setDialogState(() {
                          errorMessage = 'لا يمكن استخدام "admin" ككلمة مرور جديدة لأسباب أمنية';
                        });
                        return;
                      }

                      if (newPass != confirmPass) {
                        setDialogState(() {
                          errorMessage = 'كلمتا المرور غير متطابقتين';
                        });
                        return;
                      }

                      setDialogState(() {
                        isUpdating = true;
                        errorMessage = null;
                      });

                      try {
                        final updatedUser = UserModel(
                          id: user.id,
                          username: user.username,
                          password: newPass, // will be salted & hashed in updateUser
                          role: user.role,
                          fullName: user.fullName,
                          forcePasswordChange: false,
                        );

                        await UserService().updateUser(updatedUser);
                        if (user.id != null) {
                          await UserService().clearForcePasswordChange(user.id!);
                        }

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        newPasswordController.dispose();
                        confirmPasswordController.dispose();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم تغيير كلمة المرور بنجاح. مرحباً بك!'),
                            backgroundColor: Colors.green,
                          ),
                        );

                        Provider.of<AppProvider>(context, listen: false).login(updatedUser);
                      } catch (e) {
                        setDialogState(() {
                          isUpdating = false;
                          errorMessage = 'حدث خطأ أثناء التحديث: $e';
                        });
                      }
                    },
              child: isUpdating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ والمتابعة'),
            ),
          ],
        ),
      ),
    );
  }
}
