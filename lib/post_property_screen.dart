import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:basha_lagbe/services/firestore_service.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/property_details_screen.dart';

// ---------------------------------------------------------------------------
// Models for Post Property Wizard & My Listings
// ---------------------------------------------------------------------------

enum ListingStatus {
  pendingReview('Pending Review', Color(0xFFB7791F), Color(0xFFFFF3D6)),
  approved('Approved (Live)', Color(0xFF0E5E3B), Color(0xFFE3F4EA)),
  rejected('Needs Revision', Color(0xFFC53030), Color(0xFFFFE3E3));

  const ListingStatus(this.label, this.foreground, this.background);
  final String label;
  final Color foreground;
  final Color background;

  static ListingStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'approved':
        return ListingStatus.approved;
      case 'rejected':
        return ListingStatus.rejected;
      case 'pending':
      case 'pendingreview':
      default:
        return ListingStatus.pendingReview;
    }
  }
}

class WizardPhotoItem {
  WizardPhotoItem({
    required this.id,
    this.label = 'Property Photo',
    this.bytes,
    this.networkUrl,
    this.isCover = false,
  });

  final String id;
  String label;
  final Uint8List? bytes;
  final String? networkUrl;
  bool isCover;

  bool get isMemory => bytes != null;
  bool get isNetwork => networkUrl != null && networkUrl!.isNotEmpty;
}

class SubmittedListing {
  SubmittedListing({
    required this.id,
    required this.property,
    required this.status,
    required this.submittedAt,
    this.photos = const [],
    this.moderationNote,
    this.ownerId,
    this.isDemo = false,
  });

  final String id;
  final Property property;
  final ListingStatus status;
  final DateTime submittedAt;
  final List<WizardPhotoItem> photos;
  final String? moderationNote;
  final String? ownerId;
  final bool isDemo;
}

// ---------------------------------------------------------------------------
// Post Property Main Screen (Wizard + My Listings Switcher)
// ---------------------------------------------------------------------------

class PostPropertyScreen extends StatefulWidget {
  const PostPropertyScreen({
    super.key,
    required this.myListings,
    required this.onListingSubmitted,
    required this.onListingDeleted,
    this.initialTab = 0,
    this.firebaseUser,
    this.onRequireSignIn,
  });

  final List<SubmittedListing> myListings;
  final ValueChanged<SubmittedListing> onListingSubmitted;
  final ValueChanged<String> onListingDeleted;
  final int initialTab;
  final User? firebaseUser;
  final VoidCallback? onRequireSignIn;

  @override
  State<PostPropertyScreen> createState() => _PostPropertyScreenState();
}

class _PostPropertyScreenState extends State<PostPropertyScreen> {
  int _activeTab = 0; // 0 = Post Wizard, 1 = My Listings
  int _currentStep = 0; // 0..4 (Steps 1 to 5)
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant PostPropertyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _activeTab = widget.initialTab;
    }
  }

  // Step 1 Controllers & State
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  PropertyType _propertyType = PropertyType.family;

  // Step 2 Controllers & State
  String _selectedDivision = 'Dhaka';
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  // Step 3 Controllers & State
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _utilityController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();

  // Family specific
  int _bedrooms = 3;
  int _bathrooms = 2;
  int _balconies = 2;

  // Bachelor specific
  String _bachelorRoomType = 'Single Room';
  bool _attachedBath = true;
  bool _attachedBalcony = true;

  // Shared mess specific
  String _bedsInRoom = '2-Person Room';
  String _washroomType = 'Attached';
  String _mealSystem = 'Running (3 times daily)';

  // Amenities & Tenant rules
  final Set<String> _selectedFacilities = {
    'Lift (Elevator)',
    'Standby Generator',
    'Titas Pipeline Gas',
    '24/7 Security Guard',
    'CCTV Surveillance',
    'Balcony / Veranda',
  };
  String _availabilityStatus = 'Available now';
  String _preferredTenant = 'Family only';

  // Step 4: Photos
  final List<WizardPhotoItem> _photos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _utilityController.dispose();
    _floorController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Pre-fill quick demo data for easy testing
  // -------------------------------------------------------------------------
  void _fillSampleData() {
    setState(() {
      _titleController.text = 'South Breeze Green Nest Flat';
      _descriptionController.text =
          'Spacious and naturally illuminated apartment with high ceilings, separate dining hall, and quiet residential neighborhood. Ideal for families seeking a peaceful environment.';
      _propertyType = PropertyType.family;
      _selectedDivision = 'Dhaka';
      _areaController.text = 'Mirpur 10, Dhaka';
      _addressController.text = 'House 14, Road 4, Block C, Section 10';
      _landmarkController.text = '3 minutes walk from Mirpur 10 Metro Rail Station';
      _rentController.text = '22000';
      _depositController.text = '44000';
      _utilityController.text = 'Water and gas included; electricity as per digital prepaid meter.';
      _floorController.text = '4th Floor (Lift-3)';
      _sizeController.text = '1350';
      _bedrooms = 3;
      _bathrooms = 2;
      _balconies = 2;
      _availabilityStatus = 'Available now';
      _preferredTenant = 'Family only';
      _selectedFacilities.addAll([
        'Lift (Elevator)',
        'Standby Generator',
        'Titas Pipeline Gas',
        '24/7 Security Guard',
        'CCTV Surveillance',
        'Dedicated Car Parking',
        'Balcony / Veranda',
      ]);
    });
    _addSamplePhotos();
    showFriendlyMessage(context, 'Sample demo data filled for all steps!');
  }

  void _addSamplePhotos() {
    final sampleUrls = [
      {
        'label': 'Living & Dining Room',
        'url':
            'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1200&auto=format&fit=crop&q=80',
      },
      {
        'label': 'Master Bedroom',
        'url':
            'https://images.unsplash.com/photo-1540518614846-7ede433c4550?w=1200&auto=format&fit=crop&q=80',
      },
      {
        'label': 'Modern Kitchen',
        'url':
            'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=1200&auto=format&fit=crop&q=80',
      },
      {
        'label': 'Open Balcony View',
        'url':
            'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1200&auto=format&fit=crop&q=80',
      },
    ];

    setState(() {
      for (final sample in sampleUrls) {
        if (_photos.length < 8) {
          final isFirst = _photos.isEmpty;
          _photos.add(
            WizardPhotoItem(
              id: 'sample-${DateTime.now().microsecondsSinceEpoch}-${_photos.length}',
              label: sample['label']!,
              networkUrl: sample['url']!,
              isCover: isFirst,
            ),
          );
        }
      }
    });
  }

  Future<void> _pickImagesFromDevice() async {
    try {
      final pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      for (final file in pickedFiles) {
        if (_photos.length >= 8) break;
        final bytes = await file.readAsBytes();
        final isFirst = _photos.isEmpty;
        setState(() {
          _photos.add(
            WizardPhotoItem(
              id: 'local-${DateTime.now().microsecondsSinceEpoch}-${_photos.length}',
              label: 'Room Photo ${_photos.length + 1}',
              bytes: bytes,
              isCover: isFirst,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        showFriendlyMessage(context, 'Could not load images: $e');
      }
    }
  }

  void _setCoverPhoto(int index) {
    setState(() {
      for (var i = 0; i < _photos.length; i++) {
        _photos[i].isCover = (i == index);
      }
    });
  }

  void _removePhoto(int index) {
    setState(() {
      final removed = _photos.removeAt(index);
      if (removed.isCover && _photos.isNotEmpty) {
        _photos.first.isCover = true;
      }
    });
  }

  // -------------------------------------------------------------------------
  // Validation per step
  // -------------------------------------------------------------------------
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_titleController.text.trim().isEmpty) {
          showFriendlyMessage(context, 'Please enter a title for your property listing.');
          return false;
        }
        if (_titleController.text.trim().length < 5) {
          showFriendlyMessage(context, 'Listing title should be at least 5 characters long.');
          return false;
        }
        return true;
      case 1:
        if (_areaController.text.trim().isEmpty) {
          showFriendlyMessage(context, 'Please enter or select the neighborhood / area.');
          return false;
        }
        return true;
      case 2:
        final rent = int.tryParse(_rentController.text.replaceAll(',', '').trim());
        if (rent == null || rent <= 0) {
          showFriendlyMessage(context, 'Please enter a valid monthly rent amount in Taka.');
          return false;
        }
        return true;
      case 3:
        if (_photos.isEmpty) {
          showFriendlyMessage(context, 'Please add at least 1 photo or tap "Add Sample Photos".');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _goToNextStep() {
    if (_validateCurrentStep()) {
      setState(() {
        if (_currentStep < 4) {
          _currentStep++;
        }
      });
    }
  }

  void _goToPreviousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  void _jumpToStep(int stepIndex) {
    setState(() {
      _currentStep = stepIndex;
    });
  }

  // -------------------------------------------------------------------------
  // Submission
  // -------------------------------------------------------------------------
  void _submitListing() async {
    if (!_validateCurrentStep()) return;

    if (widget.firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in with a landlord account to post a property.'),
          backgroundColor: AppColors.darkGreen,
          action: SnackBarAction(
            label: 'Sign In',
            textColor: Colors.white,
            onPressed: () => widget.onRequireSignIn?.call(),
          ),
        ),
      );
      widget.onRequireSignIn?.call();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final rent = int.tryParse(_rentController.text.replaceAll(',', '').trim()) ?? 15000;
    final deposit = int.tryParse(_depositController.text.replaceAll(',', '').trim()) ?? (rent * 2);
    final size = int.tryParse(_sizeController.text.replaceAll(',', '').trim()) ?? 1000;

    // Build photo list for Firestore
    final List<Map<String, dynamic>> firestorePhotos = _photos.map((item) {
      return {
        'label': item.label,
        'imageUrl': item.networkUrl,
        'storagePath': null,
        'isCover': item.isCover,
      };
    }).toList();

    // Fallback if no photos were added
    if (firestorePhotos.isEmpty) {
      firestorePhotos.add({
        'label': 'Main Living Space',
        'imageUrl':
            'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1200&auto=format&fit=crop&q=80',
        'storagePath': null,
        'isCover': true,
      });
    }

    final facilitiesList = _selectedFacilities.toList();
    final highlightsList = [
      if (_landmarkController.text.trim().isNotEmpty) _landmarkController.text.trim(),
      'Local market & grocery stores nearby',
      '24/7 public transport available',
    ];

    final propertyData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : 'Well-maintained rental home available for responsible tenants.',
      'propertyType': _propertyType.name,
      'division': _selectedDivision,
      'area': _areaController.text.trim().isNotEmpty
          ? _areaController.text.trim()
          : '$_selectedDivision, Bangladesh',
      'fullAddress': _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : _areaController.text.trim(),
      'landmark': _landmarkController.text.trim().isNotEmpty
          ? _landmarkController.text.trim()
          : 'Near central hub',
      'rentPerMonth': rent,
      'depositAmount': deposit,
      'sizeSqFt': size,
      'floorLevel': _floorController.text.trim().isNotEmpty
          ? _floorController.text.trim()
          : '3rd Floor',
      'bedrooms': _propertyType == PropertyType.family ? _bedrooms : 1,
      'bathrooms': _propertyType == PropertyType.family ? _bathrooms : (_attachedBath ? 1 : 1),
      'balconies': _propertyType == PropertyType.family ? _balconies : (_attachedBalcony ? 1 : 0),
      'facilities': facilitiesList,
      'availability': _availabilityStatus,
      'availableNow': _availabilityStatus.toLowerCase().contains('now'),
      'preferredTenant': _preferredTenant,
      'utilityNotice': _utilityController.text.trim().isNotEmpty
          ? _utilityController.text.trim()
          : 'Utilities as per usage/prepaid meter.',
      'nearbyHighlights': highlightsList,
      'photos': firestorePhotos,
    };

    try {
      final docId = await FirestoreService.instance.createProperty(
        ownerId: widget.firebaseUser!.uid,
        ownerEmail: widget.firebaseUser!.email ?? '',
        data: propertyData,
      );

      final propertyPhotos = firestorePhotos.map((p) => PropertyPhoto(
        label: p['label'] as String,
        imageUrl: p['imageUrl'] as String?,
      )).toList();

      final newProperty = Property(
        id: docId,
        title: _titleController.text.trim(),
        area: propertyData['area'] as String,
        landmark: propertyData['landmark'] as String,
        fullAddress: propertyData['fullAddress'] as String?,
        rentPerMonth: rent,
        depositAmount: deposit,
        sizeSqFt: size,
        floorLevel: propertyData['floorLevel'] as String,
        balconies: propertyData['balconies'] as int,
        type: _propertyType,
        bedrooms: propertyData['bedrooms'] as int,
        bathrooms: propertyData['bathrooms'] as int,
        availability: _availabilityStatus,
        availableNow: _availabilityStatus.toLowerCase().contains('now'),
        icon: _propertyType == PropertyType.family
            ? Icons.apartment
            : _propertyType == PropertyType.bachelor
                ? Icons.home_work
                : Icons.groups,
        gradientStart: AppColors.green,
        gradientEnd: AppColors.darkGreen,
        description: propertyData['description'] as String,
        facilities: facilitiesList,
        nearbyHighlights: highlightsList,
        photos: propertyPhotos,
        utilityNotice: propertyData['utilityNotice'] as String,
        isDemo: false,
      );

      final submitted = SubmittedListing(
        id: docId,
        property: newProperty,
        status: ListingStatus.pendingReview,
        submittedAt: DateTime.now(),
        photos: List.from(_photos),
        ownerId: widget.firebaseUser!.uid,
        isDemo: false,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        widget.onListingSubmitted(submitted);
        _showSubmissionSuccessDialog(submitted);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirestoreService.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showSubmissionSuccessDialog(SubmittedListing listing) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Listing Submitted for Review!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tracking ID: ${listing.id}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.green.withAlpha(90)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_done_outlined, size: 20, color: AppColors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cloud Firestore Notice: Your listing is saved with status "Pending Review". Once approved by moderation, it will appear publicly on the Home screen. You can track and manage it under My Listings.',
                        style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _resetForm();
              },
              child: const Text('Post Another Property'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _activeTab = 1; // Switch to My Listings
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
              ),
              child: const Text('View in My Listings'),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _titleController.clear();
      _descriptionController.clear();
      _areaController.clear();
      _addressController.clear();
      _landmarkController.clear();
      _rentController.clear();
      _depositController.clear();
      _utilityController.clear();
      _floorController.clear();
      _sizeController.clear();
      _photos.clear();
    });
  }

  // -------------------------------------------------------------------------
  // Main Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Top Header & Tab Switcher
          _buildTopBar(),

          // Active View: Wizard or My Listings
          Expanded(
            child: _activeTab == 0 ? _buildWizardBody() : _buildMyListingsBody(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Top Bar & Tab Switcher
  // -------------------------------------------------------------------------
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_home_work, color: AppColors.green, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post a Rental Property',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'List your house, room or mess seat in Bangladesh',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (_activeTab == 0)
                TextButton.icon(
                  onPressed: _fillSampleData,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.darkGreen,
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Auto-fill', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented Buttons
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? AppColors.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Property Wizard',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _activeTab == 0 ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _activeTab = 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? AppColors.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'My Listings',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _activeTab == 1 ? Colors.white : AppColors.textMuted,
                            ),
                          ),
                          if (widget.myListings.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _activeTab == 1 ? Colors.white : AppColors.lightGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${widget.myListings.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _activeTab == 1 ? AppColors.darkGreen : AppColors.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  // -------------------------------------------------------------------------
  // Wizard Body with Step Progress Tracker
  // -------------------------------------------------------------------------
  Widget _buildWizardBody() {
    return Column(
      children: [
        if (widget.firebaseUser == null)
          _buildGuestBanner(),

        // Step Tracker
        _buildStepTracker(),

        // Step Content
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _buildCurrentStepView(),
          ),
        ),

        // Bottom Navigation Bar (Back & Continue buttons)
        _buildWizardBottomNav(),
      ],
    );
  }

  Widget _buildGuestBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.darkGreen, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Landlord Sign-In Required',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.darkGreen,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Browsing as guest. Sign in to submit and persist your property to Cloud Firestore.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: widget.onRequireSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Sign In', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step Progress Indicator
  // -------------------------------------------------------------------------
  Widget _buildStepTracker() {
    final stepTitles = ['Info', 'Location', 'Rent & Specs', 'Photos', 'Review'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(stepTitles.length, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                // Allow tapping completed steps to jump back easily
                if (index <= _currentStep) {
                  _jumpToStep(index);
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: isCompleted
                              ? AppColors.green
                              : isCurrent
                                  ? AppColors.darkGreen
                                  : AppColors.border,
                          child: isCompleted
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrent ? Colors.white : AppColors.textMuted,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stepTitles[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrent
                                ? AppColors.darkGreen
                                : isCompleted
                                    ? AppColors.green
                                    : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < stepTitles.length - 1)
                    Container(
                      width: 14,
                      height: 2,
                      color: isCompleted ? AppColors.green : AppColors.border,
                      margin: const EdgeInsets.only(bottom: 16),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Wizard Bottom Navigation
  // -------------------------------------------------------------------------
  Widget _buildWizardBottomNav() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton.icon(
              onPressed: _goToPreviousStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textDark,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : (_currentStep == 4 ? _submitListing : _goToNextStep),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  : Icon(
                      _currentStep == 4 ? Icons.cloud_upload_outlined : Icons.arrow_forward,
                      size: 20,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Submitting to Firestore...'
                    : (_currentStep == 4 ? 'Submit Listing for Review' : 'Continue to Next Step'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step Switcher
  // -------------------------------------------------------------------------
  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1BasicInfo();
      case 1:
        return _buildStep2Location();
      case 2:
        return _buildStep3RentAndFacilities();
      case 3:
        return _buildStep4Photos();
      case 4:
        return _buildStep5ReviewAndSubmit();
      default:
        return const SizedBox.shrink();
    }
  }

  // =========================================================================
  // STEP 1: Basic Information
  // =========================================================================
  Widget _buildStep1BasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          stepNumber: 'Step 1 of 5',
          title: 'Basic Information',
          subtitle: 'Give your listing a catchy title and select the rental category.',
        ),
        const SizedBox(height: 18),

        // Listing Title
        const Text('Listing Title *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          decoration: _buildInputDecoration(
            hintText: 'e.g. Spacious 3BHK Family Flat with Lake View',
            prefixIcon: Icons.title,
          ),
        ),
        const SizedBox(height: 18),

        // Property Category
        const Text('Property Category *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          'Form fields will automatically adapt based on your selection.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),

        _buildCategoryCard(
          type: PropertyType.family,
          title: 'Family Flat',
          subtitle: 'Complete independent apartment for families.',
          icon: Icons.apartment,
        ),
        const SizedBox(height: 10),
        _buildCategoryCard(
          type: PropertyType.bachelor,
          title: 'Bachelor Room',
          subtitle: 'Single or master bedroom suitable for students or job-holders.',
          icon: Icons.single_bed_outlined,
        ),
        const SizedBox(height: 10),
        _buildCategoryCard(
          type: PropertyType.shared,
          title: 'Shared Mess Seat',
          subtitle: 'Individual seat or bed in a managed shared student/bachelor mess.',
          icon: Icons.groups_outlined,
        ),

        const SizedBox(height: 20),

        // Description
        const Text('Property Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: _buildInputDecoration(
            hintText:
                'Describe room ventilation, sunlight, building security, neighborhood highlights, and any house rules (e.g. entry closing times, tenant preferences)...',
            prefixIcon: Icons.description_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required PropertyType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _propertyType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _propertyType = type;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.green : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.green : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : AppColors.green, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.darkGreen : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.green : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 2: Location
  // =========================================================================
  Widget _buildStep2Location() {
    final popularDhaka = [
      'Mirpur 10',
      'Dhanmondi',
      'Uttara Sector 7',
      'Mohammadpur',
      'Bashundhara R/A',
      'Banani',
      'Gulshan',
      'Badda',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          stepNumber: 'Step 2 of 5',
          title: 'Location Details',
          subtitle: 'Help renters find your property quickly across Bangladesh.',
        ),
        const SizedBox(height: 18),

        // Division / City Dropdown
        const Text('City / Division *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedDivision,
              items: const [
                DropdownMenuItem(value: 'Dhaka', child: Text('Dhaka Division')),
                DropdownMenuItem(value: 'Chattogram', child: Text('Chattogram Division')),
                DropdownMenuItem(value: 'Sylhet', child: Text('Sylhet Division')),
                DropdownMenuItem(value: 'Rajshahi', child: Text('Rajshahi Division')),
                DropdownMenuItem(value: 'Khulna', child: Text('Khulna Division')),
                DropdownMenuItem(value: 'Barishal', child: Text('Barishal Division')),
                DropdownMenuItem(value: 'Rangpur', child: Text('Rangpur Division')),
                DropdownMenuItem(value: 'Mymensingh', child: Text('Mymensingh Division')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedDivision = val);
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Area / Neighborhood
        const Text('Area / Neighborhood *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _areaController,
          decoration: _buildInputDecoration(
            hintText: 'e.g. Mirpur 10, Dhanmondi, or Badamtoli Mor',
            prefixIcon: Icons.location_city_outlined,
          ),
        ),
        const SizedBox(height: 8),

        // Quick suggestions
        if (_selectedDivision == 'Dhaka') ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: popularDhaka.map((area) {
              return ActionChip(
                label: Text(area, style: const TextStyle(fontSize: 11.5)),
                backgroundColor: AppColors.background,
                side: const BorderSide(color: AppColors.border),
                onPressed: () {
                  setState(() {
                    _areaController.text = '$area, Dhaka';
                  });
                },
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 18),

        // Full Address
        const Text('Full Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _addressController,
          decoration: _buildInputDecoration(
            hintText: 'e.g. House 14, Road 4, Block C, Section 10',
            prefixIcon: Icons.home_outlined,
          ),
        ),

        const SizedBox(height: 18),

        // Landmark
        const Text('Nearby Landmark', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _landmarkController,
          decoration: _buildInputDecoration(
            hintText: 'e.g. 3 mins from Mirpur 10 Metro Station, opposite City Bank',
            prefixIcon: Icons.near_me_outlined,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // STEP 3: Rent & Facilities
  // =========================================================================
  Widget _buildStep3RentAndFacilities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          stepNumber: 'Step 3 of 5',
          title: 'Rent, Specifications & Facilities',
          subtitle: 'Define pricing terms and select facilities tailored to your property category.',
        ),
        const SizedBox(height: 18),

        // Monthly Rent
        const Text('Monthly Rent (BDT ৳) *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _rentController,
          keyboardType: TextInputType.number,
          decoration: _buildInputDecoration(
            hintText: 'e.g. 18000',
            prefixIcon: Icons.payments_outlined,
          ),
        ),

        const SizedBox(height: 18),

        // Security Deposit
        const Text('Security Deposit (BDT ৳)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _depositController,
          keyboardType: TextInputType.number,
          decoration: _buildInputDecoration(
            hintText: 'e.g. 36000 (usually 1 or 2 months rent)',
            prefixIcon: Icons.lock_outline,
          ),
        ),

        const SizedBox(height: 18),

        // Utility Cost Details
        const Text('Utility & Service Charge Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _utilityController,
          decoration: _buildInputDecoration(
            hintText: 'e.g. Gas & water included; electricity as per digital sub-meter.',
            prefixIcon: Icons.bolt_outlined,
          ),
        ),

        const SizedBox(height: 24),
        const Divider(color: AppColors.border),
        const SizedBox(height: 14),

        // -------------------------------------------------------------------
        // Category-Adaptive Form Fields
        // -------------------------------------------------------------------
        Text(
          '${_propertyType.label} Specifications',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkGreen),
        ),
        const SizedBox(height: 12),

        if (_propertyType == PropertyType.family) ...[
          // Family specs: Bedrooms, Bathrooms, Balconies, Size, Floor
          _buildCounterSelector('Bedrooms', _bedrooms, (val) => setState(() => _bedrooms = val), 1, 8),
          const SizedBox(height: 12),
          _buildCounterSelector('Bathrooms', _bathrooms, (val) => setState(() => _bathrooms = val), 1, 6),
          const SizedBox(height: 12),
          _buildCounterSelector('Balconies', _balconies, (val) => setState(() => _balconies = val), 0, 5),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Property Size (sq ft)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _sizeController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(hintText: 'e.g. 1250', prefixIcon: Icons.square_foot),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Floor Level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _floorController,
                      decoration: _buildInputDecoration(hintText: 'e.g. 4th Floor', prefixIcon: Icons.layers_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ] else if (_propertyType == PropertyType.bachelor) ...[
          // Bachelor room specs
          const Text('Room Type', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['Single Room', 'Master Room with Balcony', 'Studio Flat'].map((type) {
              final isSelected = _bachelorRoomType == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                selectedColor: AppColors.green,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _bachelorRoomType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            title: const Text('Attached Bathroom', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Exclusive private bathroom inside the room', style: TextStyle(fontSize: 12)),
            value: _attachedBath,
            activeTrackColor: AppColors.green,
            activeThumbColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _attachedBath = val),
          ),
          SwitchListTile(
            title: const Text('Private Balcony', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Attached balcony with open airflow', style: TextStyle(fontSize: 12)),
            value: _attachedBalcony,
            activeTrackColor: AppColors.green,
            activeThumbColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _attachedBalcony = val),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _floorController,
            decoration: _buildInputDecoration(hintText: 'e.g. 3rd Floor', prefixIcon: Icons.layers_outlined),
          ),
        ] else if (_propertyType == PropertyType.shared) ...[
          // Shared mess specs (avoids bedroom counts)
          const Text('Beds in Room', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['2-Person Room', '3-Person Room', '4-Person Room'].map((beds) {
              final isSelected = _bedsInRoom == beds;
              return ChoiceChip(
                label: Text(beds),
                selected: isSelected,
                selectedColor: AppColors.green,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _bedsInRoom = beds),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text('Washroom Type', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['Attached Washroom', 'Common Washroom'].map((bath) {
              final isSelected = _washroomType == bath;
              return ChoiceChip(
                label: Text(bath),
                selected: isSelected,
                selectedColor: AppColors.green,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _washroomType = bath),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text('Meal System', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              'Running (3 times daily)',
              'Self-Cooking Allowed',
              'No Meal System',
            ].map((meal) {
              final isSelected = _mealSystem == meal;
              return ChoiceChip(
                label: Text(meal),
                selected: isSelected,
                selectedColor: AppColors.green,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _mealSystem = meal),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 24),
        const Divider(color: AppColors.border),
        const SizedBox(height: 14),

        // -------------------------------------------------------------------
        // Facilities & Amenities Chips
        // -------------------------------------------------------------------
        const Text('Facilities & Amenities', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Select all features that apply to your rental property:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Lift (Elevator)',
            'Standby Generator',
            'Titas Pipeline Gas',
            'LP Gas Cylinder',
            '24/7 Security Guard',
            'CCTV Surveillance',
            'Wi-Fi Ready',
            'Dedicated Car Parking',
            'Motorbike Parking',
            'Running Meal System',
            'Housekeeping / Maid',
            'Filtered Drinking Water',
            'Balcony / Veranda',
            'Rooftop Access',
          ].map((facility) {
            final isSelected = _selectedFacilities.contains(facility);
            return FilterChip(
              label: Text(facility),
              selected: isSelected,
              selectedColor: AppColors.lightGreen,
              checkmarkColor: AppColors.green,
              side: BorderSide(color: isSelected ? AppColors.green : AppColors.border),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.darkGreen : AppColors.textDark,
              ),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedFacilities.add(facility);
                  } else {
                    _selectedFacilities.remove(facility);
                  }
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Availability status
        const Text('Availability Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            'Available now',
            'Available from 1st of next month',
            'Available from 15th of next month',
          ].map((status) {
            final isSelected = _availabilityStatus == status;
            return ChoiceChip(
              label: Text(status),
              selected: isSelected,
              selectedColor: AppColors.green,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              onSelected: (_) => setState(() => _availabilityStatus = status),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // Preferred Tenant
        const Text('Preferred Tenant Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            'Family only',
            'Job-holders / Professionals',
            'University Students',
            'Female Students / Job-Holders',
            'Any Responsible Renter',
          ].map((tenant) {
            final isSelected = _preferredTenant == tenant;
            return ChoiceChip(
              label: Text(tenant),
              selected: isSelected,
              selectedColor: AppColors.green,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              onSelected: (_) => setState(() => _preferredTenant = tenant),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCounterSelector(String label, int value, ValueChanged<int> onChanged, int min, int max) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.green),
                onPressed: value > min ? () => onChanged(value - 1) : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline, color: AppColors.green),
                onPressed: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 4: Photos
  // =========================================================================
  Widget _buildStep4Photos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          stepNumber: 'Step 4 of 5',
          title: 'Property Photos',
          subtitle: 'Upload clear photos of bedrooms, living area, kitchen, and balconies.',
        ),
        const SizedBox(height: 16),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _photos.length >= 8 ? null : _pickImagesFromDevice,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Pick from Device', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _photos.length >= 8 ? null : _addSamplePhotos,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkGreen,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Add Demo Photos'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Photos counter badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_photos.length} of 8 photos added',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _photos.isEmpty ? AppColors.amber : AppColors.darkGreen,
              ),
            ),
            const Text(
              'First photo or star = Cover photo',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Photos Grid
        if (_photos.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.green),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No photos added yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap "Pick from Device" or "Add Demo Photos" above to include photos of your listing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ] else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final photo = _photos[index];
              return _buildPhotoTile(photo, index);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoTile(WizardPhotoItem photo, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: photo.isCover ? AppColors.green : AppColors.border,
          width: photo.isCover ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image Preview
          if (photo.isMemory)
            Image.memory(photo.bytes!, fit: BoxFit.cover)
          else if (photo.isNetwork)
            Image.network(
              photo.networkUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.lightGreen,
                child: const Icon(Icons.broken_image, color: AppColors.green),
              ),
            )
          else
            Container(color: AppColors.lightGreen),

          // Cover Photo Tag
          if (photo.isCover)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'COVER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top right Delete button
          Positioned(
            top: 6,
            right: 6,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.black.withAlpha(150),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () => _removePhoto(index),
              ),
            ),
          ),

          // Bottom Bar (Label + Set as Cover action)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      photo.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!photo.isCover)
                    InkWell(
                      onTap: () => _setCoverPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Make Cover',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
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

  // =========================================================================
  // STEP 5: Review & Submit
  // =========================================================================
  Widget _buildStep5ReviewAndSubmit() {
    final rentInt = int.tryParse(_rentController.text.replaceAll(',', '').trim()) ?? 0;
    final depositInt = int.tryParse(_depositController.text.replaceAll(',', '').trim()) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          stepNumber: 'Step 5 of 5',
          title: 'Review & Submit',
          subtitle: 'Check all entered details carefully before submitting for review.',
        ),
        const SizedBox(height: 18),

        // Section 1: Basic Info Review
        _buildReviewCard(
          title: 'Basic Information',
          icon: Icons.info_outline,
          onEdit: () => _jumpToStep(0),
          children: [
            _buildReviewRow('Title', _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Not specified'),
            _buildReviewRow('Category', _propertyType.label),
            if (_descriptionController.text.trim().isNotEmpty)
              _buildReviewRow('Description', _descriptionController.text.trim()),
          ],
        ),

        const SizedBox(height: 14),

        // Section 2: Location Review
        _buildReviewCard(
          title: 'Location Details',
          icon: Icons.location_on_outlined,
          onEdit: () => _jumpToStep(1),
          children: [
            _buildReviewRow('Division / City', _selectedDivision),
            _buildReviewRow('Area', _areaController.text.trim().isNotEmpty ? _areaController.text.trim() : 'Not specified'),
            if (_addressController.text.trim().isNotEmpty)
              _buildReviewRow('Full Address', _addressController.text.trim()),
            if (_landmarkController.text.trim().isNotEmpty)
              _buildReviewRow('Nearby Landmark', _landmarkController.text.trim()),
          ],
        ),

        const SizedBox(height: 14),

        // Section 3: Financials & Specs Review
        _buildReviewCard(
          title: 'Financials & Specifications',
          icon: Icons.account_balance_wallet_outlined,
          onEdit: () => _jumpToStep(2),
          children: [
            _buildReviewRow('Monthly Rent', rentInt > 0 ? formatTaka(rentInt) : 'Not specified', isHighlighted: true),
            _buildReviewRow('Security Deposit', depositInt > 0 ? formatTaka(depositInt) : 'None / Not specified'),
            if (_utilityController.text.trim().isNotEmpty)
              _buildReviewRow('Utilities', _utilityController.text.trim()),
            if (_propertyType == PropertyType.family) ...[
              _buildReviewRow('Bedrooms / Bathrooms', '$_bedrooms Bedrooms • $_bathrooms Bathrooms'),
              _buildReviewRow('Balconies', '$_balconies Balconies'),
              if (_sizeController.text.trim().isNotEmpty)
                _buildReviewRow('Property Size', '${_sizeController.text.trim()} sq ft'),
            ] else if (_propertyType == PropertyType.bachelor) ...[
              _buildReviewRow('Room Configuration', '$_bachelorRoomType • ${_attachedBath ? "Attached Bath" : "Common Bath"}'),
              _buildReviewRow('Balcony', _attachedBalcony ? 'Private Balcony' : 'No Balcony'),
            ] else if (_propertyType == PropertyType.shared) ...[
              _buildReviewRow('Mess Seat Config', '$_bedsInRoom • $_washroomType'),
              _buildReviewRow('Meal System', _mealSystem),
            ],
            if (_floorController.text.trim().isNotEmpty)
              _buildReviewRow('Floor Level', _floorController.text.trim()),
            _buildReviewRow('Availability', _availabilityStatus),
            _buildReviewRow('Preferred Tenant', _preferredTenant),
          ],
        ),

        const SizedBox(height: 14),

        // Section 4: Facilities Review
        _buildReviewCard(
          title: 'Facilities (${_selectedFacilities.length})',
          icon: Icons.star_outline,
          onEdit: () => _jumpToStep(2),
          children: [
            if (_selectedFacilities.isEmpty)
              const Text('Standard basic amenities', style: TextStyle(color: AppColors.textMuted))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedFacilities.map((fac) {
                  return Chip(
                    label: Text(fac, style: const TextStyle(fontSize: 11.5)),
                    backgroundColor: AppColors.lightGreen,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
          ],
        ),

        const SizedBox(height: 14),

        // Section 5: Photos Review
        _buildReviewCard(
          title: 'Photos (${_photos.length})',
          icon: Icons.photo_library_outlined,
          onEdit: () => _jumpToStep(3),
          children: [
            if (_photos.isEmpty)
              const Text(
                'No photos selected yet. Please go to Step 4 to add photos.',
                style: TextStyle(color: AppColors.heart, fontWeight: FontWeight.w600),
              )
            else
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: photo.isMemory
                              ? Image.memory(photo.bytes!, width: 80, height: 80, fit: BoxFit.cover)
                              : Image.network(photo.networkUrl!, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        if (photo.isCover)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Cover',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),

        const SizedBox(height: 18),

        // Moderation Notice Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amberLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.amber.withAlpha(90)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AppColors.amber, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Local Demo Moderation Notice: When you tap submit, this listing is saved locally and marked as "Pending Review". It will appear in your "My Listings" tab for preview.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard({
    required String title,
    required IconData icon,
    required VoidCallback onEdit,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: AppColors.green),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.green),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: AppColors.border),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
                color: isHighlighted ? AppColors.darkGreen : AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // VIEW: My Listings Section
  // =========================================================================
  Widget _buildMyListingsBody() {
    if (widget.firebaseUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, size: 48, color: AppColors.green),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sign In to View My Listings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your properties are securely stored in Cloud Firestore under your landlord account. Sign in to view, edit, or remove listings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: widget.onRequireSignIn,
                style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                icon: const Icon(Icons.login),
                label: const Text('Sign In or Register'),
              ),
            ],
          ),
        ),
      );
    }

    final listings = widget.myListings;

    if (listings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.maps_home_work_outlined, size: 48, color: AppColors.green),
              ),
              const SizedBox(height: 18),
              const Text(
                'No listings posted yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the Property Wizard to submit your rental property. It will appear here with review status.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _activeTab = 0; // Return to wizard
                  });
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                icon: const Icon(Icons.add),
                label: const Text('Start New Property Listing'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final item = listings[index];
        final property = item.property;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Cover thumbnail & Info
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 72,
                        height: 72,
                        color: AppColors.lightGreen,
                        child: item.photos.isNotEmpty && item.photos.first.isMemory
                            ? Image.memory(item.photos.first.bytes!, fit: BoxFit.cover)
                            : (property.photos.isNotEmpty && property.photos.first.isNetworkPhoto)
                                ? Image.network(
                                    property.photos.first.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.home, color: AppColors.green),
                                  )
                                : const Icon(Icons.home, color: AppColors.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Status Chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.status.background,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.hourglass_top_outlined,
                                      size: 12,
                                      color: item.status.foreground,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.status.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: item.status.foreground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatTaka(property.rentPerMonth),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            property.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            property.area,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tracking & Source Notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppColors.background,
                child: Row(
                  children: [
                    const Icon(Icons.tag, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'ID: ${item.id}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    Text(
                      item.isDemo ? 'Demo Listing' : 'Cloud Listing (Firestore)',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Action Buttons Row
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PropertyDetailsScreen(
                              property: property,
                              favouriteIds: const {},
                              onToggleFavourite: (_) {},
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Preview Details'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.green),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Edit listing details',
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.darkGreen),
                      onPressed: () => _showEditListingDialog(item),
                    ),
                    IconButton(
                      tooltip: 'Delete listing',
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.heart),
                      onPressed: () => _confirmDeleteListing(item),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditListingDialog(SubmittedListing item) {
    final property = item.property;
    final rentController = TextEditingController(text: '${property.rentPerMonth}');
    final depositController = TextEditingController(
      text: property.depositAmount != null ? '${property.depositAmount}' : '',
    );
    final descController = TextEditingController(text: property.description);
    String selectedAvailability = property.availability;
    bool isSaving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit: ${property.title}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update key details for this listing. Status and ownership remain protected.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: rentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Rent (৳)',
                        prefixIcon: Icon(Icons.payments_outlined, color: AppColors.green),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: depositController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Deposit Amount (৳)',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.green),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAvailability.toLowerCase().contains('now')
                          ? 'Available now'
                          : selectedAvailability,
                      decoration: const InputDecoration(
                        labelText: 'Availability',
                        prefixIcon: Icon(Icons.event_available, color: AppColors.green),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Available now', child: Text('Available now')),
                        DropdownMenuItem(
                          value: 'Available from 1st of next month',
                          child: Text('Available from 1st of next month'),
                        ),
                        DropdownMenuItem(value: 'Booked / Unavailable', child: Text('Booked / Unavailable')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedAvailability = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newRent =
                              int.tryParse(rentController.text.trim()) ?? property.rentPerMonth;
                          final newDeposit = int.tryParse(depositController.text.trim());
                          final newDesc = descController.text.trim();

                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          if (widget.firebaseUser == null || item.isDemo) {
                            Navigator.of(dialogContext).pop();
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('Demo listing updated locally.')),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            await FirestoreService.instance.updateProperty(
                              propertyId: item.id,
                              ownerId: widget.firebaseUser!.uid,
                              updates: {
                                'rentPerMonth': newRent,
                                'depositAmount': newDeposit,
                                'availability': selectedAvailability,
                                'availableNow': selectedAvailability.toLowerCase().contains('now'),
                                'description': newDesc.isNotEmpty ? newDesc : property.description,
                              },
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Listing updated successfully in Cloud Firestore.'),
                                backgroundColor: AppColors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                            });
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(FirestoreService.getFriendlyErrorMessage(e)),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteListing(SubmittedListing item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Listing?'),
          content: Text(
            item.isDemo
                ? 'Are you sure you want to remove this demo listing?'
                : 'Are you sure you want to permanently delete this listing from Cloud Firestore? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.heart),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (widget.firebaseUser != null && !item.isDemo) {
                  try {
                    await FirestoreService.instance.deleteProperty(
                      propertyId: item.id,
                      ownerId: widget.firebaseUser!.uid,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Listing deleted from Cloud Firestore.'),
                          backgroundColor: AppColors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(FirestoreService.getFriendlyErrorMessage(e)),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  }
                } else {
                  widget.onListingDeleted(item.id);
                  if (mounted) {
                    showFriendlyMessage(context, 'Listing removed.');
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  Widget _buildSectionHeader({
    required String stepNumber,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.35),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(prefixIcon, color: AppColors.green, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
