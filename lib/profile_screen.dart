import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/auth_sheet.dart';
import 'package:basha_lagbe/services/auth_service.dart';
import 'package:basha_lagbe/services/firestore_service.dart';
import 'package:basha_lagbe/admin_dashboard_screen.dart';
import 'package:basha_lagbe/chat_screen.dart';
import 'package:basha_lagbe/conversations_screen.dart';

// ---------------------------------------------------------------------------
// Models for User Profile & Rental Requests
// ---------------------------------------------------------------------------

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'Verified Renter & Host',
  });

  final String name;
  final String email;
  final String phone;
  final String role;

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
    );
  }
}

class RentalRequest {
  const RentalRequest({
    required this.id,
    required this.property,
    required this.renterName,
    required this.renterPhone,
    required this.preferredMoveIn,
    this.message = '',
    required this.requestedAt,
    this.status = 'Pending Landlord Response',
    this.ownerId,
    this.tenantId,
    this.tenantEmail,
    this.landlordNote,
    this.updatedAt,
    this.isDemo = false,
  });

  final String id;
  final Property property;
  final String renterName;
  final String renterPhone;
  final String preferredMoveIn;
  final String message;
  final DateTime requestedAt;
  final String status;
  final String? ownerId;
  final String? tenantId;
  final String? tenantEmail;
  final String? landlordNote;
  final DateTime? updatedAt;
  final bool isDemo;

  bool get isPending {
    final s = status.toLowerCase();
    return s.contains('pending');
  }

  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  RentalRequest copyWith({
    String? id,
    Property? property,
    String? renterName,
    String? renterPhone,
    String? preferredMoveIn,
    String? message,
    DateTime? requestedAt,
    String? status,
    String? ownerId,
    String? tenantId,
    String? tenantEmail,
    String? landlordNote,
    DateTime? updatedAt,
    bool? isDemo,
  }) {
    return RentalRequest(
      id: id ?? this.id,
      property: property ?? this.property,
      renterName: renterName ?? this.renterName,
      renterPhone: renterPhone ?? this.renterPhone,
      preferredMoveIn: preferredMoveIn ?? this.preferredMoveIn,
      message: message ?? this.message,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      tenantId: tenantId ?? this.tenantId,
      tenantEmail: tenantEmail ?? this.tenantEmail,
      landlordNote: landlordNote ?? this.landlordNote,
      updatedAt: updatedAt ?? this.updatedAt,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}

// ---------------------------------------------------------------------------
// Main Profile Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
    this.firebaseUser,
    this.onSignOut,
    required this.listingsCount,
    required this.savedCount,
    required this.rentalRequests,
    required this.onCancelRentalRequest,
    required this.onNavigateToMyListings,
    required this.onNavigateToSaved,
    required this.onNavigateToHome,
    this.firestoreService,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;
  final User? firebaseUser;
  final VoidCallback? onSignOut;
  final int listingsCount;
  final int savedCount;
  final List<RentalRequest> rentalRequests;
  final ValueChanged<String> onCancelRentalRequest;
  final VoidCallback onNavigateToMyListings;
  final VoidCallback onNavigateToSaved;
  final VoidCallback onNavigateToHome;
  final FirestoreService? firestoreService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  FirestoreService get _service => widget.firestoreService ?? FirestoreService.instance;
  bool _notificationsEnabled = true;

  void _openAuthSheet({bool isRegister = false}) {
    AuthSheet.show(
      context,
      initialIsRegister: isRegister,
      onAuthenticated: (user) {
        showFriendlyMessage(
          context,
          'Signed in as ${user.displayName ?? user.email ?? "User"}',
        );
      },
    );
  }

  void _confirmSignOut() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out from your BashaLagbe Firebase account?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await AuthService.instance.signOut();
                widget.onSignOut?.call();
                if (mounted) {
                  showFriendlyMessage(context, 'Signed out of Firebase account.');
                }
              } catch (e) {
                if (mounted) {
                  showFriendlyMessage(context, AuthService.getFriendlyErrorMessage(e));
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Account'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your BashaLagbe account and profile data? This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final uid = widget.firebaseUser?.uid;
              try {
                if (uid != null) {
                  await FirestoreService.instance.deleteUserProfile(uid);
                }
                await AuthService.instance.deleteAccount();
                widget.onSignOut?.call();
                if (mounted) {
                  showFriendlyMessage(context, 'Your account has been deleted.');
                }
              } catch (e) {
                if (mounted) {
                  showFriendlyMessage(context, AuthService.getFriendlyErrorMessage(e));
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await AuthService.instance.sendEmailVerification();
      if (mounted) {
        showFriendlyMessage(
          context,
          'Verification email sent. Please check your inbox and spam folder.',
        );
      }
    } catch (e) {
      if (mounted) {
        showFriendlyMessage(context, AuthService.getFriendlyErrorMessage(e));
      }
    }
  }

  void _openEditProfileSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return EditProfileSheet(
          profile: widget.profile,
          onSave: (updated) {
            widget.onProfileUpdated(updated);
            Navigator.of(modalContext).pop();
            showFriendlyMessage(context, 'Profile updated successfully!');
          },
        );
      },
    );
  }

  void _openRentalRequestsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return RentalRequestsSheet(
          rentalRequests: widget.rentalRequests,
          currentUser: widget.firebaseUser,
          onCancelRequest: (requestId) async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: AppColors.heart),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Withdraw Request?'),
                    ),
                  ],
                ),
                content: const Text(
                  'Are you sure you want to withdraw this rental request? You will be able to reapply later if you wish.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Keep Request', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.heart),
                    child: const Text('Withdraw'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              widget.onCancelRentalRequest(requestId);
              if (modalContext.mounted) {
                Navigator.of(modalContext).pop();
              }
              if (mounted) {
                showFriendlyMessage(context, 'Rental request withdrawn.');
              }
            }
          },
          onExploreHomes: () {
            Navigator.of(modalContext).pop();
            widget.onNavigateToHome();
          },
        );
      },
    );
  }

  void _showHelpDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HelpSupportSheet(),
    );
  }

  void _showAboutDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AboutBashaLagbeSheet(),
    );
  }

  void _showPrivacyTermsDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PrivacyTermsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // -------------------------------------------------------------
              // Header
              // -------------------------------------------------------------
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.firebaseUser != null
                            ? 'Manage your account and view all your rental activity.'
                            : 'Sign in or explore rentals and saved homes as a guest.',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // -------------------------------------------------------------
              // Profile Identity Card (Firebase Authenticated or Sign-In Prompt)
              // -------------------------------------------------------------
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: widget.firebaseUser != null
                      ? _buildFirebaseAuthCard(widget.firebaseUser!)
                      : _buildSignedOutCard(),
                ),
              ),

              // -------------------------------------------------------------
              // My Activity Section
              // -------------------------------------------------------------
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.white,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            // 1. My Listings
                            _buildActivityTile(
                              icon: Icons.maps_home_work_outlined,
                              title: 'My Listings',
                              subtitle: 'Properties you have posted for rent',
                              badgeText: '${widget.listingsCount} listing${widget.listingsCount == 1 ? '' : 's'}',
                              badgeColor: AppColors.lightGreen,
                              badgeTextColor: AppColors.darkGreen,
                              onTap: widget.onNavigateToMyListings,
                            ),
                            const Divider(height: 1, indent: 56, color: AppColors.border),

                            // 2. Saved Properties
                            _buildActivityTile(
                              icon: Icons.favorite_outline,
                              title: 'Saved Properties',
                              subtitle: 'Bookmarked houses, rooms & mess seats',
                              badgeText: '${widget.savedCount} saved',
                              badgeColor: widget.savedCount > 0 ? AppColors.lightGreen : AppColors.background,
                              badgeTextColor: widget.savedCount > 0 ? AppColors.darkGreen : AppColors.textMuted,
                              onTap: widget.onNavigateToSaved,
                            ),
                            const Divider(height: 1, indent: 56, color: AppColors.border),

                            // 3. My Rental Requests
                            _buildActivityTile(
                              icon: Icons.send_outlined,
                              title: 'My Rental Requests',
                              subtitle: 'Requests sent to landlords via Request to Rent',
                              badgeText: '${widget.rentalRequests.length} request${widget.rentalRequests.length == 1 ? '' : 's'}',
                              badgeColor: widget.rentalRequests.isNotEmpty
                                  ? AppColors.amberLight
                                  : AppColors.background,
                              badgeTextColor: widget.rentalRequests.isNotEmpty
                                  ? AppColors.amber
                                  : AppColors.textMuted,
                              onTap: _openRentalRequestsSheet,
                            ),
                            if (widget.firebaseUser != null) ...[
                              const Divider(height: 1, indent: 56, color: AppColors.border),
                              _buildActivityTile(
                                icon: Icons.forum_outlined,
                                title: 'Messages',
                                subtitle: 'Real-time chat with landlords and tenants',
                                badgeText: 'Chat',
                                badgeColor: AppColors.lightGreen,
                                badgeTextColor: AppColors.darkGreen,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ConversationsScreen(
                                        currentUser: widget.firebaseUser,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                            if (widget.firebaseUser != null)
                              StreamBuilder<bool>(
                                stream: _service.streamIsAdmin(widget.firebaseUser!.uid),
                                builder: (context, adminSnapshot) {
                                  if (adminSnapshot.data != true) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Divider(height: 1, indent: 56, color: AppColors.border),
                                      _buildActivityTile(
                                        key: const ValueKey('admin_dashboard_tile'),
                                        icon: Icons.admin_panel_settings_outlined,
                                        title: 'Admin Dashboard',
                                        subtitle: 'Review and moderate pending property submissions',
                                        badgeText: 'Admin',
                                        badgeColor: AppColors.lightGreen,
                                        badgeTextColor: AppColors.darkGreen,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => AdminDashboardScreen(
                                                currentUser: widget.firebaseUser,
                                                firestoreService: _service,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // -------------------------------------------------------------
              // Settings and Preferences
              // -------------------------------------------------------------
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settings & Preferences',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.white,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              secondary: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: AppColors.lightGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.notifications_outlined, color: AppColors.green, size: 20),
                              ),
                              title: const Text(
                                'Rental Notifications',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                              ),
                              subtitle: const Text(
                                'Push & SMS alerts for new listings',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              value: _notificationsEnabled,
                              activeTrackColor: AppColors.green,
                              activeThumbColor: Colors.white,
                              onChanged: (val) {
                                setState(() {
                                  _notificationsEnabled = val;
                                });
                                showFriendlyMessage(
                                  context,
                                  val
                                      ? 'Notification alerts enabled.'
                                      : 'Notification alerts paused.',
                                );
                              },
                            ),
                            const Divider(height: 1, indent: 56, color: AppColors.border),
                            ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: AppColors.lightGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.language, color: AppColors.green, size: 20),
                              ),
                              title: const Text(
                                'App Language',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                              ),
                              subtitle: const Text(
                                'English (Bangla localization planned)',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                              onTap: () {
                                showFriendlyMessage(
                                  context,
                                  'Bangla localization will be available in future releases.',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // -------------------------------------------------------------
              // Information & Support
              // -------------------------------------------------------------
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Support & Legal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.white,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _buildInfoTile(
                              icon: Icons.help_outline_rounded,
                              title: 'Help & FAQs',
                              subtitle: 'How BashaLagbe works & renter guidance',
                              onTap: _showHelpDialog,
                            ),
                            const Divider(height: 1, indent: 56, color: AppColors.border),
                            _buildInfoTile(
                              icon: Icons.info_outline_rounded,
                              title: 'About BashaLagbe',
                              subtitle: 'Our mission, version & developer info',
                              onTap: _showAboutDialog,
                            ),
                            const Divider(height: 1, indent: 56, color: AppColors.border),
                            _buildInfoTile(
                              icon: Icons.policy_outlined,
                              title: 'Privacy Policy & Terms',
                              subtitle: 'Data protection, Firebase, & terms of service',
                              onTap: _showPrivacyTermsDialog,
                            ),
                            if (widget.firebaseUser != null) ...[
                              const Divider(height: 1, indent: 56, color: AppColors.border),
                              _buildInfoTile(
                                icon: Icons.delete_forever_outlined,
                                iconColor: Colors.red.shade700,
                                iconBgColor: Colors.red.shade50,
                                title: 'Delete Account',
                                titleColor: Colors.red.shade700,
                                subtitle: 'Permanently remove your account and data',
                                onTap: _confirmDeleteAccount,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Version tag
                      const Center(
                        child: Text(
                          'BashaLagbe v1.0.0\nBuilt with Flutter • Material 3',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.green, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: badgeTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? iconBgColor,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor ?? AppColors.lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor ?? AppColors.green, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFirebaseAuthCard(User user) {
    final displayName = user.displayName != null && user.displayName!.trim().isNotEmpty
        ? user.displayName!.trim()
        : (user.email != null && user.email!.contains('@')
            ? user.email!.split('@').first
            : 'BashaLagbe User');
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.green, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name & Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: AppColors.green),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Firebase Account',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkGreen,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: user.emailVerified ? AppColors.lightGreen : AppColors.amberLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.emailVerified ? 'Email Verified' : 'Unverified Email',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: user.emailVerified ? AppColors.darkGreen : AppColors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Email
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 16, color: AppColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  user.email ?? 'No email provided',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          // Email verification prompt if unverified
          if (!user.emailVerified) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.amber),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Email is not yet verified.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textDark),
                    ),
                  ),
                  InkWell(
                    onTap: _sendVerificationEmail,
                    child: const Text(
                      'Send link',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.green,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Actions: Edit Profile & Sign Out
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 320;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openEditProfileSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreen,
                        side: const BorderSide(color: AppColors.green),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text(
                        'Edit Profile',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _confirmSignOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 15),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openEditProfileSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreen,
                        side: const BorderSide(color: AppColors.green),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text(
                        'Edit Profile',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _confirmSignOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 15),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignedOutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.green,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to BashaLagbe',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sign in to access your profile, sync listings, and manage rental requests.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 330;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openAuthSheet(isRegister: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text(
                        'Sign In',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openAuthSheet(isRegister: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreen,
                        side: const BorderSide(color: AppColors.green),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                      label: const Text(
                        'Create Account',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openAuthSheet(isRegister: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text(
                        'Sign In',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openAuthSheet(isRegister: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreen,
                        side: const BorderSide(color: AppColors.green),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                      label: const Text(
                        'Create Account',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Currently browsing as guest. Saved homes and search work locally.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
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
}

// ---------------------------------------------------------------------------
// Edit Profile Bottom Sheet
// ---------------------------------------------------------------------------

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.profile,
    required this.onSave,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onSave;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _emailController = TextEditingController(text: widget.profile.email);
    _phoneController = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      final updated = widget.profile.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (AuthService.instance.currentUser != null) {
        try {
          await AuthService.instance.updateDisplayName(_nameController.text.trim());
        } catch (_) {}
      }
      widget.onSave(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  const Icon(Icons.edit, color: AppColors.green),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Notice Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppColors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Updating your profile syncs your display name across BashaLagbe.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Full Name
              const Text('Full Name *', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(
                  hintText: 'e.g. Tanvir Ahmed',
                  prefixIcon: Icons.person_outline,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  if (val.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Email Address
              const Text('Email Address *', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hintText: 'e.g. tanvir.basha@gmail.com',
                  prefixIcon: Icons.email_outlined,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your email address';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Phone Number
              const Text('Contact Phone *', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  hintText: 'e.g. +880 1712-345678',
                  prefixIcon: Icons.phone_outlined,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (val.trim().length < 6) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 22),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _handleSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Edits',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppColors.background,
      prefixIcon: Icon(prefixIcon, color: AppColors.green, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.green, width: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Rental Requests Bottom Sheet
// ---------------------------------------------------------------------------

class RentalRequestsSheet extends StatelessWidget {
  const RentalRequestsSheet({
    super.key,
    required this.rentalRequests,
    required this.onCancelRequest,
    required this.onExploreHomes,
    this.currentUser,
  });

  final List<RentalRequest> rentalRequests;
  final ValueChanged<String> onCancelRequest;
  final VoidCallback onExploreHomes;
  final User? currentUser;

  static String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    return '${dt.day} $month ${dt.year}';
  }

  Widget _buildStatusBadge(RentalRequest req) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    if (req.isAccepted) {
      bg = AppColors.successSurface;
      fg = AppColors.success;
      icon = Icons.check_circle_outline;
      label = 'Accepted';
    } else if (req.isRejected) {
      bg = AppColors.errorSurface;
      fg = AppColors.error;
      icon = Icons.highlight_off_outlined;
      label = 'Declined';
    } else if (req.isCancelled) {
      bg = Colors.grey.shade200;
      fg = AppColors.textMuted;
      icon = Icons.cancel_outlined;
      label = 'Withdrawn';
    } else {
      bg = AppColors.amberLight;
      fg = AppColors.amber;
      icon = Icons.hourglass_top_outlined;
      label = 'Pending Review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Icon(Icons.send_rounded, color: AppColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Rental Requests',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '${rentalRequests.length} request${rentalRequests.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Requests List or Empty State
          Expanded(
            child: rentalRequests.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              color: AppColors.lightGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_and_archive_outlined,
                              size: 44,
                              color: AppColors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No rental requests yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'When you tap "Request to Rent" on any property, your rental inquiry will be listed here with its status.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: onExploreHomes,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.search),
                            label: const Text('Explore Available Homes'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: rentalRequests.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final req = rentalRequests[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        req.property.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        req.property.area,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (req.isDemo) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.info_outline, size: 10, color: AppColors.textMuted),
                                            SizedBox(width: 3),
                                            Text(
                                              'Demo',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    _buildStatusBadge(req),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  formatTaka(req.property.rentPerMonth),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                                const Text(' / mo', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Move-in: ${req.preferredMoveIn}',
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  ),
                                ),
                              ],
                            ),
                            if (req.message.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  'Your Note: "${req.message}"',
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textDark),
                                ),
                              ),
                            ],
                            if (req.landlordNote != null && req.landlordNote!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: req.isAccepted
                                      ? AppColors.successSurface
                                      : AppColors.errorSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: req.isAccepted
                                        ? AppColors.success.withAlpha(60)
                                        : AppColors.error.withAlpha(60),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      req.isAccepted ? Icons.check_circle_outline : Icons.info_outline,
                                      size: 14,
                                      color: req.isAccepted ? AppColors.success : AppColors.error,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Landlord Note: "${req.landlordNote}"',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: req.isAccepted ? AppColors.success : AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (req.isAccepted) ...[
                              LandlordContactCard(
                                propertyId: req.property.id,
                                landlordNote: req.landlordNote,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    final ownerId = req.ownerId;
                                    final tenantId = req.tenantId;
                                    if (ownerId == null || ownerId.isEmpty || tenantId == null || tenantId.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Cannot start chat: missing participant info.')),
                                      );
                                      return;
                                    }
                                    try {
                                      final convId = await FirestoreService.instance.getOrCreateConversation(
                                        propertyId: req.property.id,
                                        propertyTitle: req.property.title,
                                        ownerId: ownerId,
                                        tenantId: tenantId,
                                        tenantName: req.renterName,
                                      );
                                      if (context.mounted) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ChatScreen(
                                              conversation: Conversation(
                                                id: convId,
                                                requestId: convId,
                                                propertyId: req.property.id,
                                                propertyTitle: req.property.title,
                                                ownerId: ownerId,
                                                tenantId: tenantId,
                                                tenantName: req.renterName,
                                                createdAt: DateTime.now(),
                                                updatedAt: DateTime.now(),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to open chat: $e')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                  label: const Text('Chat with Landlord'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.green,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ] else if (req.isPending) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.amberLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.amber.withAlpha(60)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.lock_clock_rounded, size: 14, color: AppColors.amber),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Landlord contact details will be revealed here once accepted.',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.amber),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (req.isRejected) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.errorSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.error.withAlpha(60)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.cancel_outlined, size: 14, color: AppColors.error),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Request declined. Landlord contact details remain private.',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (req.isCancelled) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Request withdrawn. Contact details are unavailable.',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Submitted ${_formatDate(req.requestedAt)}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (req.isPending)
                                  TextButton(
                                    onPressed: () => onCancelRequest(req.id),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.heart,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Withdraw Request', style: TextStyle(fontSize: 12)),
                                  )
                                else if (req.isAccepted)
                                  const Text(
                                    'Accepted by Landlord',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0E5E3B)),
                                  )
                                else if (req.isRejected)
                                  const Text(
                                    'Declined by Landlord',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFC53030)),
                                  )
                                else if (req.isCancelled)
                                  const Text(
                                    'Withdrawn by You',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Landlord Contact Card (Revealed only to tenants with accepted requests)
// ---------------------------------------------------------------------------

class LandlordContactCard extends StatefulWidget {
  const LandlordContactCard({
    super.key,
    required this.propertyId,
    this.landlordNote,
  });

  final String propertyId;
  final String? landlordNote;

  @override
  State<LandlordContactCard> createState() => _LandlordContactCardState();
}

class _LandlordContactCardState extends State<LandlordContactCard> {
  int _retryKey = 0;

  void _retry() {
    setState(() {
      _retryKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey(_retryKey),
      child: StreamBuilder<LandlordContactInfo?>(
        stream: FirestoreService.instance.streamPropertyContactInfo(widget.propertyId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            final isPermissionDenied = error is FirebaseException
                ? error.code == 'permission-denied'
                : error.toString().contains('permission-denied') ||
                    error.toString().contains('Missing or insufficient permissions');

            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.amber.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.amber, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Contact Details Unavailable',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const Text('Retry', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.amber,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPermissionDenied
                        ? 'Contact information is currently restricted or permissions are pending server verification. If your rental request was just accepted, please tap Retry.'
                        : FirestoreService.getFriendlyErrorMessage(error ?? 'An unexpected error occurred.'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.35),
                  ),
                  if (widget.landlordNote != null && widget.landlordNote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Landlord Note: "${widget.landlordNote}"',
                      style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.green.withAlpha(60)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                  ),
                  SizedBox(width: 8),
                  Text('Loading landlord contact details...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            );
          }

          final info = snapshot.data;
          if (info == null || info.isEmpty) {
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkGreen.withAlpha(60)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.darkGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rental Request Accepted!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.landlordNote != null && widget.landlordNote!.isNotEmpty
                              ? 'The landlord has accepted your request. Contact note: "${widget.landlordNote}"'
                              : 'The landlord has accepted your request, but did not provide direct phone/email numbers. Please wait for the landlord to reach out or visit the property.',
                          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.lightGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppColors.darkGreen, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Landlord Contact Details',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.darkGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'UNLOCKED',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Revealed because your rental request was accepted.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),

              if (info.phone != null && info.phone!.trim().isNotEmpty) ...[
                _ContactActionRow(
                  icon: Icons.phone_rounded,
                  label: 'Phone Number',
                  value: info.phone!.trim(),
                  actionLabel: 'Call / Copy',
                  onAction: () {
                    Clipboard.setData(ClipboardData(text: info.phone!.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Phone number copied to clipboard: ${info.phone!.trim()}'),
                        backgroundColor: AppColors.darkGreen,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              if (info.whatsapp != null && info.whatsapp!.trim().isNotEmpty) ...[
                _ContactActionRow(
                  icon: Icons.chat_bubble_rounded,
                  label: 'WhatsApp',
                  value: info.whatsapp!.trim(),
                  actionLabel: 'Copy WhatsApp',
                  onAction: () {
                    Clipboard.setData(ClipboardData(text: info.whatsapp!.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('WhatsApp number copied to clipboard: ${info.whatsapp!.trim()}'),
                        backgroundColor: AppColors.darkGreen,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              if (info.email != null && info.email!.trim().isNotEmpty) ...[
                _ContactActionRow(
                  icon: Icons.email_rounded,
                  label: 'Email Address',
                  value: info.email!.trim(),
                  actionLabel: 'Copy Email',
                  onAction: () {
                    Clipboard.setData(ClipboardData(text: info.email!.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Email address copied to clipboard: ${info.email!.trim()}'),
                        backgroundColor: AppColors.darkGreen,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              if (info.otherLink != null && info.otherLink!.trim().isNotEmpty) ...[
                _ContactActionRow(
                  icon: Icons.link_rounded,
                  label: (info.otherTitle != null && info.otherTitle!.trim().isNotEmpty)
                      ? info.otherTitle!.trim()
                      : 'Other Contact / Link',
                  value: info.otherLink!.trim(),
                  actionLabel: 'Copy Link',
                  onAction: () {
                    Clipboard.setData(ClipboardData(text: info.otherLink!.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Link copied to clipboard: ${info.otherLink!.trim()}'),
                        backgroundColor: AppColors.darkGreen,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
}

class _ContactActionRow extends StatelessWidget {
  const _ContactActionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String label;
  final String value;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                SelectableText(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(40, 32),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Help & Support Bottom Sheet
// ---------------------------------------------------------------------------

class HelpSupportSheet extends StatelessWidget {
  const HelpSupportSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.help_outline, color: AppColors.green),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _faqItem(
              question: 'How do I search for homes in my preferred area?',
              answer:
                  'Use the search bar on the Home tab to enter areas like Mirpur, Dhanmondi, or Sylhet, or landmarks like Metro rail stations. Tap filter chips (Bachelor, Family, Shared) to refine your search.',
            ),
            _faqItem(
              question: 'How does the "Request to Rent" feature work?',
              answer:
                  'When viewing any property details, tap "Request to Rent" at the bottom. Enter your preferred move-in date and contact number. In this demo milestone, requests are safely stored locally on your device under My Activity.',
            ),
            _faqItem(
              question: 'How do I list my rental property?',
              answer:
                  'Tap the "Post" tab on the bottom navigation bar. Complete the 5-step wizard with your property details, rent, and photos. Submitted listings are placed under "Pending Review" in your My Listings tab.',
            ),
            _faqItem(
              question: 'Is BashaLagbe free for renters and students?',
              answer:
                  'Yes! BashaLagbe is created to eliminate expensive broker commissions for bachelors, students, and families across Bangladesh.',
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.headset_mic_outlined, color: AppColors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live 24/7 hotline and chat support will launch alongside the public release. No real phone calls or messages are active in this demo.',
                      style: TextStyle(fontSize: 12, color: AppColors.darkGreen, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _faqItem({required String question, required String answer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              answer,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About BashaLagbe Bottom Sheet
// ---------------------------------------------------------------------------

class AboutBashaLagbeSheet extends StatelessWidget {
  const AboutBashaLagbeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.home_work, color: AppColors.green, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BashaLagbe',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'About the Project',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'BashaLagbe is an Android-first rental house discovery app designed for Bangladesh. It connects tenants with verified rental apartments, bachelor rooms, and shared mess seats without wasting money on middleman fees and unnecessary physical visits.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 14),
            const Text(
              'Technology Stack',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              '• Flutter SDK with Material 3 Design\n• Google Firebase Authentication & Cloud Firestore\n• Cloudinary Cloud Media Services\n• Responsive layout for Mobile & Web (Google Chrome)',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy Policy & Terms Bottom Sheet
// ---------------------------------------------------------------------------

class PrivacyTermsSheet extends StatelessWidget {
  const PrivacyTermsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.policy_outlined, color: AppColors.green),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Privacy Policy & Terms',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.green.withAlpha(90)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: AppColors.green, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'BashaLagbe is committed to protecting your privacy and providing a secure platform for finding and listing rental homes across Bangladesh.',
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: '1. Service Overview',
              content:
                  'BashaLagbe connects prospective tenants with property owners and landlords in Bangladesh. We provide digital listings, verified property attributes, secure rental request workflows, and private real-time messaging between matched parties.',
            ),
            _buildSection(
              title: '2. Data Collection & Authentication',
              content:
                  'We use Google Firebase Authentication for account management. When you register or sign in, we process your email address, display name, and authentication tokens. Password credentials are encrypted and stored exclusively by Google Firebase and are never accessible to BashaLagbe administrators.',
            ),
            _buildSection(
              title: '3. Cloud Storage & Media Services',
              content:
                  'Property listings, rental inquiries, user profiles, and chat conversations are stored securely in Google Cloud Firestore (project: bashalagbe-f9595). Property photographs uploaded by landlords are processed, optimized, and hosted via Cloudinary media delivery services under secure CDN delivery.',
            ),
            _buildSection(
              title: '4. Contact Privacy & Tenant Protection',
              content:
                  'Landlord direct phone numbers and contact details are stored in an isolated, access-controlled database subcollection. They are never published publicly. Only authenticated tenants whose rental requests have been explicitly accepted by the property owner are granted access to landlord contact information.',
            ),
            _buildSection(
              title: '5. User Data Rights & Account Deletion',
              content:
                  'You retain full control over your personal data. You may edit your profile at any time. You may also permanently delete your account and associated profile data directly within the app using the "Delete Account" button in your profile settings. Upon deletion, your account and profile records are erased from our authentication and database systems.',
            ),
            _buildSection(
              title: '6. Prohibited Content & Listing Integrity',
              content:
                  'Users agree not to submit fraudulent, misleading, or unauthorized property listings, spam, abusive messages, or harmful material. BashaLagbe moderators reserve the right to review, reject, or remove any listing or suspend accounts violating these standards.',
            ),
            _buildSection(
              title: '7. Disclaimer of Liability',
              content:
                  'While BashaLagbe performs administrative moderation on listings, users are advised to exercise ordinary due diligence before executing tenancy contracts or transferring rental deposits. BashaLagbe is not a party to rental agreements formed between landlords and tenants.',
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Last updated: October 2026 • Version 1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
