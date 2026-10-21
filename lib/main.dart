import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:basha_lagbe/property_details_screen.dart';

void main() {
  runApp(const BashaLagbeApp());
}

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

class AppColors {
  static const Color green = Color(0xFF1B8A5A);
  static const Color darkGreen = Color(0xFF0E5E3B);
  static const Color lightGreen = Color(0xFFE3F4EA);
  static const Color background = Color(0xFFF5FAF6);
  static const Color border = Color(0xFFDDEBE2);
  static const Color textDark = Color(0xFF1C2B24);
  static const Color textMuted = Color(0xFF66766D);
  static const Color amber = Color(0xFFB7791F);
  static const Color amberLight = Color(0xFFFFF3D6);
  static const Color heart = Color(0xFFE53935);
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class BashaLagbeApp extends StatelessWidget {
  const BashaLagbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BashaLagbe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.lightGreen,
        ),
      ),
      home: const MainShell(),
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
}

// All of these listings are fictional and for design preview only.
const List<Property> demoProperties = [
  Property(
    id: 'demo-1',
    title: 'Green Nest Family Flat',
    area: 'Mirpur 10, Dhaka',
    landmark: 'Near Mirpur 10 Metro Rail Station',
    fullAddress: 'Road 4, Block C, Section 10, Mirpur, Dhaka',
    rentPerMonth: 18000,
    depositAmount: 36000,
    sizeSqFt: 1250,
    floorLevel: '4th Floor (Lift-3)',
    balconies: 2,
    type: PropertyType.family,
    bedrooms: 3,
    bathrooms: 2,
    availability: 'Available now',
    availableNow: true,
    icon: Icons.apartment,
    gradientStart: Color(0xFF2E9E6B),
    gradientEnd: Color(0xFF0E5E3B),
    description:
        'Spacious, naturally lit south-facing family apartment in a gated residential building. Excellent cross-ventilation, separate drawing and dining spaces, and child-safe balcony railings.',
    facilities: [
      'Lift (Elevator)',
      'Standby Generator',
      'Titas Pipeline Gas',
      '24/7 Guard & CCTV',
      'Car Parking Available',
      'South-facing Balcony',
      'Water Supply 24/7',
    ],
    nearbyHighlights: [
      'Mirpur 10 Metro Rail Station (3 min walk)',
      'Mirpur Girls Ideal School & College (5 min)',
      'Benarosi Palli & Local Supermarket (4 min)',
      'Central Jam-e Mosque (2 min)',
    ],
    utilityNotice: 'Gas & water included in service charge; electricity prepaid sub-meter.',
    photos: [
      PropertyPhoto(
        label: 'Living & Dining Hall',
        icon: Icons.chair_outlined,
        gradientStart: Color(0xFF2E9E6B),
        gradientEnd: Color(0xFF0E5E3B),
      ),
      PropertyPhoto(
        label: 'Master Bedroom',
        icon: Icons.bed_outlined,
        gradientStart: Color(0xFF38A169),
        gradientEnd: Color(0xFF1B6B45),
      ),
      PropertyPhoto(
        label: 'Modern Fitted Kitchen',
        icon: Icons.kitchen_outlined,
        gradientStart: Color(0xFF2B8A68),
        gradientEnd: Color(0xFF104D36),
      ),
      PropertyPhoto(
        label: 'South Balcony View',
        icon: Icons.balcony_outlined,
        gradientStart: Color(0xFF48BB78),
        gradientEnd: Color(0xFF22543D),
      ),
    ],
  ),
  Property(
    id: 'demo-2',
    title: 'Lakeview Bachelor Room',
    area: 'Dhanmondi, Dhaka',
    landmark: 'Near Dhanmondi Lake',
    fullAddress: 'Road 8/A, Dhanmondi R/A, Dhaka',
    rentPerMonth: 9500,
    depositAmount: 9500,
    sizeSqFt: 380,
    floorLevel: '3rd Floor',
    balconies: 1,
    type: PropertyType.bachelor,
    bedrooms: 1,
    bathrooms: 1,
    availability: 'Available from 1 Nov',
    availableNow: false,
    icon: Icons.home_work,
    gradientStart: Color(0xFF3AA6A0),
    gradientEnd: Color(0xFF176B66),
    description:
        'Peaceful and secure bachelor room with attached tiled washroom and private lake-facing balcony. Ideal for university students or young professionals looking for a calm study atmosphere.',
    facilities: [
      'Attached Bathroom',
      'Lake-facing Balcony',
      'High-speed Wi-Fi Ready',
      'Filtered Drinking Water',
      '24/7 Security Guard',
      'Daily Maid Cleaning Option',
    ],
    nearbyHighlights: [
      'Dhanmondi Lake Park (1 min walk)',
      'Rapa Plaza & Metro Shopping Mall (6 min)',
      'Food Courts & Dhanmondi 27 Hub (5 min)',
    ],
    utilityNotice: 'Wi-Fi and water included; shared electricity divided equally.',
    photos: [
      PropertyPhoto(
        label: 'Bachelor Room',
        icon: Icons.single_bed_outlined,
        gradientStart: Color(0xFF3AA6A0),
        gradientEnd: Color(0xFF176B66),
      ),
      PropertyPhoto(
        label: 'Attached Bathroom',
        icon: Icons.bathtub_outlined,
        gradientStart: Color(0xFF319795),
        gradientEnd: Color(0xFF234E52),
      ),
      PropertyPhoto(
        label: 'Lake View Balcony',
        icon: Icons.deck_outlined,
        gradientStart: Color(0xFF4FD1C5),
        gradientEnd: Color(0xFF285E61),
      ),
    ],
  ),
  Property(
    id: 'demo-3',
    title: 'Sunrise Shared Mess Seat',
    area: 'Mohammadpur, Dhaka',
    landmark: 'Near Mohammadpur Town Hall',
    fullAddress: 'Noorjahan Road, Mohammadpur, Dhaka',
    rentPerMonth: 4500,
    depositAmount: 4500,
    sizeSqFt: 220,
    floorLevel: '2nd Floor',
    balconies: 1,
    type: PropertyType.shared,
    bedrooms: 1,
    bathrooms: 1,
    availability: 'Available now',
    availableNow: true,
    icon: Icons.groups,
    gradientStart: Color(0xFF6BB26B),
    gradientEnd: Color(0xFF2F7A3F),
    description:
        'Cozy single seat in a friendly 2-person shared room with managed mess meal system. Conveniently located near Mohammadpur Town Hall market and bus stands.',
    facilities: [
      'Running Meal System (3 times)',
      'High-speed Wi-Fi',
      'Drinking Water Filter',
      'Housekeeping Service',
      'Shared Fridge & Kitchen',
    ],
    nearbyHighlights: [
      'Mohammadpur Town Hall Market (2 min walk)',
      'Mohammadpur Bus Stand (5 min walk)',
      'Krishi Market & Daily Bazaar (4 min)',
    ],
    utilityNotice: 'Gas, electricity and Wi-Fi included in monthly rent. Meals charged per meal.',
    photos: [
      PropertyPhoto(
        label: 'Shared Bed Space',
        icon: Icons.bed_outlined,
        gradientStart: Color(0xFF6BB26B),
        gradientEnd: Color(0xFF2F7A3F),
      ),
      PropertyPhoto(
        label: 'Common Study & Dining',
        icon: Icons.table_restaurant_outlined,
        gradientStart: Color(0xFF48BB78),
        gradientEnd: Color(0xFF276749),
      ),
    ],
  ),
  Property(
    id: 'demo-4',
    title: 'Palm Court Apartment',
    area: 'Uttara Sector 7, Dhaka',
    landmark: 'Near Uttara North Metro Station',
    fullAddress: 'Road 12, Sector 7, Uttara, Dhaka',
    rentPerMonth: 25000,
    depositAmount: 50000,
    sizeSqFt: 1550,
    floorLevel: '6th Floor (Lift)',
    balconies: 3,
    type: PropertyType.family,
    bedrooms: 3,
    bathrooms: 3,
    availability: 'Available from 15 Nov',
    availableNow: false,
    icon: Icons.domain,
    gradientStart: Color(0xFF45A880),
    gradientEnd: Color(0xFF14654A),
    description:
        'Premium 3-bedroom family apartment with imported fittings, master bath tub, expansive open kitchen, and reserved basement parking in a quiet neighborhood of Uttara.',
    facilities: [
      'Twin High-speed Lifts',
      'Full Standby Generator (including AC)',
      'Reserved Car Parking Slot',
      'CCTV Surveillance & Guard 24/7',
      'Intercom & Fire Safety System',
      '3 Wide Balconies',
    ],
    nearbyHighlights: [
      'Uttara North Metro Station (5 min)',
      'Sector 7 Central Park & Lake (3 min walk)',
      'Scholastica & Milestone College (6 min)',
    ],
    utilityNotice: 'Prepaid electricity; service charge includes gas, water and generator maintenance.',
    photos: [
      PropertyPhoto(
        label: 'Spacious Drawing Room',
        icon: Icons.weekend_outlined,
        gradientStart: Color(0xFF45A880),
        gradientEnd: Color(0xFF14654A),
      ),
      PropertyPhoto(
        label: 'Master Bedroom Suite',
        icon: Icons.bed_outlined,
        gradientStart: Color(0xFF38B2AC),
        gradientEnd: Color(0xFF234E52),
      ),
      PropertyPhoto(
        label: 'Kitchen & Dining Area',
        icon: Icons.kitchen_outlined,
        gradientStart: Color(0xFF4FD1C5),
        gradientEnd: Color(0xFF1D4044),
      ),
      PropertyPhoto(
        label: 'Corner Balcony',
        icon: Icons.balcony_outlined,
        gradientStart: Color(0xFF2C7A7B),
        gradientEnd: Color(0xFF1A365D),
      ),
    ],
  ),
  Property(
    id: 'demo-5',
    title: 'Campus Corner Studio',
    area: 'Bashundhara R/A, Dhaka',
    landmark: 'Near Jamuna Future Park',
    fullAddress: 'Block D, Bashundhara R/A, Dhaka',
    rentPerMonth: 12000,
    depositAmount: 12000,
    sizeSqFt: 520,
    floorLevel: '2nd Floor',
    balconies: 1,
    type: PropertyType.bachelor,
    bedrooms: 1,
    bathrooms: 1,
    availability: 'Available now',
    availableNow: true,
    icon: Icons.house,
    gradientStart: Color(0xFF52B788),
    gradientEnd: Color(0xFF1F7A56),
    description:
        'Modern studio apartment tailored for university students or tech professionals. Walking distance to private universities, supermarkets, and fitness gyms.',
    facilities: [
      'Elevator / Lift',
      'Standby Generator Backup',
      'High-speed Fiber Wi-Fi Ready',
      'Security Guard & Intercom',
      'Modern Kitchenette',
    ],
    nearbyHighlights: [
      'North South University & IUB (6 min)',
      'Jamuna Future Park (7 min)',
      'Evercare Hospital Dhaka (8 min)',
      'Meena Bazar & Gyms (3 min walk)',
    ],
    utilityNotice: 'Water & security included; electricity as per digital sub-meter.',
    photos: [
      PropertyPhoto(
        label: 'Studio Room & Desk Space',
        icon: Icons.laptop_chromebook_outlined,
        gradientStart: Color(0xFF52B788),
        gradientEnd: Color(0xFF1F7A56),
      ),
      PropertyPhoto(
        label: 'Kitchenette & Bath',
        icon: Icons.microwave_outlined,
        gradientStart: Color(0xFF68D391),
        gradientEnd: Color(0xFF276749),
      ),
    ],
  ),
  Property(
    id: 'demo-6',
    title: 'Hilltop Family Home',
    area: 'Zindabazar, Sylhet',
    landmark: 'Near Zindabazar Point',
    fullAddress: 'Jallarpar Road, Zindabazar, Sylhet',
    rentPerMonth: 15000,
    depositAmount: 30000,
    sizeSqFt: 1100,
    floorLevel: '3rd Floor',
    balconies: 2,
    type: PropertyType.family,
    bedrooms: 2,
    bathrooms: 2,
    availability: 'Available from 1 Dec',
    availableNow: false,
    icon: Icons.cottage,
    gradientStart: Color(0xFF4FAE8C),
    gradientEnd: Color(0xFF1A6B55),
    description:
        'Peaceful and airy family residence in central Sylhet. Offers refreshing natural breezes, high ceilings, rooftop access, and hassle-free city connection.',
    facilities: [
      '24/7 Deep Tube-well Water',
      'Generator Power Backup',
      '2 Spacious Balconies',
      'Dedicated Bike & Car Parking',
      'Rooftop Garden Access',
    ],
    nearbyHighlights: [
      'Zindabazar Point & Shopping Mall (3 min walk)',
      'Sylhet Central Jam-e Mosque (4 min)',
      'Shahi Eidgah & Parks (7 min)',
    ],
    utilityNotice: 'Gas & water included; DESCO/BPDB electricity by user meter.',
    photos: [
      PropertyPhoto(
        label: 'Main Living Room',
        icon: Icons.living_outlined,
        gradientStart: Color(0xFF4FAE8C),
        gradientEnd: Color(0xFF1A6B55),
      ),
      PropertyPhoto(
        label: 'Master Bedroom',
        icon: Icons.bedroom_parent_outlined,
        gradientStart: Color(0xFF38A169),
        gradientEnd: Color(0xFF1C4532),
      ),
    ],
  ),
  Property(
    id: 'demo-7',
    title: 'Harbour Side Shared Flat',
    area: 'Agrabad, Chattogram',
    landmark: 'Near Agrabad Commercial Area',
    fullAddress: 'Badamtoli Mor, Agrabad C/A, Chattogram',
    rentPerMonth: 7000,
    depositAmount: 7000,
    sizeSqFt: 620,
    floorLevel: '4th Floor',
    balconies: 1,
    type: PropertyType.shared,
    bedrooms: 2,
    bathrooms: 1,
    availability: 'Available now',
    availableNow: true,
    icon: Icons.holiday_village,
    gradientStart: Color(0xFF3C9D9B),
    gradientEnd: Color(0xFF15616A),
    description:
        'Well-connected executive shared flat for commercial professionals and port personnel working in Chattogram. Well-kept with dedicated study spaces.',
    facilities: [
      'Generator Power Backup',
      'High-speed Wi-Fi',
      '24/7 Security Gate',
      'Balcony with Port Breeze',
      'Water Filter & Fridge',
    ],
    nearbyHighlights: [
      'World Trade Center Chattogram (4 min)',
      'Agrabad Commercial Bank Zone (3 min walk)',
      'Access Road Bus Stops (2 min walk)',
    ],
    utilityNotice: 'Electricity and Wi-Fi included in rent.',
    photos: [
      PropertyPhoto(
        label: 'Shared Bedroom',
        icon: Icons.bed_outlined,
        gradientStart: Color(0xFF3C9D9B),
        gradientEnd: Color(0xFF15616A),
      ),
      PropertyPhoto(
        label: 'City View Balcony',
        icon: Icons.deck_outlined,
        gradientStart: Color(0xFF4FD1C5),
        gradientEnd: Color(0xFF234E52),
      ),
    ],
  ),
  Property(
    id: 'demo-8',
    title: 'Banani Garden Flat',
    area: 'Banani, Dhaka',
    landmark: 'Near Banani Road 11',
    fullAddress: 'Road 11, Block D, Banani, Dhaka',
    rentPerMonth: 32000,
    depositAmount: 64000,
    sizeSqFt: 1850,
    floorLevel: '5th Floor (Lift)',
    balconies: 3,
    type: PropertyType.family,
    bedrooms: 4,
    bathrooms: 3,
    availability: 'Available from 10 Nov',
    availableNow: false,
    icon: Icons.villa,
    gradientStart: Color(0xFF2F9E5E),
    gradientEnd: Color(0xFF0B5A35),
    description:
        'Luxurious and peaceful 4-bedroom flat nestled in prime Banani. Close to top dining, embassies, international schools, and serene community parks.',
    facilities: [
      'Dual Elevator System',
      'Full Heavy Generator Backup',
      '2 Reserved Basement Car Parks',
      '24/7 CCTV & Professional Guards',
      'Modular Kitchen with Gas Line',
      'Intercom & Video Door Phone',
    ],
    nearbyHighlights: [
      'Banani Road 11 Dining Hub (2 min walk)',
      'Kamal Ataturk Avenue (4 min walk)',
      'Banani Lake Park & Walking Track (5 min)',
      'American International School & Embaassies (7 min)',
    ],
    utilityNotice: 'Maintenance service charge covers generator, gas, security and cleaning.',
    photos: [
      PropertyPhoto(
        label: 'Designer Drawing Room',
        icon: Icons.weekend_outlined,
        gradientStart: Color(0xFF2F9E5E),
        gradientEnd: Color(0xFF0B5A35),
      ),
      PropertyPhoto(
        label: 'Master Bedroom with Balcony',
        icon: Icons.bedroom_parent_outlined,
        gradientStart: Color(0xFF38A169),
        gradientEnd: Color(0xFF1B4D3E),
      ),
      PropertyPhoto(
        label: 'Gourmet Kitchen',
        icon: Icons.kitchen_outlined,
        gradientStart: Color(0xFF48BB78),
        gradientEnd: Color(0xFF22543D),
      ),
      PropertyPhoto(
        label: 'Greenery Balcony View',
        icon: Icons.park_outlined,
        gradientStart: Color(0xFF285E61),
        gradientEnd: Color(0xFF1A365D),
      ),
    ],
  ),
];

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
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final Set<String> _favouriteIds = <String>{};
  int _selectedIndex = 0;

  void _toggleFavourite(String id) {
    setState(() {
      if (!_favouriteIds.add(id)) {
        _favouriteIds.remove(id);
      }
    });
  }

  void _onDestinationSelected(int index) {
    if (index == 2) {
      showFriendlyMessage(context, 'The Post Property feature is coming soon!');
      return;
    }

    if (index == 3) {
      showFriendlyMessage(context, 'The Profile feature is coming soon!');
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final savedCount = _favouriteIds.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: _selectedIndex == 0
            ? HomeScreen(
                favouriteIds: _favouriteIds,
                onToggleFavourite: _toggleFavourite,
              )
            : SavedScreen(
                favouriteIds: _favouriteIds,
                onToggleFavourite: _toggleFavourite,
              ),
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
  });

  final Set<String> favouriteIds;
  final ValueChanged<String> onToggleFavourite;

  @override
  Widget build(BuildContext context) {
    final savedProperties = demoProperties
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
  });

  final Set<String> favouriteIds;
  final ValueChanged<String> onToggleFavourite;

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
    return demoProperties.where((property) {
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DemoNotice(),
                const SizedBox(height: 14),
                Text(
                  results.length == 1
                      ? '1 demo home found'
                      : '${results.length} demo homes found',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(query: _query.trim(), onReset: _resetAll),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green, AppColors.darkGreen],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
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
                borderSide: BorderSide.none,
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
// Demo notice
// ---------------------------------------------------------------------------

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amberLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.amber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Demo listings: all homes shown here are fictional samples for design preview. They are not real, verified or available properties.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(20),
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
                          color: AppColors.darkGreen,
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

  @override
  Widget build(BuildContext context) {
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
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
}

// ---------------------------------------------------------------------------
// Small reusable pill (icon + text)
// ---------------------------------------------------------------------------

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.icon,
    required this.label,
    this.background = const Color(0xFFF0F4F1),
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
  const EmptyState({super.key, required this.query, required this.onReset});

  final String query;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final message = query.isEmpty
        ? 'There are no demo homes in this category yet.'
        : 'We could not find any demo homes matching "$query".';

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
            'No homes found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$message\nTry another area such as Mirpur, Uttara or Sylhet, or search by a nearby landmark.',
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
