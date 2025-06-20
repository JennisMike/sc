import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:path_provider/path_provider.dart';
import 'package:swap_chat_leancloud/features/chat/models/conversation_model.dart';
import 'package:swap_chat_leancloud/features/chat/models/chat_message_model.dart';
import 'providers/profile_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/home/main_navigation.dart' as nav;
import 'screens/splash/splash_screen.dart';
import 'services/payment_service.dart';
import 'services/transaction_service.dart';
import 'services/auth_service.dart'; // Added for authServiceProvider
import 'services/notification_service.dart'; // Added for notificationServiceProvider
import 'utils/logger.dart';
import 'theme/app_theme.dart';

// Theme state provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

// Theme notifier class
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeMode = prefs.getString('themeMode');
    if (themeMode != null) {
      switch (themeMode) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        case 'system':
        default:
          state = ThemeMode.system;
          break;
      }
    } else {
      // Default to system theme if no preference is saved
      state = ThemeMode.system;
    }
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    ThemeMode newMode;
    
    // Cycle through the theme modes: system -> light -> dark -> system
    switch (state) {
      case ThemeMode.system:
        newMode = ThemeMode.light;
        await prefs.setString('themeMode', 'light');
        break;
      case ThemeMode.light:
        newMode = ThemeMode.dark;
        await prefs.setString('themeMode', 'dark');
        break;
      case ThemeMode.dark:
        newMode = ThemeMode.system;
        await prefs.setString('themeMode', 'system');
        break;
    }
    
    state = newMode;
  }
}

// Global Isar instance (can be provided via Riverpod later if preferred)
late Isar globalIsarInstance;

void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  if (notificationResponse.payload != null) {
    logger.info('notification payload: $payload');
  }
  // Handle notification tap
  // You can navigate to a specific screen based on the payload
}

final logger = AppLogger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    logger.info('Loading environment variables');
    await dotenv.load(fileName: ".env");

    // Initialize flutter_local_notifications
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();



    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings(
      'app_icon',
    );
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Initialize SharedPreferences for our providers
    final sharedPreferences = await SharedPreferences.getInstance();

    // Initialize Supabase
    logger.info('Initializing Supabase');
    await Supabase.initialize(
      url: dotenv.get('SUPABASE_URL'),
      anonKey: dotenv.get('SUPABASE_ANON_KEY'),
      debug: true, // Enable debug mode for better error logging
    );

    // Initialize Isar BEFORE other services that might depend on it or runApp
    logger.info('Initializing Isar database');
    final dir = await getApplicationDocumentsDirectory();
    globalIsarInstance = await Isar.open(
      [ConversationSchema, ChatMessageSchema], // Add ChatMessageSchema
      directory: dir.path,
      name: 'swapChatIsarDB', // Optional: name your Isar instance
    );
    logger.info('Isar database initialized');

    // Initialize services
    logger.info('Initializing services');
    final paymentService = PaymentService();
    final transactionService = TransactionService();
    await paymentService.init();

    // Run the app with Riverpod
    logger.info('Starting app with Riverpod');
    runApp(
      ProviderScope(
        overrides: [
          // Provide the SharedPreferences instance to our providers
          sharedPrefsProvider.overrideWithValue(sharedPreferences),
          // Provide the FlutterLocalNotificationsPlugin instance
          localNotificationsPluginProvider.overrideWithValue(flutterLocalNotificationsPlugin),
          // If you want to provide Isar instance via Riverpod:
          // isarInstanceProvider.overrideWithValue(globalIsarInstance),
        ],
        child: MyApp(
          paymentService: paymentService,
          transactionService: transactionService,
        ),
      ),
    );
  } catch (e, stack) {
    logger.error('Error during initialization', e, stack);
    // Show error UI
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Error: ${e.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Attempt to restart the app
                  main();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class MyApp extends ConsumerStatefulWidget {
  final PaymentService paymentService;
  final TransactionService transactionService;

  const MyApp({
    Key? key,
    required this.paymentService,
    required this.transactionService,
  }) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _initialCheckCompleted = false;
  bool _hasLocalSession = false;

  @override
  void initState() {
    super.initState();
    _checkLocalSession();
  }

  Future<void> _checkLocalSession() async {
    // Give Supabase a moment to load the session from storage
    await Future.delayed(const Duration(milliseconds: 500)); 
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (mounted) {
      setState(() {
        _hasLocalSession = currentSession != null;
        _initialCheckCompleted = true;
        print("MyApp: Initial local session check completed. Has local session: $_hasLocalSession");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    // Use the Supabase auth stream provider
    final authState = ref.watch(supabaseAuthStreamProvider);

    // Show splash screen while initial check (local session) or Supabase auth is loading
    if (!_initialCheckCompleted && !authState.hasValue) {
      print("MyApp: Initial checks not completed and Supabase auth not yet valued. Showing SplashScreen.");
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    print("MyApp: Building main UI based on Supabase auth state.");
    return MaterialApp(
      title: 'SwapChat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: authState.when(
        data: (supabaseAuthState) { // supabaseAuthState is Supabase AuthState
          final user = supabaseAuthState.session?.user;
          if (user != null) {
            print("MyApp: Supabase User Authenticated. User ID: ${user.id}. Showing MainNavigation.");
            // Activate NotificationService when user is authenticated
            ref.watch(notificationServiceProvider);
            print("MyApp: NotificationService activated for authenticated Supabase user.");

            // Ensure profile is loaded for the authenticated user
            // TODO: Verify profileRepositoryProvider compatibility with Supabase auth if it depends on auth state.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(profileRepositoryProvider.notifier).loadUserProfile();
            });
            return const nav.HomeScreen();
          } else {
            print("MyApp: Supabase User is not authenticated (session or user is null). Showing WelcomeScreen.");
            return const WelcomeScreen();
          }
        },
        loading: () {
          print("MyApp: Supabase Auth state is loading. Showing SplashScreen.");
          return const SplashScreen();
        },
        error: (error, stackTrace) {
          print("MyApp: Error in Supabase auth state: $error. Showing WelcomeScreen.");
          return const WelcomeScreen();
        },
      ),
    );
  }
}
