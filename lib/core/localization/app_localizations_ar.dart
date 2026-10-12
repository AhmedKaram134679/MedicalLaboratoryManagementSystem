// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'نظام إدارة المختبرات الطبية';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get patients => 'سجل المرضى';

  @override
  String get registration => 'تسجيل مريض جديد';

  @override
  String get resultsEntry => 'إدخال النتائج';

  @override
  String get invoices => 'الفواتير والحسابات';

  @override
  String get inventory => 'إدارة المخزون';

  @override
  String get settings => 'الإعدادات';

  @override
  String get reports => 'التقارير';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get search => 'بحث';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get print => 'طباعة';

  @override
  String get refresh => 'تحديث';

  @override
  String get status => 'الحالة';

  @override
  String get name => 'الاسم';

  @override
  String get age => 'العمر';

  @override
  String get gender => 'الجنس';

  @override
  String get phone => 'الهاتف';

  @override
  String get address => 'العنوان';

  @override
  String get doctor => 'الطبيب المعالج';

  @override
  String get completed => 'مكتمل';

  @override
  String get pending => 'معلق';

  @override
  String get draft => 'مسودة';

  @override
  String get approved => 'معتمد';

  @override
  String get total => 'الإجمالي';

  @override
  String get paid => 'المدفوع';

  @override
  String get remaining => 'المتبقي';

  @override
  String get discount => 'الخصم';

  @override
  String get actions => 'إجراءات';

  @override
  String get close => 'إغلاق';

  @override
  String get adminRequests => 'طلبات الإدارة';

  @override
  String get noPendingRequests => 'لا توجد طلبات معلقة';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get resetAndApprove => 'إعادة التعيين والموافقة';

  @override
  String get passwordResetSuccess => 'تمت إعادة تعيين كلمة المرور بنجاح';

  @override
  String get passwordRecovery => 'استعادة كلمة المرور';

  @override
  String get unapproveTest => 'إلغاء اعتماد فحص';

  @override
  String requestedOn(String date) {
    return 'تاريخ الطلب: $date';
  }

  @override
  String resetPasswordFor(String username) {
    return 'إعادة تعيين كلمة المرور للمستخدم $username';
  }

  @override
  String get approve => 'موافقة';

  @override
  String get reject => 'رفض';

  @override
  String errorLoadingRequests(String error) {
    return 'خطأ في تحميل الطلبات: $error';
  }

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginButton => 'دخول';

  @override
  String get invalidCredentials => 'اسم المستخدم أو كلمة المرور غير صحيحة';

  @override
  String get allFieldsRequired => 'يرجى ملء جميع الحقول المطلوبة';

  @override
  String get backupManagement => 'إدارة النسخ الاحتياطي';

  @override
  String get createBackup => 'إنشاء نسخة احتياطية';

  @override
  String get restoreBackup => 'استعادة نسخة احتياطية';

  @override
  String get backupSuccess => 'تم إنشاء النسخة الاحتياطية بنجاح';

  @override
  String get restoreSuccess => 'تمت استعادة النسخة الاحتياطية بنجاح';

  @override
  String get date => 'التاريخ';

  @override
  String get exportPdf => 'تصدير PDF';

  @override
  String get exportExcel => 'تصدير Excel';

  @override
  String get startDate => 'من تاريخ';

  @override
  String get endDate => 'إلى تاريخ';

  @override
  String get quantity => 'الكمية';

  @override
  String get unit => 'الوحدة';

  @override
  String get minThreshold => 'حد الطلب الأدنى';

  @override
  String get expiryDate => 'تاريخ الصلاحية';

  @override
  String get addItem => 'إضافة صنف';

  @override
  String get filter => 'تصفية';

  @override
  String get notes => 'ملاحظات';

  @override
  String get confirmDelete => 'هل أنت متأكد من حذف هذا السجل؟';

  @override
  String get warning => 'تنبيه';

  @override
  String get success => 'نجاح';

  @override
  String get error => 'خطأ';

  @override
  String get weakDeficiency => 'نقص خفيف';

  @override
  String get moderateDeficiency => 'نقص متوسط';

  @override
  String get preferredLevel => 'المستوى المفضل';

  @override
  String get toxicity => 'سمية';

  @override
  String get casts => 'أسطوانات';
}
