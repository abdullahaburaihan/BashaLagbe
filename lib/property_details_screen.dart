import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:basha_lagbe/auth_sheet.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/profile_screen.dart';
import 'package:basha_lagbe/services/firestore_service.dart';

// ---------------------------------------------------------------------------
// Property Photo Model
// Designed so real uploaded photos (network URL or asset) can replace
// demo illustrations in future milestones without changing the screen layout.
// ---------------------------------------------------------------------------

class PropertyPhoto {
  const PropertyPhoto({
    required this.label,
    this.imageUrl,
    this.storagePath,
    this.isCover = false,
    this.order = 0,
    this.assetPath,
    this.icon = Icons.home_outlined,
    this.gradientStart,
    this.gradientEnd,
  });

  final String label;
  final String? imageUrl;
  final String? storagePath;
  final bool isCover;
  final int order;
  final String? assetPath;
  final IconData icon;
  final Color? gradientStart;
  final Color? gradientEnd;

  bool get isNetworkPhoto => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isAssetPhoto => assetPath != null && assetPath!.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Property Details Screen
// ---------------------------------------------------------------------------

class PropertyDetailsScreen extends StatefulWidget {
  const PropertyDetailsScreen({
    super.key,
    required this.property,
    required this.favouriteIds,
    required this.onToggleFavourite,
    this.onRentalRequestSubmitted,
    this.firebaseUser,
    this.onRequireSignIn,
  });

  final Property property;
  final Set<String> favouriteIds;
  final ValueChanged<String> onToggleFavourite;
  final ValueChanged<RentalRequest>? onRentalRequestSubmitted;
  final User? firebaseUser;
  final VoidCallback? onRequireSignIn;

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final PageController _pageController = PageController();
  int _currentPhotoIndex = 0;
  bool _requestSubmittedLocally = false;
  bool _hasActiveCloudRequest = false;
  StreamSubscription<RentalRequest?>? _tenantRequestSub;
  RentalRequest? _tenantRequest;

  @override
  void initState() {
    super.initState();
    _checkExistingActiveRequest();
    _subscribeToTenantRequest();
  }

  @override
  void didUpdateWidget(covariant PropertyDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseUser != widget.firebaseUser ||
        oldWidget.property.id != widget.property.id) {
      _checkExistingActiveRequest();
      _subscribeToTenantRequest();
    }
  }

  void _subscribeToTenantRequest() {
    _tenantRequestSub?.cancel();
    final user = _currentUser;
    if (user == null || widget.property.isDemo || _isOwner) {
      if (mounted) {
        setState(() {
          _tenantRequest = null;
        });
      }
      return;
    }

    _tenantRequestSub = FirestoreService.instance
        .streamTenantRentalRequest(
          propertyId: widget.property.id,
          tenantId: user.uid,
        )
        .listen(
          (req) {
            if (mounted) {
              setState(() {
                _tenantRequest = req;
                if (req != null) {
                  _hasActiveCloudRequest = req.isPending || req.isAccepted;
                }
              });
            }
          },
          onError: (e) {
            debugPrint('PropertyDetailsScreen streamTenantRentalRequest error: $e');
          },
        );
  }

  User? get _currentUser {
    if (widget.firebaseUser != null) return widget.firebaseUser;
    if (FirestoreService.instance.isFirebaseAvailable) {
      try {
        return FirebaseAuth.instance.currentUser;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool get _isOwner {
    final user = _currentUser;
    if (user == null) return false;
    final ownerId = widget.property.ownerId;
    return ownerId != null && ownerId.isNotEmpty && ownerId == user.uid;
  }

  Future<void> _checkExistingActiveRequest() async {
    final user = _currentUser;
    if (user == null || widget.property.isDemo || _isOwner) return;

    try {
      final hasActive = await FirestoreService.instance.hasActiveRentalRequest(
        propertyId: widget.property.id,
        tenantId: user.uid,
      );
      if (mounted) {
        setState(() {
          _hasActiveCloudRequest = hasActive;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tenantRequestSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<PropertyPhoto> get _photos {
    if (widget.property.photos.isNotEmpty) {
      final validPhotos = widget.property.photos
          .where((p) => p.isNetworkPhoto || p.isAssetPhoto)
          .toList();
      if (validPhotos.isNotEmpty) {
        return validPhotos;
      }
    }
    // Fallback gallery if property has no explicit photos list or only legacy null-URL placeholders
    return [
      PropertyPhoto(
        label: 'Main Living Space',
        imageUrl:
            'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1200&auto=format&fit=crop&q=80',
        icon: widget.property.icon,
        gradientStart: widget.property.gradientStart,
        gradientEnd: widget.property.gradientEnd,
      ),
      PropertyPhoto(
        label: 'Bedrooms',
        imageUrl:
            'https://images.unsplash.com/photo-1540518614846-7ede433c4550?w=1200&auto=format&fit=crop&q=80',
        icon: Icons.bed_outlined,
        gradientStart: widget.property.gradientStart.withAlpha(200),
        gradientEnd: widget.property.gradientEnd.withAlpha(230),
      ),
      PropertyPhoto(
        label: 'Washroom & Kitchen',
        imageUrl:
            'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=1200&auto=format&fit=crop&q=80',
        icon: Icons.kitchen_outlined,
        gradientStart: widget.property.gradientEnd,
        gradientEnd: widget.property.gradientStart,
      ),
      PropertyPhoto(
        label: 'Balcony & View',
        imageUrl:
            'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1200&auto=format&fit=crop&q=80',
        icon: Icons.balcony_outlined,
        gradientStart: widget.property.gradientStart,
        gradientEnd: widget.property.gradientEnd,
      ),
    ];
  }

  void _handleFavouriteTap() {
    setState(() {
      widget.onToggleFavourite(widget.property.id);
    });
  }

  void _promptSignIn(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.green),
            SizedBox(width: 8),
            Text('Sign In Required'),
          ],
        ),
        content: const Text(
          'You need to sign in to send a rental request to the landlord and track its status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              if (widget.onRequireSignIn != null) {
                widget.onRequireSignIn!();
              } else {
                AuthSheet.show(context);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showRequestToRentModal(BuildContext context) {
    final user = _currentUser;

    if (_isOwner) {
      showFriendlyMessage(
        context,
        'You are the owner of this property. Manage it from My Listings.',
      );
      return;
    }

    if (_hasActiveCloudRequest) {
      showFriendlyMessage(
        context,
        'Your rental request for this property is pending landlord review.',
      );
      return;
    }

    // Requirement 1: Require sign in for real cloud properties
    if (!widget.property.isDemo && user == null) {
      _promptSignIn(context);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return RequestToRentSheet(
          property: widget.property,
          currentUser: user,
          onRequireSignIn: () {
            Navigator.of(modalContext).pop();
            _promptSignIn(context);
          },
          onSubmitted: (request) {
            setState(() {
              if (request.isDemo) {
                _requestSubmittedLocally = true;
              } else {
                _hasActiveCloudRequest = true;
              }
            });
            widget.onRentalRequestSubmitted?.call(request);
            Navigator.of(modalContext).pop();
            if (request.isDemo) {
              showFriendlyMessage(
                context,
                'Demo request saved locally. Landlords will receive notifications in future milestones.',
              );
            } else {
              showFriendlyMessage(
                context,
                'Rental request sent to landlord! You can track its status in your Profile.',
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final isFavourite = widget.favouriteIds.contains(property.id);
    final photos = _photos;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // -----------------------------------------------------------------
          // App Bar with Photo Gallery
          // -----------------------------------------------------------------
          SliverAppBar(
            expandedHeight: 310,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.darkGreen,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black.withAlpha(90),
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withAlpha(90),
                  child: IconButton(
                    tooltip: 'Share listing',
                    icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                    onPressed: () {
                      showFriendlyMessage(
                        context,
                        'Listing link copied to clipboard.',
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withAlpha(90),
                  child: IconButton(
                    tooltip: isFavourite ? 'Remove from saved' : 'Save this home',
                    icon: Icon(
                      isFavourite ? Icons.favorite : Icons.favorite_border,
                      color: isFavourite ? AppColors.heart : Colors.white,
                      size: 22,
                    ),
                    onPressed: _handleFavouriteTap,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // 1. Photo ViewPager with mouse & touch drag support
                  Positioned.fill(
                    child: ScrollConfiguration(
                      behavior: const MaterialScrollBehavior().copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.stylus,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: photos.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPhotoIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          return _GalleryPhotoItem(
                            photo: photo,
                            defaultStart: property.gradientStart,
                            defaultEnd: property.gradientEnd,
                          );
                        },
                      ),
                    ),
                  ),

                  // 2. Top gradient overlay to ensure top icons remain legible (IgnorePointer so it never blocks swipe)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x99000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Desktop/Web Navigation Arrows (< and > buttons)
                  if (_currentPhotoIndex > 0)
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Material(
                          color: Colors.black.withAlpha(130),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_currentPhotoIndex < photos.length - 1)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Material(
                          color: Colors.black.withAlpha(130),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 4. Bottom info banner (Counter + Photo label + Interactive dots)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  '${_currentPhotoIndex + 1} / ${photos.length} • ${photos[_currentPhotoIndex].label}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Page indicators (interactive clickable dots)
                        Row(
                          children: List.generate(photos.length, (dotIndex) {
                            final isActive = dotIndex == _currentPhotoIndex;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _pageController.animateToPage(
                                  dotIndex,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: isActive ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.white : Colors.white54,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // -----------------------------------------------------------------
          // Listing Details Content
          // -----------------------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (property.isDemo) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.amberLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.amber.withAlpha(90)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Demo Preview Listing — Fictional demonstration listing for preview purposes only.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Rent + Type Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        formatTaka(property.rentPerMonth),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '/ month',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      InfoPill(
                        icon: Icons.sell_outlined,
                        label: property.type.label,
                        background: AppColors.lightGreen,
                        foreground: AppColors.darkGreen,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 20, color: AppColors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          property.fullAddress ?? property.area,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (property.landmark.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.near_me_outlined, size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Landmark: ${property.landmark}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ---------------------------------------------------------
                  // Rent & Deposit Financial Breakdown Card
                  // ---------------------------------------------------------
                  _SectionCard(
                    title: 'Financial Breakdown',
                    icon: Icons.account_balance_wallet_outlined,
                    child: Column(
                      children: [
                        _FinancialRow(
                          title: 'Monthly Rent',
                          amount: formatTaka(property.rentPerMonth),
                          subtitle: 'Due by the 5th of each calendar month',
                        ),
                        const Divider(height: 18, color: AppColors.border),
                        _FinancialRow(
                          title: 'Security Deposit',
                          amount: property.depositAmount != null
                              ? formatTaka(property.depositAmount!)
                              : formatTaka(property.rentPerMonth * 2),
                          subtitle: 'Refundable at move-out as per lease agreement',
                          amountColor: AppColors.darkGreen,
                        ),
                        const Divider(height: 18, color: AppColors.border),
                        _FinancialRow(
                          title: 'Utilities & Bills',
                          amount: 'Notice below',
                          subtitle: property.utilityNotice,
                          isAmountHighlighted: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ---------------------------------------------------------
                  // Key Specifications
                  // ---------------------------------------------------------
                  _SectionCard(
                    title: 'Property Specifications',
                    icon: Icons.tune_outlined,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _SpecTile(
                          icon: Icons.bed_outlined,
                          title: '${property.bedrooms} Bedrooms',
                          subtitle: 'Well-ventilated',
                        ),
                        _SpecTile(
                          icon: Icons.bathtub_outlined,
                          title: '${property.bathrooms} Bathrooms',
                          subtitle: 'Tiled & clean',
                        ),
                        _SpecTile(
                          icon: Icons.balcony_outlined,
                          title: '${property.balconies} Balconies',
                          subtitle: 'Open airflow',
                        ),
                        if (property.sizeSqFt != null)
                          _SpecTile(
                            icon: Icons.square_foot_outlined,
                            title: '${property.sizeSqFt} sq ft',
                            subtitle: 'Super built-up',
                          ),
                        _SpecTile(
                          icon: Icons.layers_outlined,
                          title: property.floorLevel,
                          subtitle: 'Building floor',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ---------------------------------------------------------
                  // Availability & Tenant Suitability
                  // ---------------------------------------------------------
                  _SectionCard(
                    title: 'Availability & Preferences',
                    icon: Icons.event_available_outlined,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: property.availableNow
                                    ? AppColors.lightGreen
                                    : AppColors.amberLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                property.availableNow
                                    ? Icons.check_circle_outline
                                    : Icons.schedule_outlined,
                                color: property.availableNow
                                    ? AppColors.darkGreen
                                    : AppColors.amber,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    property.availability,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: property.availableNow
                                          ? AppColors.darkGreen
                                          : AppColors.amber,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    property.availableNow
                                        ? 'Ready for immediate occupancy.'
                                        : 'Available soon for viewing and booking.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_alt_outlined, size: 18, color: AppColors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Preferred Renters: ${property.type.label} tenants',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ---------------------------------------------------------
                  // Facilities & Amenities
                  // ---------------------------------------------------------
                  _SectionCard(
                    title: 'Facilities & Amenities',
                    icon: Icons.star_outline,
                    child: property.facilities.isEmpty
                        ? const Text(
                            'Standard residential utilities available.',
                            style: TextStyle(color: AppColors.textMuted),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 10,
                            children: property.facilities.map((facility) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGreen.withAlpha(120),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: AppColors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      facility,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  const SizedBox(height: 18),

                  // ---------------------------------------------------------
                  // About & Description
                  // ---------------------------------------------------------
                  if (property.description.isNotEmpty) ...[
                    _SectionCard(
                      title: 'About This Property',
                      icon: Icons.description_outlined,
                      child: Text(
                        property.description,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.55,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ---------------------------------------------------------
                  // Nearby Highlights
                  // ---------------------------------------------------------
                  if (property.nearbyHighlights.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Location Highlights',
                      icon: Icons.map_outlined,
                      child: Column(
                        children: property.nearbyHighlights.map((highlight) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.directions_walk,
                                  size: 18,
                                  color: AppColors.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    highlight,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ---------------------------------------------------------
                  // Landlord Contact Details & Request Status
                  // ---------------------------------------------------------
                  if (!widget.property.isDemo && !_isOwner) ...[
                    if (_tenantRequest != null && _tenantRequest!.isAccepted) ...[
                      LandlordContactCard(
                        propertyId: widget.property.id,
                        landlordNote: _tenantRequest!.landlordNote,
                      ),
                      const SizedBox(height: 18),
                    ] else if (_tenantRequest != null && _tenantRequest!.isPending) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.amberLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.amber.withAlpha(80)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_clock_rounded, color: AppColors.amber, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rental Request Pending Landlord Review',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'You submitted a rental request for this home. The landlord\'s phone, WhatsApp, and email will be revealed here as soon as they accept your request.',
                                    style: TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else if (_tenantRequest != null && _tenantRequest!.isRejected) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.errorSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.error.withAlpha(80)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Previous Request Declined',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _tenantRequest!.landlordNote != null && _tenantRequest!.landlordNote!.isNotEmpty
                                        ? 'Landlord note: "${_tenantRequest!.landlordNote}"'
                                        : 'The landlord declined your previous request. Direct contact details remain protected.',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, color: AppColors.green, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Landlord Contact Privacy',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkGreen,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'To prevent spam and protect landlord privacy, contact details remain hidden. Click "Request to Rent" below to send a formal application. Once accepted, all contact methods will be unlocked.',
                                    style: TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],

                  // ---------------------------------------------------------
                  // Demo Notice (shown only for demo previews)
                  // ---------------------------------------------------------
                  if (widget.property.isDemo) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.amberLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.amber.withAlpha(70)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.amber, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Demo Listing Notice: All specifications, photos and contact prompts are local simulations for preview. Real listings will be verified in future milestones.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // ---------------------------------------------------------------------
      // Sticky Bottom Action Bar
      // ---------------------------------------------------------------------
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
          border: const Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTaka(property.rentPerMonth),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
                Text(
                  property.depositAmount != null
                      ? 'Deposit: ${formatTaka(property.depositAmount!)}'
                      : 'Deposit: 2 Months',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isOwner
                    ? () {
                        showFriendlyMessage(
                          context,
                          'You are the owner of this property. Manage it from My Listings.',
                        );
                      }
                    : (_tenantRequest?.isAccepted == true
                        ? () {
                            showFriendlyMessage(
                              context,
                              'Landlord accepted your rental request! Contact details are displayed above.',
                            );
                          }
                        : (_hasActiveCloudRequest
                            ? () {
                                showFriendlyMessage(
                                  context,
                                  'Your rental request for this property is pending landlord review.',
                                );
                              }
                            : () => _showRequestToRentModal(context))),
                style: FilledButton.styleFrom(
                  backgroundColor: _isOwner
                      ? Colors.grey.shade400
                      : (_tenantRequest?.isAccepted == true
                          ? AppColors.darkGreen
                          : (_hasActiveCloudRequest || _requestSubmittedLocally
                              ? AppColors.darkGreen
                              : AppColors.green)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(
                  _isOwner
                      ? Icons.home_work_outlined
                      : (_tenantRequest?.isAccepted == true
                          ? Icons.verified_user_rounded
                          : (_hasActiveCloudRequest || _requestSubmittedLocally
                              ? Icons.check_circle_outline
                              : Icons.send_outlined)),
                  size: 20,
                ),
                label: Text(
                  _isOwner
                      ? 'Your Property (Owner)'
                      : (_tenantRequest?.isAccepted == true
                          ? 'Request Accepted (Contact Above)'
                          : (_hasActiveCloudRequest
                              ? 'Request Sent (Pending)'
                              : (_requestSubmittedLocally
                                  ? 'Request Sent (Demo)'
                                  : (_tenantRequest?.isRejected == true
                                      ? 'Re-apply for Rent'
                                      : 'Request to Rent')))),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gallery Photo Item (Supports future uploaded URLs or local illustrations)
// ---------------------------------------------------------------------------

class _GalleryPhotoItem extends StatelessWidget {
  const _GalleryPhotoItem({
    required this.photo,
    required this.defaultStart,
    required this.defaultEnd,
  });

  final PropertyPhoto photo;
  final Color defaultStart;
  final Color defaultEnd;

  Widget _decorativeCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x22FFFFFF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If photo provides a network photo URL
    if (photo.isNetworkPhoto) {
      return Image.network(
        photo.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppColors.background,
            child: Center(
              child: SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppColors.green,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackIllustration(isError: true),
      );
    }

    // If future milestone provides local asset photo
    if (photo.isAssetPhoto) {
      return Image.asset(
        photo.assetPath!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackIllustration(isError: true),
      );
    }

    // Fallback illustration
    return _buildFallbackIllustration();
  }

  Widget _buildFallbackIllustration({bool isError = false}) {
    final startColor = photo.gradientStart ?? defaultStart;
    final endColor = photo.gradientEnd ?? defaultEnd;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -30, top: 20, child: _decorativeCircle(160)),
          Positioned(left: -40, bottom: -20, child: _decorativeCircle(180)),
          Positioned(left: 60, top: 80, child: _decorativeCircle(40)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.broken_image_outlined : photo.icon,
                  size: 64,
                  color: const Color(0xEEFFFFFF),
                ),
                const SizedBox(height: 10),
                Text(
                  photo.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                if (isError) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Photo preview offline',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable Section Card
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.green),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Specification Tile
// ---------------------------------------------------------------------------

class _SpecTile extends StatelessWidget {
  const _SpecTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.green),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Financial Breakdown Row
// ---------------------------------------------------------------------------

class _FinancialRow extends StatelessWidget {
  const _FinancialRow({
    required this.title,
    required this.amount,
    required this.subtitle,
    this.amountColor = AppColors.darkGreen,
    this.isAmountHighlighted = true,
  });

  final String title;
  final String amount;
  final String subtitle;
  final Color amountColor;
  final bool isAmountHighlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          amount,
          style: TextStyle(
            fontSize: isAmountHighlighted ? 16 : 13,
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// "Request to Rent" Interactive Modal Bottom Sheet
// Supports local demo mode for demo listings and real Firestore submission
// for live cloud property listings.
// ---------------------------------------------------------------------------

class RequestToRentSheet extends StatefulWidget {
  const RequestToRentSheet({
    super.key,
    required this.property,
    required this.onSubmitted,
    this.currentUser,
    this.onRequireSignIn,
  });

  final Property property;
  final ValueChanged<RentalRequest> onSubmitted;
  final User? currentUser;
  final VoidCallback? onRequireSignIn;

  @override
  State<RequestToRentSheet> createState() => _RequestToRentSheetState();
}

class _RequestToRentSheetState extends State<RequestToRentSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final TextEditingController _noteController = TextEditingController();

  String _selectedMoveIn = 'Immediate';
  final List<String> _moveInOptions = [
    'Immediate',
    '1st of next month',
    '15th of next month',
  ];

  bool _isSubmitting = false;
  String? _nameError;
  String? _phoneError;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialName = widget.currentUser?.displayName?.trim();
    _nameController = TextEditingController(
      text: (initialName != null && initialName.isNotEmpty)
          ? initialName
          : (widget.property.isDemo ? 'Demo Renter' : ''),
    );
    final initialPhone = widget.currentUser?.phoneNumber?.trim();
    _phoneController = TextEditingController(
      text: (initialPhone != null && initialPhone.isNotEmpty)
          ? initialPhone
          : (widget.property.isDemo ? '01700000000' : ''),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final message = _noteController.text.trim();
    final moveIn = _selectedMoveIn.trim();

    setState(() {
      _nameError = null;
      _phoneError = null;
      _errorMessage = null;
    });

    bool hasValidationError = false;
    if (name.isEmpty) {
      _nameError = 'Please enter your full name.';
      hasValidationError = true;
    }

    if (phone.isEmpty) {
      _phoneError = 'Please enter a contact phone number.';
      hasValidationError = true;
    } else if (phone.length < 6) {
      _phoneError = 'Please enter a valid phone number (at least 6 digits).';
      hasValidationError = true;
    }

    if (moveIn.isEmpty) {
      _errorMessage = 'Please select a preferred move-in date.';
      hasValidationError = true;
    }

    if (hasValidationError) {
      setState(() {});
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // 1. Demo property fallback: preserve local in-memory submission
    if (widget.property.isDemo) {
      final demoRequest = RentalRequest(
        id: 'REQ-${DateTime.now().millisecondsSinceEpoch % 10000}',
        property: widget.property,
        renterName: name,
        renterPhone: phone,
        preferredMoveIn: moveIn,
        message: message,
        requestedAt: DateTime.now(),
        status: 'Pending Landlord Response',
        isDemo: true,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        widget.onSubmitted(demoRequest);
      }
      return;
    }

    // 2. Real cloud property: authenticate & submit to Cloud Firestore
    final user = widget.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'You must be signed in to submit a rental request.';
        });
        widget.onRequireSignIn?.call();
      }
      return;
    }

    final ownerId = widget.property.ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'This listing is missing landlord identification.';
        });
      }
      return;
    }

    if (user.uid == ownerId) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'You cannot submit a rental request for your own property.';
        });
      }
      return;
    }

    try {
      final docId = await FirestoreService.instance.createRentalRequest(
        propertyId: widget.property.id,
        ownerId: ownerId,
        tenantId: user.uid,
        tenantEmail: user.email ?? '',
        tenantName: name,
        tenantPhone: phone,
        preferredMoveIn: moveIn,
        message: message,
        propertyTitle: widget.property.title,
        propertyArea: widget.property.area,
        rentPerMonth: widget.property.rentPerMonth,
        propertyPhotoUrl: widget.property.photos.isNotEmpty
            ? widget.property.photos.first.imageUrl
            : null,
      );

      final realRequest = RentalRequest(
        id: docId,
        property: widget.property,
        renterName: name,
        renterPhone: phone,
        preferredMoveIn: moveIn,
        message: message,
        requestedAt: DateTime.now(),
        status: 'pending',
        ownerId: ownerId,
        tenantId: user.uid,
        tenantEmail: user.email,
        isDemo: false,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        widget.onSubmitted(realRequest);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = FirestoreService.getFriendlyErrorMessage(e);
        });
      }
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
                        'Request to Rent',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        widget.property.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
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

            // Informational Notice Banner
            if (widget.property.isDemo)
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
                        'Local Demo Notice: This request is stored locally on this device only. No SMS, phone call, or message will be sent to real landlords.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.green.withAlpha(80)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 20, color: AppColors.darkGreen),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Direct Landlord Request: Your rental application will be delivered securely to the property owner for review.',
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

            // Inline Error Banner
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withAlpha(120)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 20, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Renter Name Field
            const Text(
              'Your Full Name',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                hintText: 'e.g. Shakib Al Hasan',
                errorText: _nameError,
                filled: true,
                fillColor: AppColors.background,
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 14),

            // Contact Phone Field
            const Text(
              'Contact Phone Number',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              onChanged: (_) {
                if (_phoneError != null) setState(() => _phoneError = null);
              },
              decoration: InputDecoration(
                hintText: 'e.g. 01712345678',
                errorText: _phoneError,
                filled: true,
                fillColor: AppColors.background,
                prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 14),

            // Preferred Move-in Date chips
            const Text(
              'Preferred Move-in Date',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _moveInOptions.map((option) {
                final isSelected = _selectedMoveIn == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  selectedColor: AppColors.green,
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  onSelected: _isSubmitting
                      ? null
                      : (val) {
                          if (val) {
                            setState(() {
                              _selectedMoveIn = option;
                            });
                          }
                        },
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Note / Query Field
            const Text(
              'Message or Specific Questions (Optional)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 2,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: 'e.g. Any parking fee? Can we visit this Friday?',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  disabledBackgroundColor: AppColors.green.withAlpha(140),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSubmitting
                      ? 'Sending Request...'
                      : (widget.property.isDemo
                          ? 'Submit Demo Rental Request'
                          : 'Send Rental Request'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
