import 'package:ecommerce_app/controllers/auth_service.dart';
import 'package:ecommerce_app/firebase_options.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:ecommerce_app/providers/user_provider.dart';
import 'package:ecommerce_app/views/cart_page.dart';
import 'package:ecommerce_app/views/checkout_page.dart';
import 'package:ecommerce_app/views/discount_page.dart';
import 'package:ecommerce_app/views/home.dart';
import 'package:ecommerce_app/views/home_nav.dart';
import 'package:ecommerce_app/views/login.dart';
import 'package:ecommerce_app/views/orders_page.dart';
import 'package:ecommerce_app/views/signup.dart';
import 'package:ecommerce_app/views/specific_products.dart';
import 'package:ecommerce_app/views/update_profile.dart';
import 'package:ecommerce_app/views/view_product.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Firebase Initialize
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // 2. Load .env file (try-catch ke andar taaki crash na ho)
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("⚠️ .env file nahi mili. Koi baat nahi, app aage badh raha hai.");
    }

    // 3. Stripe Setup (Safety Check ke sath)
    String stripeKey = dotenv.env["STRIPE_PUBLISH_KEY"] ?? "";

    // Check karega ki key khali toh nahi hai na
    if (stripeKey.isNotEmpty) {
      Stripe.publishableKey = stripeKey;
      Stripe.merchantIdentifier = 'merchant.flutter.stripe.test';
      Stripe.urlScheme = 'flutterstripe';
      await Stripe.instance.applySettings();
    } else {
      debugPrint("⚠️ Stripe Key khali hai ya galat hai. Stripe abhi ke liye disable kar diya gaya hai.");
    }

    // Agar sab theek raha, toh app run hoga
    runApp(const MyApp());

  } catch (e) {
    debugPrint("App Initialization Error: $e");
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "App Start Error:\n\n$e",
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'eCommerce App',
        debugShowCheckedModeBanner: false,
        
        // 🔥 FORCE DARK THEME
        themeMode: ThemeMode.dark, 
        
        // 🌑 DARK THEME CONFIGURATION (iOS & Android friendly)
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, 
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF121212), // Premium Dark look
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121212),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        // ☀️ LIGHT THEME CONFIGURATION (Agar user light mode chahe)
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, 
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),

        routes: {
          "/": (context) => const CheckUser(),
          "/login": (context) => const LoginPage(),
          "/home": (context) => const HomeNav(),
          "/signup": (context) => const SingupPage(),
          "/update_profile": (context) => const UpdateProfile(),
          "/discount": (context) => const DiscountPage(),
          "/specific": (context) => const SpecificProducts(),
          "/view_product": (context) => const ViewProduct(),
          "/cart": (context) => const CartPage(),
          "/checkout": (context) => const CheckoutPage(),
          "/orders": (context) => const OrdersPage(),
          "/view_order": (context) => const ViewOrder(), 
        },
      ),
    );
  }
}

class CheckUser extends StatefulWidget {
  const CheckUser({super.key});

  @override
  State<CheckUser> createState() => _CheckUserState();
}

class _CheckUserState extends State<CheckUser> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    bool isLoggedIn = await AuthService().isLoggedIn();
    if (mounted) { 
      if (isLoggedIn) {
        Navigator.pushReplacementNamed(context, "/home");
      } else {
        Navigator.pushReplacementNamed(context, "/login");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
