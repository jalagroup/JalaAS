import '../models/role.dart';
import '../models/custom_report.dart';
import 'supabase_service.dart';

/// Singleton-style static service that holds the current user's role and
/// feature map in memory after login.  Call [loadForUser] once after sign-in
/// and [clear] on sign-out.
class PermissionService {
  PermissionService._();

  static Role? _role;
  static Map<String, RoleFeature> _featureMap = {};

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  static Future<void> loadForUser(String userId) async {
    _role = await SupabaseService.getUserRole(userId);
    _featureMap = _role != null
        ? {for (final f in _role!.features) f.featureKey: f}
        : {};
  }

  static void clear() {
    _role = null;
    _featureMap = {};
  }

  // ── Role info ───────────────────────────────────────────────────────────────

  static bool get hasRole => _role != null;

  static Role? get currentRole => _role;

  static String get roleName => _role?.nameAr ?? '';

  static bool get isAdminInterface =>
      _role?.interfaceType == InterfaceType.admin;

  static bool get isUserInterface =>
      _role?.interfaceType == InterfaceType.user;

  // ── Feature checks ──────────────────────────────────────────────────────────

  /// Returns true if the current role includes [featureKey].
  static bool hasFeature(String featureKey) =>
      _featureMap.containsKey(featureKey);

  /// Returns the per-feature config for [featureKey], or null.
  static RoleFeature? getFeature(String featureKey) =>
      _featureMap[featureKey];

  /// Convenience: get a string list from a feature's config.
  static List<String> featureStringList(String featureKey, String configKey) =>
      getFeature(featureKey)?.getStringList(configKey) ?? [];

  /// Convenience: get a string value from a feature's config.
  static String featureString(String featureKey, String configKey,
          {String defaultVal = ''}) =>
      getFeature(featureKey)?.getString(configKey, defaultVal: defaultVal) ??
      defaultVal;

  // ── Custom report access ────────────────────────────────────────────────────

  /// Returns true if the current role can view [reportId].
  /// If the role has no 'allowed_report_ids' restriction, all reports are allowed.
  static bool canViewReport(String reportId) {
    final feature = getFeature('custom_reports_viewer');
    if (feature == null) return false;
    final allowed = feature.getStringList('allowed_report_ids');
    if (allowed.isEmpty) return true; // no restriction → all allowed
    return allowed.contains(reportId);
  }

  /// Filter a list of reports to those the current role may view.
  static List<CustomReport> filterReports(List<CustomReport> reports) {
    if (!hasFeature('custom_reports_viewer')) return [];
    final feature = getFeature('custom_reports_viewer');
    final allowed = feature?.getStringList('allowed_report_ids') ?? [];
    if (allowed.isEmpty) return reports;
    return reports.where((r) => allowed.contains(r.id)).toList();
  }
}
