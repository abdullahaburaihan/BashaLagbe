import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/property_details_screen.dart';
import 'package:basha_lagbe/services/firestore_service.dart';

/// Protected Admin Moderation Dashboard.
///
/// Strictly authorizes users against the `/admins/{uid}` Firestore roster.
/// Allows administrators to view pending property listings across all owners,
/// inspect listing details, and approve or reject listings with required moderation notes.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    this.firestoreService,
    this.currentUser,
  });

  final FirestoreService? firestoreService;
  final User? currentUser;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  FirestoreService get _service => widget.firestoreService ?? FirestoreService.instance;
  User? get _user => widget.currentUser ?? FirebaseAuth.instance.currentUser;

  String? _processingPropertyId;

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return _buildAccessDenied('Please sign in to access the administrator dashboard.');
    }

    return StreamBuilder<bool>(
      stream: _service.streamIsAdmin(user.uid),
      builder: (context, adminSnapshot) {
        if (adminSnapshot.connectionState == ConnectionState.waiting && !adminSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (adminSnapshot.hasError) {
          return _buildAccessDenied(
            'Unable to verify administrative privileges at this time. Please check your network connection or contact support.',
          );
        }

        final isAdmin = adminSnapshot.data == true;
        if (!isAdmin) {
          return _buildAccessDenied(
            'Access Restricted: Your account (${user.email ?? user.uid}) does not have administrative moderation privileges.',
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.admin_panel_settings, color: AppColors.green),
                SizedBox(width: 8),
                Text('Admin Moderation'),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            shape: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            centerTitle: true,
          ),
          body: StreamBuilder<List<Property>>(
            stream: _service.streamPendingProperties(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.heart),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading pending listings:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final pending = snapshot.data ?? [];
              if (pending.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: AppColors.lightGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: AppColors.green,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'All Caught Up!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'There are no pending property listings awaiting moderation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: pending.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final prop = pending[index];
                  return _buildPendingPropertyCard(prop);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAccessDenied(String reason) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.heart.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gpp_bad,
                  size: 64,
                  color: AppColors.heart,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Unauthorized Access',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Return to App'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPropertyCard(Property prop) {
    final isProcessing = _processingPropertyId == prop.id;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: prop.photos.isNotEmpty && prop.photos.first.imageUrl != null
                        ? Image.network(
                            prop.photos.first.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildFallbackThumbnail(prop),
                          )
                        : _buildFallbackThumbnail(prop),
                  ),
                ),
                const SizedBox(width: 14),
                // Title, Rent, Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.amberLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.amber,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '৳${prop.rentPerMonth}/mo',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        prop.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${prop.area}${prop.landmark.isNotEmpty ? " • ${prop.landmark}" : ""}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Metadata: Owner UID, Bedrooms, Bathrooms, Type
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildMetadataChip(
                  Icons.category_outlined,
                  prop.type.name.toUpperCase(),
                ),
                _buildMetadataChip(
                  Icons.king_bed_outlined,
                  '${prop.bedrooms} Bed',
                ),
                _buildMetadataChip(
                  Icons.bathtub_outlined,
                  '${prop.bathrooms} Bath',
                ),
                if (prop.ownerId != null && prop.ownerId!.isNotEmpty)
                  _buildMetadataChip(
                    Icons.badge_outlined,
                    'Owner: ${prop.ownerId!.length > 12 ? "${prop.ownerId!.substring(0, 10)}…" : prop.ownerId}',
                  ),
              ],
            ),

            if (prop.facilities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: prop.facilities.take(4).map((f) => Chip(
                  label: Text(f, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.lightGreen.withValues(alpha: 0.5),
                  side: BorderSide.none,
                )).toList(),
              ),
            ],

            const SizedBox(height: 12),
            // Actions Row
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PropertyDetailsScreen(
                                property: prop,
                                favouriteIds: const {},
                                onToggleFavourite: (_) {},
                                onRentalRequestSubmitted: (_) {},
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Review'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const Spacer(),
                if (isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () => _handleReject(prop),
                    icon: const Icon(Icons.close, size: 16, color: AppColors.heart),
                    label: const Text('Reject', style: TextStyle(color: AppColors.heart)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.heart),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _handleApprove(prop),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(Property prop) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [prop.gradientStart, prop.gradientEnd],
        ),
      ),
      child: Center(
        child: Icon(prop.icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildMetadataChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(Property prop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Approve Property Listing?'),
        content: Text(
          'Are you sure you want to approve "${prop.title}"? It will become publicly visible to all renters immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingPropertyId = prop.id);
    try {
      await _service.approvePropertyAsAdmin(propertyId: prop.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Property "${prop.title}" approved successfully.'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve property: $e'),
            backgroundColor: AppColors.heart,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingPropertyId = null);
      }
    }
  }

  Future<void> _handleReject(Property prop) async {
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject Property Listing'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting "${prop.title}". Please provide a clear moderation note explaining what must be corrected.',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'e.g. Photos are too low quality, or address requires more detail.',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'A moderation note is required.';
                  }
                  if (text.length > 500) {
                    return 'Note cannot exceed 500 characters.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogCtx).pop(true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.heart),
            child: const Text('Reject Listing'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final note = noteController.text.trim();
    setState(() => _processingPropertyId = prop.id);
    try {
      await _service.rejectPropertyAsAdmin(
        propertyId: prop.id,
        moderationNote: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Property "${prop.title}" rejected with note.'),
            backgroundColor: AppColors.heart,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject property: $e'),
            backgroundColor: AppColors.heart,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingPropertyId = null);
      }
    }
  }
}
