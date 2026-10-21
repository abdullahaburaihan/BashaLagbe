import 'package:flutter/material.dart';
import 'package:basha_lagbe/main.dart';

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
  });

  final String id;
  final Property property;
  final String renterName;
  final String renterPhone;
  final String preferredMoveIn;
  final String message;
  final DateTime requestedAt;
  final String status;
}

// ---------------------------------------------------------------------------
// Main Profile Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
    required this.listingsCount,
    required this.savedCount,
    required this.rentalRequests,
    required this.onCancelRentalRequest,
    required this.onNavigateToMyListings,
    required this.onNavigateToSaved,
    required this.onNavigateToHome,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onProfileUpdated;
  final int listingsCount;
  final int savedCount;
  final List<RentalRequest> rentalRequests;
  final ValueChanged<String> onCancelRentalRequest;
  final VoidCallback onNavigateToMyListings;
  final VoidCallback onNavigateToSaved;
  final VoidCallback onNavigateToHome;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;

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
          onCancelRequest: (requestId) {
            widget.onCancelRentalRequest(requestId);
            Navigator.of(modalContext).pop();
            showFriendlyMessage(context, 'Rental request withdrawn.');
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
    final profile = widget.profile;

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
                      const Text(
                        'Manage your demo account and view all your rental activity.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // -------------------------------------------------------------
              // Profile Identity Card
              // -------------------------------------------------------------
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
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
                                  profile.name.trim().isNotEmpty
                                      ? profile.name.trim().substring(0, 1).toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Name & Role
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          profile.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightGreen,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      profile.role,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 14),

                        // Contact Info
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 16, color: AppColors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                profile.email,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 16, color: AppColors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                profile.phone,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Demo profile disclosure notice
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.amberLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: AppColors.amber),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Demo Profile: Saved locally in-memory for testing.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Edit Profile Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openEditProfileSheet,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.darkGreen,
                              side: const BorderSide(color: AppColors.green),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text(
                              'Edit Profile Details',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                                'Demo Mode • Push & SMS alerts for new listings',
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
                                      ? 'Notification alerts enabled (Demo mode).'
                                      : 'Notification alerts paused (Demo mode).',
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
                              subtitle: 'Official legal documents placeholder',
                              onTap: _showPrivacyTermsDialog,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Version tag
                      const Center(
                        child: Text(
                          'BashaLagbe v1.0.0 (Demo Preview)\nBuilt with Flutter • Material 3',
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
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: AppColors.lightGreen,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.green, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: Row(
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
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: AppColors.lightGreen,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.green, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
      onTap: onTap,
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

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      final updated = widget.profile.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      );
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
                      'Edit Demo Profile',
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
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.amber.withAlpha(90)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppColors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Local Demo Mode: Changes are preserved locally while the app is running. This is not tied to a remote backend.',
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
  });

  final List<RentalRequest> rentalRequests;
  final ValueChanged<String> onCancelRequest;
  final VoidCallback onExploreHomes;

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
                      '${rentalRequests.length} active demo request${rentalRequests.length == 1 ? '' : 's'}',
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.amberLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.schedule, size: 12, color: AppColors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        req.status,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
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
                                const Spacer(),
                                Text(
                                  'Move-in: ${req.preferredMoveIn}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
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
                                  'Note: "${req.message}"',
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textDark),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tracking: ${req.id}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                                TextButton(
                                  onPressed: () => onCancelRequest(req.id),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.heart,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Withdraw Request', style: TextStyle(fontSize: 12)),
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
                const Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BashaLagbe',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  Text(
                    'Version 1.0.0 (Demo Preview)',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const Spacer(),
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
            '• Flutter SDK with Material 3 Design\n• Responsive layout for Mobile & Web (Google Chrome)\n• Modular local state architecture\n• Backend & Firebase integration scheduled for future milestones',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 20),
        ],
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              const Text(
                'Privacy Policy & Terms',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
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
              color: AppColors.amberLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amber.withAlpha(90)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gavel, color: AppColors.amber, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Official Legal Documents Notice: Formal Terms of Service and Privacy Policy agreements are currently being drafted for the official Google Play release and are not yet available.',
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Demo Privacy Guarantee',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'In this milestone preview, all profile details, saved properties, posted listings, and rental inquiries are stored strictly on your local device. No personal information or tracking telemetry is transmitted to external servers.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
