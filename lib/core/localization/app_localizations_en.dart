// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Medical Laboratory Management System';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get patients => 'Patients';

  @override
  String get registration => 'Patient Registration';

  @override
  String get resultsEntry => 'Results Entry';

  @override
  String get invoices => 'Invoices';

  @override
  String get inventory => 'Inventory';

  @override
  String get settings => 'Settings';

  @override
  String get reports => 'Reports';

  @override
  String get logout => 'Logout';

  @override
  String get search => 'Search';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get print => 'Print';

  @override
  String get refresh => 'Refresh';

  @override
  String get status => 'Status';

  @override
  String get name => 'Name';

  @override
  String get age => 'Age';

  @override
  String get gender => 'Gender';

  @override
  String get phone => 'Phone';

  @override
  String get address => 'Address';

  @override
  String get doctor => 'Doctor';

  @override
  String get completed => 'Completed';

  @override
  String get pending => 'Pending';

  @override
  String get draft => 'Draft';

  @override
  String get approved => 'Approved';

  @override
  String get total => 'Total';

  @override
  String get paid => 'Paid';

  @override
  String get remaining => 'Remaining';

  @override
  String get discount => 'Discount';

  @override
  String get actions => 'Actions';

  @override
  String get close => 'Close';

  @override
  String get adminRequests => 'Admin Requests';

  @override
  String get noPendingRequests => 'No pending requests';

  @override
  String get newPassword => 'New Password';

  @override
  String get resetAndApprove => 'Reset & Approve';

  @override
  String get passwordResetSuccess => 'Password reset successfully';

  @override
  String get passwordRecovery => 'Password Recovery';

  @override
  String get unapproveTest => 'Unapprove Test';

  @override
  String requestedOn(String date) {
    return 'Requested on: $date';
  }

  @override
  String resetPasswordFor(String username) {
    return 'Reset Password for $username';
  }

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String errorLoadingRequests(String error) {
    return 'Error loading requests: $error';
  }

  @override
  String get loginTitle => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get loginButton => 'Sign In';

  @override
  String get invalidCredentials => 'Invalid username or password';

  @override
  String get allFieldsRequired => 'Please fill all required fields';

  @override
  String get backupManagement => 'Backup Management';

  @override
  String get createBackup => 'Create Backup';

  @override
  String get restoreBackup => 'Restore Backup';

  @override
  String get backupSuccess => 'Backup created successfully';

  @override
  String get restoreSuccess => 'Backup restored successfully';

  @override
  String get date => 'Date';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get exportExcel => 'Export Excel';

  @override
  String get startDate => 'Start Date';

  @override
  String get endDate => 'End Date';

  @override
  String get quantity => 'Quantity';

  @override
  String get unit => 'Unit';

  @override
  String get minThreshold => 'Minimum Threshold';

  @override
  String get expiryDate => 'Expiry Date';

  @override
  String get addItem => 'Add Item';

  @override
  String get filter => 'Filter';

  @override
  String get notes => 'Notes';

  @override
  String get confirmDelete => 'Are you sure you want to delete this record?';

  @override
  String get warning => 'Warning';

  @override
  String get success => 'Success';

  @override
  String get error => 'Error';

  @override
  String get weakDeficiency => 'Weak Deficiency';

  @override
  String get moderateDeficiency => 'Moderate Deficiency';

  @override
  String get preferredLevel => 'Preferred Level';

  @override
  String get toxicity => 'Toxicity';

  @override
  String get casts => 'Casts';
}
