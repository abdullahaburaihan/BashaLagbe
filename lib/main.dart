import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:basha_lagbe/firebase_options.dart';
import 'package:basha_lagbe/services/auth_service.dart';
import 'package:basha_lagbe/services/firestore_service.dart';
import 'package:basha_lagbe/auth_sheet.dart';
import 'package:basha_lagbe/property_details_screen.dart';
import 'package:basha_lagbe/post_property_screen.dart';
import 'package:basha_lagbe/profile_screen.dart';

/// Returns the appropriate Firestore emulator host based on the target platform.
///
/// On Android devices and emulators, the host machine's loopback is mapped to `10.0.2.2`.
/// On web (Chrome) and desktop platforms, `localhost` maps directly to the host machine.
@visibleForTesting
String getFirestoreEmulatorHost({
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  final targetPlatform = platform ?? defaultTargetPlatform;
  if (!isWeb && targetPlatform == TargetPlatform.android) {
    return '10.0.2.2';
  }
  return 'localhost';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (const bool.fromEnvironment(
      'USE_FIREBASE_EMULATOR',
      defaultValue: false,
    )) {
      final host = getFirestoreEmulatorHost();
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      debugPrint('Firestore connected to local emulator at $host:8080');
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }
  runApp(const BashaLagbeApp());
}

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

class AppColors {
  // Primary brand
  static const Color primary = Color(0xFF244B3B);
  static const Color primaryDark = Color(0xFF1A382C);
  static const Color green = primary; // Backward-compatible alias
  static const Color darkGreen = primaryDark; // Backward-compatible alias
  static const Color secondarySage = Color(0xFFDCE6D9);
  static const Color lightGreen = secondarySage; // Backward-compatible alias

  // Background and surfaces
  static const Color background = Color(0xFFF7F4EC); // Warm ivory
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFDADFD8);

  // Typography
  static const Color textDark = Color(0xFF202923); // Primary text
  static const Color textMuted = Color(0xFF59655D); // Secondary text
  static const Color textTertiary = Color(0xFF707A73); // Tertiary text
  static const Color textInverse = Color(0xFFFFFFFF); // Inverse text

  // Semantic statuses
  static const Color success = Color(0xFF246B45);
  static const Color successSurface = Color(0xFFE7F2E9);
  static const Color warning = Color(0xFF8A5200);
  static const Color warningSurface = Color(0xFFFFF1D6);
  static const Color amber = warning; // Backward-compatible alias
  static const Color amberLight = warningSurface; // Backward-compatible alias
  static const Color error = Color(0xFFB4232F);
  static const Color errorSurface = Color(0xFFFCE9E8);
  static const Color favourite = Color(0xFFB4234B);
  static const Color favouriteSurface = Color(0xFFFBE8EE);
  static const Color heart = favourite; // Backward-compatible alias

  // Accents and states
  static const Color clay = Color(0xFFB96E50);
  static const Color disabledSurface = Color(0xFFE8EBE6);
  static const Color disabledText = Color(0xFF68716B);
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class BashaLagbeApp extends StatelessWidget {
  const BashaLagbeApp({super.key, this.initialApprovedProperties});

  final List<Property>? initialApprovedProperties;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BashaLagbe',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        fontFamilyFallback: const [
          'Noto Sans Bengali',
          'Hind Siliguri',
          'SolaimanLipi',
          'Kalpurush',
          'sans-serif',
        ],
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
          onSurface: AppColors.textDark,
          primary: AppColors.primary,
          onPrimary: AppColors.textInverse,
          secondary: AppColors.secondarySage,
          onSecondary: AppColors.textDark,
          error: AppColors.error,
          onError: AppColors.textInverse,
        ),
        scaffoldBackgroundColor: AppColors.background,
        dividerColor: AppColors.border,
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          shape: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.secondarySage,
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              );
            }
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary);
            }
            return const IconThemeData(color: AppColors.textMuted);
          }),
        ),
      ),
      home: MainShell(initialApprovedProperties: initialApprovedProperties),
    );
  }
}

// ---------------------------------------------------------------------------
// Data models and demo data
// ---------------------------------------------------------------------------

enum PropertyType {
  bachelor('Bachelor'),
  family('Family'),
  shared('Shared');

  const PropertyType(this.label);
  final String label;

  static PropertyType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'bachelor':
        return PropertyType.bachelor;
      case 'shared':
        return PropertyType.shared;
      case 'family':
      default:
        return PropertyType.family;
    }
  }
}

enum PropertyFilter {
  all('All'),
  bachelor('Bachelor'),
  family('Family'),
  shared('Shared');

  const PropertyFilter(this.label);
  final String label;

  bool matches(PropertyType type) {
    switch (this) {
      case PropertyFilter.all:
        return true;
      case PropertyFilter.bachelor:
        return type == PropertyType.bachelor;
      case PropertyFilter.family:
        return type == PropertyType.family;
      case PropertyFilter.shared:
        return type == PropertyType.shared;
    }
  }
}

class Property {
  const Property({
    required this.id,
    required this.title,
    required this.area,
    required this.landmark,
    required this.rentPerMonth,
    required this.type,
    required this.bedrooms,
    required this.bathrooms,
    required this.availability,
    required this.availableNow,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    this.depositAmount,
    this.sizeSqFt,
    this.floorLevel = 'Not specified',
    this.balconies = 1,
    this.fullAddress,
    this.description = '',
    this.facilities = const [],
    this.nearbyHighlights = const [],
    this.photos = const [],
    this.utilityNotice = 'Electricity & utility bills as per usage/sub-meter',
    this.isDemo = false,
    this.ownerId,
  });

  final String id;
  final String title;
  final String area;
  final String landmark;
  final int rentPerMonth;
  final PropertyType type;
  final int bedrooms;
  final int bathrooms;
  final String availability;
  final bool availableNow;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;

  // Detailed fields for property details & future milestones
  final int? depositAmount;
  final int? sizeSqFt;
  final String floorLevel;
  final int balconies;
  final String? fullAddress;
  final String description;
  final List<String> facilities;
  final List<String> nearbyHighlights;
  final List<PropertyPhoto> photos;
  final String utilityNotice;
  final bool isDemo;
  final String? ownerId;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Formats a number like 18000 as ৳18,000
String formatTaka(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return '৳${buffer.toString()}';
}

void showFriendlyMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkGreen,
      duration: const Duration(seconds: 3),
    ),
  );
}

// ---------------------------------------------------------------------------
// Main shell (bottom navigation + shared favourite state)
// ---------------------------------------------------------------------------

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialApprovedProperties});

  final List<Property>? initialApprovedProperties;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final Set<String> _favouriteIds = <String>{};
  Set<String> _guestFavouriteIds = <String>{};
  int _selectedIndex = 0;

  final List<SubmittedListing> _myListings = [];

  int _postInitialTab = 0;

  static const _defaultGuestProfile = UserProfile(
    name: 'BashaLagbe User',
    email: '',
    phone: '',
    role: 'Guest Renter',
  );

  UserProfile _userProfile = _defaultGuestProfile;

  final List<RentalRequest> _rentalRequests = [];

  StreamSubscription<User?>? _authSub;
  StreamSubscription<Set<String>>? _favouritesSub;
  StreamSubscription<List<Property>>? _approvedPropertiesSub;
  StreamSubscription<List<SubmittedListing>>? _userListingsSub;
  StreamSubscription<List<RentalRequest>>? _tenantRequestsSub;

  User? _firebaseUser;
  List<Property> _approvedProperties = [];
  List<SubmittedListing> _userCloudListings = [];
  List<RentalRequest> _userCloudRentalRequests = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialApprovedProperties != null) {
      _approvedProperties = List.from(widget.initialApprovedProperties!);
    }
    _firebaseUser = AuthService.instance.currentUser;
    _subscribeToApprovedProperties();
    if (_firebaseUser != null) {
      _subscribeToUserFavourites(_firebaseUser!.uid);
      _subscribeToUserListings(_firebaseUser!.uid);
      _subscribeToTenantRequests(_firebaseUser!.uid);
    }
    _authSub = AuthService.instance.authStateChanges.listen((user) {
      if (!mounted) return;
      final previousUid = _firebaseUser?.uid;
      final newUid = user?.uid;

      setState(() {
        _firebaseUser = user;
        if (user != null) {
          final name =
              (user.displayName != null && user.displayName!.trim().isNotEmpty)
              ? user.displayName!
              : _userProfile.name;
          final email = user.email ?? _userProfile.email;
          _userProfile = _userProfile.copyWith(name: name, email: email);
        } else {
          _userProfile = _defaultGuestProfile;
        }
      });

      if (newUid != previousUid) {
        if (user != null) {
          _subscribeToUserFavourites(user.uid);
          _subscribeToUserListings(user.uid);
          _subscribeToTenantRequests(user.uid);
        } else {
          _unsubscribeAndRestoreGuestFavourites();
          _unsubscribeUserListings();
          _unsubscribeTenantRequests();
        }
      }
    });
  }

  void _subscribeToApprovedProperties() {
    _approvedPropertiesSub?.cancel();
    _approvedPropertiesSub = FirestoreService.instance
        .streamApprovedProperties()
        .listen(
          (props) {
            if (mounted) {
              setState(() {
                _approvedProperties = props;
              });
            }
          },
          onError: (e) {
            debugPrint('Approved properties stream error: $e');
          },
        );
  }

  void _subscribeToUserListings(String uid) {
    _userListingsSub?.cancel();
    _userListingsSub = FirestoreService.instance
        .streamUserListings(uid)
        .listen(
          (listings) {
            if (mounted) {
              setState(() {
                _userCloudListings = listings;
              });
            }
          },
          onError: (e) {
            debugPrint('User listings stream error: $e');
          },
        );
  }

  void _unsubscribeUserListings() {
    _userListingsSub?.cancel();
    _userListingsSub = null;
    setState(() {
      _userCloudListings = [];
    });
  }

  void _subscribeToTenantRequests(String uid) {
    _tenantRequestsSub?.cancel();
    _tenantRequestsSub = FirestoreService.instance
        .streamTenantRequests(uid)
        .listen(
          (requests) {
            if (mounted) {
              setState(() {
                _userCloudRentalRequests = requests;
              });
            }
          },
          onError: (e) {
            debugPrint('Tenant requests stream error: $e');
          },
        );
  }

  void _unsubscribeTenantRequests() {
    _tenantRequestsSub?.cancel();
    _tenantRequestsSub = null;
    setState(() {
      _userCloudRentalRequests = [];
    });
  }

  void _subscribeToUserFavourites(String uid) {
    _favouritesSub?.cancel();
    setState(() {
      _favouriteIds.clear();
    });
    _favouritesSub = FirestoreService.instance
        .streamFavourites(uid)
        .listen(
          (cloudFavs) {
            if (mounted) {
              setState(() {
                _favouriteIds.clear();
                _favouriteIds.addAll(cloudFavs);
              });
            }
          },
          onError: (e) {
            debugPrint('Favourites subscription error: $e');
          },
        );
  }

  void _unsubscribeAndRestoreGuestFavourites() {
    _favouritesSub?.cancel();
    _favouritesSub = null;
    setState(() {
      _favouriteIds.clear();
      _favouriteIds.addAll(_guestFavouriteIds);
    });
  }

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

  @override
  void dispose() {
    _authSub?.cancel();
    _favouritesSub?.cancel();
    _approvedPropertiesSub?.cancel();
    _userListingsSub?.cancel();
    _tenantRequestsSub?.cancel();
    super.dispose();
  }

  void _toggleFavourite(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;

    if (_firebaseUser == null) {
      // Guest mode: update locally in-memory
      setState(() {
        if (!_favouriteIds.add(cleanId)) {
          _favouriteIds.remove(cleanId);
        }
        _guestFavouriteIds = Set<String>.from(_favouriteIds);
      });
      return;
    }

    // Authenticated mode: optimistic UI update + Firestore background sync
    final uid = _firebaseUser!.uid;
    final isAdding = !_favouriteIds.contains(cleanId);

    setState(() {
      if (isAdding) {
        _favouriteIds.add(cleanId);
      } else {
        _favouriteIds.remove(cleanId);
      }
    });

    try {
      if (isAdding) {
        await FirestoreService.instance.addFavourite(uid, cleanId);
      } else {
        await FirestoreService.instance.removeFavourite(uid, cleanId);
      }
    } catch (e) {
      if (mounted) {
        // Rollback optimistic update on error
        setState(() {
          if (isAdding) {
            _favouriteIds.remove(cleanId);
          } else {
            _favouriteIds.add(cleanId);
          }
        });
        final msg = FirestoreService.getFriendlyErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update saved home: $msg'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      if (index == 2) {
        _postInitialTab = 0;
      }
      _selectedIndex = index;
    });
  }

  void _navigateToMyListings() {
    setState(() {
      _postInitialTab = 1;
      _selectedIndex = 2;
    });
  }

  void _navigateToSaved() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _navigateToHome() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _handleRentalRequestSubmitted(RentalRequest request) {
    setState(() {
      _rentalRequests.removeWhere((r) => r.id == request.id);
      _rentalRequests.insert(0, request);
    });
  }

  void _handleCancelRentalRequest(String id) async {
    final isCloud = _userCloudRentalRequests.any((r) => r.id == id);
    if (isCloud && _firebaseUser != null) {
      try {
        await FirestoreService.instance.cancelRentalRequest(
          requestId: id,
          tenantId: _firebaseUser!.uid,
        );
      } catch (e) {
        debugPrint('Cancel rental request error: $e');
      }
    } else {
      setState(() {
        _rentalRequests.removeWhere((r) => r.id == id);
      });
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return HomeScreen(
          favouriteIds: _favouriteIds,
          onToggleFavourite: _toggleFavourite,
          onRentalRequestSubmitted: _handleRentalRequestSubmitted,
          approvedProperties: _approvedProperties,
          firebaseUser: _firebaseUser,
          onRequireSignIn: () => _openAuthSheet(),
          onPostProperty: () => setState(() => _selectedIndex = 2),
        );
      case 1:
        return SavedScreen(
          favouriteIds: _favouriteIds,
          onToggleFavourite: _toggleFavourite,
          onRentalRequestSubmitted: _handleRentalRequestSubmitted,
          approvedProperties: _approvedProperties,
          firebaseUser: _firebaseUser,
          onRequireSignIn: () => _openAuthSheet(),
        );
      case 2:
        return PostPropertyScreen(
          initialTab: _postInitialTab,
          myListings: _firebaseUser != null ? _userCloudListings : _myListings,
          firebaseUser: _firebaseUser,
          onRequireSignIn: () => _openAuthSheet(),
          onListingSubmitted: (newListing) {
            setState(() {
              if (_firebaseUser != null) {
                _userCloudListings.removeWhere(
                  (item) => item.id == newListing.id,
                );
                _userCloudListings.insert(0, newListing);
              } else {
                _myListings.insert(0, newListing);
              }
            });
          },
          onListingDeleted: (id) {
            setState(() {
              if (_firebaseUser != null) {
                _userCloudListings.removeWhere((item) => item.id == id);
              } else {
                _myListings.removeWhere((item) => item.id == id);
              }
            });
          },
        );
      case 3:
        return ProfileScreen(
          profile: _userProfile,
          firebaseUser: _firebaseUser,
          onSignOut: () {
            _unsubscribeAndRestoreGuestFavourites();
            _unsubscribeUserListings();
            _unsubscribeTenantRequests();
            setState(() {
              _firebaseUser = null;
              _userProfile = _defaultGuestProfile;
            });
          },
          onProfileUpdated: (updated) {
            setState(() {
              _userProfile = updated;
            });
          },
          listingsCount: _firebaseUser != null ? _userCloudListings.length : 0,
          savedCount: _favouriteIds.length,
          rentalRequests: _firebaseUser != null
              ? _userCloudRentalRequests
              : _rentalRequests,
          onCancelRentalRequest: _handleCancelRentalRequest,
          onNavigateToMyListings: _navigateToMyListings,
          onNavigateToSaved: _navigateToSaved,
          onNavigateToHome: _navigateToHome,
        );
      default:
        return HomeScreen(
          favouriteIds: _favouriteIds,
          onToggleFavourite: _toggleFavourite,
          onRentalRequestSubmitted: _handleRentalRequestSubmitted,
          approvedProperties: _approvedProperties,
          firebaseUser: _firebaseUser,
          onRequireSignIn: () => _openAuthSheet(),
          onPostProperty: () => setState(() => _selectedIndex = 2),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedCount = _favouriteIds.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: _buildBody(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.darkGreen),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: savedCount > 0,
                label: Text('$savedCount'),
                child: const Icon(Icons.favorite_border),
              ),
              selectedIcon: const Icon(Icons.favorite),
              label: 'Saved',
            ),
            const NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Post',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home screen

class SavedScreen extends StatelessWidget {
  const SavedScreen({
    super.key,
    required this.favouriteIds,
    required this.onToggleFavourite,
    this.onRentalRequestSubmitted,
    this.approvedProperties = const [],
    this.firebaseUser,
    this.onRequireSignIn,
  });

  final Set<String> favouriteIds;
  final ValueChanged<String> onToggleFavourite;
  final ValueChanged<RentalRequest>? onRentalRequestSubmitted;
  final List<Property> approvedProperties;
  final User? firebaseUser;
  final VoidCallback? onRequireSignIn;

  @override
  Widget build(BuildContext context) {
    final savedProperties = approvedProperties
        .where((property) => favouriteIds.contains(property.id))
        .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved Homes',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${savedProperties.length} homes saved',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: savedProperties.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: AppColors.green,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No saved homes yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the heart on any home to save it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () {
                              // Return to the Home tab.
                              // The parent handles navigation below.
                              Navigator.of(context).maybePop();
                            },
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('Explore homes'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: savedProperties.length,
                    itemBuilder: (context, index) {
                      final property = savedProperties[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PropertyCard(
                          key: ValueKey(property.id),
                          property: property,
                          isFavourite: true,
                          onFavouriteTap: () {
                            onToggleFavourite(property.id);
                          },
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PropertyDetailsScreen(
                                  property: property,
                                  favouriteIds: favouriteIds,
                                  onToggleFavourite: onToggleFavourite,
                                  onRentalRequestSubmitted:
                                      onRentalRequestSubmitted,
                                  firebaseUser: firebaseUser,
                                  onRequireSignIn: onRequireSignIn,
                                ),
                              ),
                            );
                          },
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.favouriteIds,
    required this.onToggleFavourite,
    this.onRentalRequestSubmitted,
    this.approvedProperties = const [],
    this.firebaseUser,
    this.onRequireSignIn,
    this.onPostProperty,
  });

  final Set<String> favouriteIds;
  final ValueChanged<String> onToggleFavourite;
  final ValueChanged<RentalRequest>? onRentalRequestSubmitted;
  final List<Property> approvedProperties;
  final User? firebaseUser;
  final VoidCallback? onRequireSignIn;
  final VoidCallback? onPostProperty;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  PropertyFilter _filter = PropertyFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Property> get _results {
    final q = _query.trim().toLowerCase();
    final properties = widget.approvedProperties;
    return properties.where((property) {
      final matchesFilter = _filter.matches(property.type);
      final matchesQuery =
          q.isEmpty ||
          property.title.toLowerCase().contains(q) ||
          property.area.toLowerCase().contains(q) ||
          property.landmark.toLowerCase().contains(q);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
    });
  }

  void _resetAll() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filter = PropertyFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: HomeHeader(
            controller: _searchController,
            hasText: _query.isNotEmpty,
            onChanged: (value) => setState(() => _query = value),
            onClear: _clearSearch,
          ),
        ),
        SliverToBoxAdapter(
          child: FilterChipsRow(
            selected: _filter,
            onSelected: (filter) => setState(() => _filter = filter),
          ),
        ),
        if (results.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                results.length == 1
                    ? '1 home available'
                    : '${results.length} homes available',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              hasApprovedProperties: widget.approvedProperties.isNotEmpty,
              query: _query.trim(),
              filter: _filter,
              onReset: _resetAll,
              onPostProperty: widget.onPostProperty,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final property = results[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PropertyCard(
                    key: ValueKey(property.id),
                    property: property,
                    isFavourite: widget.favouriteIds.contains(property.id),
                    onFavouriteTap: () => widget.onToggleFavourite(property.id),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PropertyDetailsScreen(
                            property: property,
                            favouriteIds: widget.favouriteIds,
                            onToggleFavourite: widget.onToggleFavourite,
                            onRentalRequestSubmitted:
                                widget.onRentalRequestSubmitted,
                            firebaseUser: widget.firebaseUser,
                            onRequireSignIn: widget.onRequireSignIn,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }, childCount: results.length),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header with app name, tagline and search field
// ---------------------------------------------------------------------------

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: AppColors.green,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to',
                    style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                  ),
                  Text(
                    'BashaLagbe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Find your next rental home in Bangladesh: flats, rooms and mess seats near the places you love.',
            style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search area, property or landmark',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: AppColors.green),
              suffixIcon: hasText
                  ? IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: onClear,
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.darkGreen,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips
// ---------------------------------------------------------------------------

class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PropertyFilter selected;
  final ValueChanged<PropertyFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: PropertyFilter.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = PropertyFilter.values[index];
          final isSelected = filter == selected;
          return FilterChip(
            label: Text(filter.label),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(filter),
            backgroundColor: Colors.white,
            selectedColor: AppColors.green,
            side: BorderSide(
              color: isSelected ? AppColors.green : AppColors.border,
            ),
            shape: const StadiumBorder(),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Property card
// ---------------------------------------------------------------------------

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    required this.isFavourite,
    required this.onFavouriteTap,
    required this.onTap,
  });

  final Property property;
  final bool isFavourite;
  final VoidCallback onFavouriteTap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PropertyImagePlaceholder(property: property),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: isFavourite
                          ? 'Remove from saved'
                          : 'Save this home',
                      onPressed: onFavouriteTap,
                      icon: Icon(
                        isFavourite ? Icons.favorite : Icons.favorite_border,
                        color: isFavourite
                            ? AppColors.heart
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: property.isDemo
                          ? Colors.black.withValues(alpha: 0.70)
                          : AppColors.darkGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          property.isDemo
                              ? Icons.info_outline
                              : Icons.verified_outlined,
                          size: 12,
                          color: property.isDemo
                              ? Colors.amberAccent
                              : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          property.isDemo ? 'Demo Preview' : 'Verified Cloud',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatTaka(property.rentPerMonth),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text(
                          '/ month',
                          style: TextStyle(
                            fontSize: 13,
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
                  const SizedBox(height: 8),
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.area,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.landmark,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoPill(
                        icon: Icons.bed_outlined,
                        label: property.bedrooms == 1
                            ? '1 bedroom'
                            : '${property.bedrooms} bedrooms',
                      ),
                      InfoPill(
                        icon: Icons.bathtub_outlined,
                        label: property.bathrooms == 1
                            ? '1 bathroom'
                            : '${property.bathrooms} bathrooms',
                      ),
                      InfoPill(
                        icon: property.availableNow
                            ? Icons.check_circle_outline
                            : Icons.event_outlined,
                        label: property.availability,
                        background: property.availableNow
                            ? AppColors.lightGreen
                            : AppColors.amberLight,
                        foreground: property.availableNow
                            ? AppColors.darkGreen
                            : AppColors.amber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder "photo" made from built-in widgets
// ---------------------------------------------------------------------------

class PropertyImagePlaceholder extends StatelessWidget {
  const PropertyImagePlaceholder({super.key, required this.property});

  final Property property;

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x22FFFFFF),
      ),
    );
  }

  Widget _buildGradientPlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [property.gradientStart, property.gradientEnd],
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -30, top: -30, child: _circle(130)),
          Positioned(left: -25, bottom: -45, child: _circle(120)),
          Positioned(left: 70, top: 20, child: _circle(36)),
          Center(
            child: Icon(
              property.icon,
              size: 72,
              color: const Color(0xDDFFFFFF),
            ),
          ),
          if (property.isDemo)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'DEMO LISTING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PropertyPhoto? coverPhoto;
    for (final p in property.photos) {
      if (p.isCover && p.isNetworkPhoto) {
        coverPhoto = p;
        break;
      }
    }
    if (coverPhoto == null) {
      for (final p in property.photos) {
        if (p.isNetworkPhoto) {
          coverPhoto = p;
          break;
        }
      }
    }

    if (coverPhoto != null && coverPhoto.imageUrl != null) {
      return SizedBox(
        height: 160,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              coverPhoto.imageUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: AppColors.lightGreen,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
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
                  _buildGradientPlaceholder(),
            ),
            if (property.isDemo)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'DEMO LISTING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return _buildGradientPlaceholder();
  }
}

// ---------------------------------------------------------------------------
// Small reusable pill (icon + text)
// ---------------------------------------------------------------------------

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.icon,
    required this.label,
    this.background = AppColors.secondarySage,
    this.foreground = AppColors.textDark,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.hasApprovedProperties,
    required this.query,
    this.filter = PropertyFilter.all,
    required this.onReset,
    this.onPostProperty,
  });

  final bool hasApprovedProperties;
  final String query;
  final PropertyFilter filter;
  final VoidCallback onReset;
  final VoidCallback? onPostProperty;

  @override
  Widget build(BuildContext context) {
    if (!hasApprovedProperties) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.home_work_outlined,
                size: 48,
                color: AppColors.green,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No approved properties yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Verified rental apartments and rooms will appear here once reviewed and approved by moderators.\n\nAre you a property owner? Post your listing today!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            if (onPostProperty != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onPostProperty,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_home_outlined),
                label: const Text(
                  'Post a Property',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final message = query.isNotEmpty
        ? 'We could not find any homes matching "$query".'
        : 'There are no available homes in the "${filter.label}" category.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No matching homes found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$message\nTry searching for another neighborhood or landmark, or clear your filters.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onReset,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Clear search and filters'),
          ),
        ],
      ),
    );
  }
}
