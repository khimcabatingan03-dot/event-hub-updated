import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../form_feedback.dart';
import '../helpers.dart';
import '../services/auth_services.dart';
import '../services/firestore_service.dart';
import '../services/notification_store.dart';
import 'categories_screen.dart';
import 'event_details_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'my_events_screen.dart';
import 'notifications_screen.dart';
import 'set_password_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // bottom navigation
  int currentTab = 0;

  // the shell that hosts every page (home, categories, my events,
  // history, notifications, event details) so the bottom
  // navigation bar below stays visible at all times
  final GlobalKey<NavigatorState> _shellNav = GlobalKey<NavigatorState>();
  late final _ShellTabObserver _tabObserver = _ShellTabObserver(
    _onShellTabChanged,
  );

  // keeps the highlighted button in sync with the page on top
  void _onShellTabChanged(int tab) {
    if (!mounted || currentTab == tab) return;
    setState(() => currentTab = tab);
  }

  // search bar text
  String searchText = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // selected category filter
  String selectedCategory = 'All';

  // filter sheet choices
  String whenFilter = 'Anytime';
  String sortBy = 'Date';
  bool hidePast = false;

  // how many extra filters are on (shown as a badge on the button)
  int get activeFilterCount {
    int count = 0;
    if (whenFilter != 'Anytime') count++;
    if (sortBy != 'Date') count++;
    if (hidePast) count++;
    return count;
  }

  // the heading above the list — changes with the chosen sort
  String get _listHeading {
    if (whenFilter == 'Already happened') return 'Past events';
    if (sortBy == 'Newest added') return 'Recently added';
    if (sortBy == 'Name A-Z') return 'All events';
    if (whenFilter != 'Anytime') return whenFilter;
    return 'Upcoming';
  }

  @override
  void initState() {
    super.initState();
    // load the local notifications (bell feed / badge) and seed the
    // welcome messages the first time
    NotificationStore.instance.ensureLoaded().then((_) {
      NotificationStore.instance.seedSamples();
    });

    // give any old random Firestore ids readable names, then add the
    // sample events one time (only when the list is empty) and clear
    // the old notification collection that is no longer used
    FirestoreService().makeIdsReadable().then((_) {
      FirestoreService().addSampleEvents();
      FirestoreService().removeStoredNotifications();
    });

    // Google users without a password yet: offer to set one up
    _offerPasswordSetupOnce();
  }

  // the AlertDialog is only shown once per app run
  static bool _passwordOfferShown = false;

  void _offerPasswordSetupOnce() {
    if (_passwordOfferShown) return;
    if (!AuthService().currentUserNeedsPassword()) return;
    _passwordOfferShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      String email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Set up an EventHub password?'),
          content: const Text(
            'You are signed in with Google only. Add an EventHub password '
            '(never your Google password) so you can also log in with your '
            'email and password — no second account is created.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Not now',
                style: TextStyle(color: AppColors.greyText),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SetPasswordScreen(email: email),
                  ),
                );
              },
              child: const Text(
                'Set password',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    });
  }

  // tapping the avatar: account details + the option to add a password
  void openAccountDialog() {
    User? user = FirebaseAuth.instance.currentUser;
    bool needsPassword = AuthService().currentUserNeedsPassword();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('My account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              textOf(user?.displayName).isEmpty
                  ? 'Student'
                  : textOf(user?.displayName),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              textOf(user?.email),
              style: const TextStyle(color: AppColors.greyText, fontSize: 13),
            ),
            if (needsPassword) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Signed in with Google only — no EventHub password yet.',
                      style: TextStyle(color: AppColors.greyText, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.greyText),
            ),
          ),
          if (needsPassword)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SetPasswordScreen(email: textOf(user?.email)),
                  ),
                );
              },
              child: const Text(
                'Set password',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  // the student's first name
  String firstName() {
    String? name = FirebaseAuth.instance.currentUser?.displayName;
    if (name == null || name.isEmpty) return 'Student';
    return name.split(' ').first;
  }

  // greeting based on the time of day
  String greeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // open the other pages from the bottom nav — they open inside
  // the shell so the bottom navigation bar stays visible
  void openPage(int index) {
    final NavigatorState? shell = _shellNav.currentState;
    if (shell == null) return;

    // going back to Home: close whatever page is open
    if (index == 0) {
      shell.popUntil((route) => route.isFirst);
      return;
    }

    final Widget page;
    if (index == 1) {
      page = const CategoriesScreen();
    } else if (index == 2) {
      page = const MyEventsScreen();
    } else {
      page = const HistoryScreen();
    }

    // switch tabs without stacking pages; remember which tab the
    // page belongs to (for the highlight)
    shell.pushAndRemoveUntil(
      MaterialPageRoute(
        settings: RouteSettings(name: 'tab:$index'),
        builder: (context) => page,
      ),
      (route) => route.isFirst,
    );
  }

  // ------------------------------------------------------------
  // FILTERS
  // ------------------------------------------------------------

  // The dateLabel is stored as "OCT 28" with no year, so we guess the
  // year: if that day already passed by more than 30 days we assume it
  // means next year's occurrence (campus events repeat annually).
  DateTime _eventDate(Map data) {
    DateTime date = getEventDate(textOf(data['dateLabel']));
    DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));
    if (date.isBefore(cutoff)) {
      date = DateTime(date.year + 1, date.month, date.day);
    }
    return date;
  }

  // does this event match the "When" choice?
  bool _matchesWhen(Map data) {
    if (whenFilter == 'Anytime') return true;

    final DateTime event = _eventDate(data);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    switch (whenFilter) {
      case 'Today':
        return event.isAtSameMomentAs(today);
      case 'This week':
        final DateTime end = today.add(const Duration(days: 7));
        return !event.isBefore(today) && event.isBefore(end);
      case 'This month':
        return event.year == now.year && event.month == now.month;
      case 'Later':
        // after the end of the current month
        final DateTime endOfMonth = DateTime(now.year, now.month + 1, 1);
        return event.isAfter(endOfMonth);
      case 'Already happened':
        return event.isBefore(today);
    }
    return true;
  }

  // has the event already finished?
  bool _isPast(Map data) => _eventDate(data).isBefore(DateTime.now());

  // put the filtered list in the chosen order
  void _sortEvents(List list) {
    list.sort((a, b) {
      final Map da = a.data() as Map;
      final Map db = b.data() as Map;

      switch (sortBy) {
        case 'Newest added':
          final dynamic ta = da['createdAt'];
          final dynamic tb = db['createdAt'];
          if (ta is Timestamp && tb is Timestamp) {
            return tb.compareTo(ta);
          }
          return 0;
        case 'Name A-Z':
          return textOf(
            da['title'],
          ).toLowerCase().compareTo(textOf(db['title']).toLowerCase());
        default: // soonest date first
          return _eventDate(da).compareTo(_eventDate(db));
      }
    });
  }

  // one selectable row inside the filter sheet
  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.dark,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // the heading above each group of options
  Widget _filterHeading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    ),
  );

  // open the filter bottom sheet
  Future<void> openFilters() async {
    // work on copies so Cancel really cancels
    String tempWhen = whenFilter;
    String tempSort = sortBy;
    bool tempHidePast = hidePast;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // title + reset
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter events',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          tempWhen = 'Anytime';
                          tempSort = 'Date';
                          tempHidePast = false;
                        }),
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ---- when ----
                  _filterHeading('When'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final String option in [
                        'Anytime',
                        'Today',
                        'This week',
                        'This month',
                        'Later',
                        'Already happened',
                      ])
                        _filterChip(
                          option,
                          tempWhen == option,
                          () => setSheetState(() => tempWhen = option),
                        ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ---- sort ----
                  _filterHeading('Sort by'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final String option in [
                        'Date',
                        'Newest added',
                        'Name A-Z',
                      ])
                        _filterChip(
                          option,
                          tempSort == option,
                          () => setSheetState(() => tempSort = option),
                        ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ---- past events ----
                  _filterHeading('Past events'),
                  SwitchListTile(
                    value: tempHidePast,
                    onChanged: (value) =>
                        setSheetState(() => tempHidePast = value),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Hide events that already happened',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Off means past events still show in the list',
                      style: TextStyle(color: AppColors.greyText, fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---- apply ----
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          whenFilter = tempWhen;
                          sortBy = tempSort;
                          hidePast = tempHidePast;
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: const Text(
                        'Show results',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // the shell: every page opens inside this nested navigator
      // so the bottom navigation bar stays visible on all screens
      body: Navigator(
        key: _shellNav,
        observers: [_tabObserver],
        onGenerateRoute: (settings) =>
            MaterialPageRoute(settings: settings, builder: _homeBody),
      ),

      // bottom navigation (pill shape)
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            navButton(0, Icons.home, 'Home'),
            navButton(1, Icons.grid_view, ''),
            navButton(2, Icons.event_note, ''),
            navButton(3, Icons.history, ''),
          ],
        ),
      ),
    );
  }

  // the home page content — the shell's first page
  Widget _homeBody(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // greeting row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // avatar with first letter of the name
                    // (tap for account details)
                    GestureDetector(
                      onTap: openAccountDialog,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.dark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          firstName().substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting(),
                          style: const TextStyle(
                            color: AppColors.greyText,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Hi, ${firstName()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    // notification bell with unread badge
                    // (count comes from the local notification list)
                    ListenableBuilder(
                      listenable: NotificationStore.instance,
                      builder: (context, _) {
                        int unread = NotificationStore.instance.unreadCount;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.notifications_none,
                                color: AppColors.dark,
                              ),
                            ),
                            // badge showing how many are unread
                            if (unread > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unread > 9 ? '9+' : '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    // log out
                    IconButton(
                      onPressed: () {
                        // the home screen context (outside the dialog)
                        final BuildContext homeContext = context;
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text('Log out?'),
                            content: const Text(
                              'Are you sure you want to log out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: AppColors.greyText),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  // messenger captured before the dialog
                                  // closes, so the message still shows
                                  final ScaffoldMessengerState messenger =
                                      ScaffoldMessenger.of(homeContext);
                                  Navigator.pop(dialogContext);
                                  await AuthService().logout();
                                  showSnackOn(messenger, 'Logged out.');
                                  if (homeContext.mounted) {
                                    // the root navigator replaces the
                                    // whole app (shell included)
                                    Navigator.of(
                                      homeContext,
                                      rootNavigator: true,
                                    ).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                                child: const Text(
                                  'Log out',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.logout,
                        color: AppColors.greyText,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // search bar + filter button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        searchText = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search events',
                      hintStyle: const TextStyle(color: AppColors.greyText),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.greyText,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F3F3),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // filter button
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        onPressed: openFilters,
                        icon: const Icon(Icons.tune, color: Colors.white),
                      ),
                    ),
                    // badge showing how many filters are on
                    if (activeFilterCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppColors.dark,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$activeFilterCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  categoryChip('All'),
                  const SizedBox(width: 8),
                  categoryChip('Academic'),
                  const SizedBox(width: 8),
                  categoryChip('Sports'),
                  const SizedBox(width: 8),
                  categoryChip('Seminar'),
                  const SizedBox(width: 8),
                  categoryChip('Entertainment'),
                  const SizedBox(width: 8),
                  categoryChip('Organization'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // the events list
            StreamBuilder<QuerySnapshot>(
              stream: FirestoreService().getEvents(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }

                // get the events, then apply search, category,
                // date filters and sorting
                List<QueryDocumentSnapshot> events = snapshot.data!.docs;
                List filtered = events.where((event) {
                  Map data = event.data() as Map;
                  bool matchSearch = textOf(
                    data['title'],
                  ).toLowerCase().contains(searchText);
                  bool matchCategory =
                      selectedCategory == 'All' ||
                      textOf(data['category']) == selectedCategory;
                  bool matchWhen = _matchesWhen(data);
                  bool matchPast = !hidePast || !_isPast(data);
                  return matchSearch && matchCategory && matchWhen && matchPast;
                }).toList();

                _sortEvents(filtered);

                if (filtered.isEmpty) {
                  bool filtersOn =
                      activeFilterCount > 0 ||
                      selectedCategory != 'All' ||
                      searchText.isNotEmpty;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.search_off,
                            color: AppColors.greyText,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            filtersOn
                                ? 'No events match your filters.'
                                : 'No events found.',
                            style: const TextStyle(color: AppColors.greyText),
                          ),
                          if (filtersOn) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  whenFilter = 'Anytime';
                                  sortBy = 'Date';
                                  hidePast = false;
                                  selectedCategory = 'All';
                                  searchText = '';
                                  searchController.clear();
                                });
                              },
                              child: const Text(
                                'Clear filters',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                // first event becomes the big featured card
                DocumentSnapshot firstEvent = filtered.first;
                Map firstData = firstEvent.data() as Map;
                List rest = filtered.skip(1).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // featured event card
                    featuredCard(firstEvent, firstData),

                    const SizedBox(height: 20),

                    // upcoming header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _listHeading,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            openPage(1); // go to categories
                          },
                          child: const Text(
                            'See all',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // the rest of the events
                    for (var event in rest)
                      eventCard(event, event.data() as Map),
                  ],
                );
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // one button in the bottom navigation
  Widget navButton(int index, IconData icon, String label) {
    bool selected = currentTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          currentTab = index;
        });
        openPage(index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label.isEmpty ? 14 : 18,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.greyText,
              size: 20,
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.greyText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // the category chips above the list
  Widget categoryChip(String category) {
    bool selected = selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.dark : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.dark,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // the big featured event card at the top
  Widget featuredCard(DocumentSnapshot event, Map data) {
    return GestureDetector(
      onTap: () {
        // open the event details inside the shell so the bottom
        // navigation bar stays visible
        _shellNav.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                EventDetailsScreen(eventId: event.id, data: data),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // category tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    textOf(data['category']),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                // date badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dateMonth(data['dateLabel']),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dateDay(data['dateLabel']),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // title
            Text(
              textOf(data['title']),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // time and location
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  timeStart(data['timeLabel']),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.location_on, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    textOf(data['location']),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // each event in the list
  Widget eventCard(DocumentSnapshot event, Map data) {
    return GestureDetector(
      onTap: () {
        // open the event details inside the shell so the bottom
        // navigation bar stays visible
        _shellNav.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                EventDetailsScreen(eventId: event.id, data: data),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDED)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // event image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                textOf(data['image']),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 52,
                  height: 52,
                  color: AppColors.primary,
                  child: const Icon(Icons.event, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // event info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // category tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E3E7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      textOf(data['category']),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    textOf(data['title']),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.greyText,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${textOf(data['dateLabel'])} · ${timeStart(data['timeLabel'])}',
                        style: const TextStyle(
                          color: AppColors.greyText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.greyText,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          textOf(data['location']),
                          style: const TextStyle(
                            color: AppColors.greyText,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: AppColors.greyText),
          ],
        ),
      ),
    );
  }
}

// watches the shell's navigator and keeps the highlighted bottom
// button in sync with the page that is showing (Home when a page
// is popped back to the start, the matching tab when one opens)
class _ShellTabObserver extends NavigatorObserver {
  _ShellTabObserver(this.onTabChanged);

  // called with the tab index that should look selected
  final void Function(int tab) onTabChanged;

  // tab pages are pushed with a "tab:<index>" route name
  static int? _tabOf(Route<dynamic>? route) {
    final String? name = route?.settings.name;
    if (name != null && name.startsWith('tab:')) {
      return int.tryParse(name.substring(4));
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final int? tab = _tabOf(route);
    if (tab != null) onTabChanged(tab);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // the page below became visible again
    onTabChanged(_tabOf(previousRoute) ?? 0);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // removed by a tab switch — the new page's didPush handles it
  }
}
