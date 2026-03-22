import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>?> createPaymentIntent({
  required String name,
  required String address,
  required String amount,
}) async {
  try {
    final url = Uri.parse('https://api.stripe.com/v1/payment_intents');
    
    // 🔥 SAFE NULL CHECK: Agar env mein key nahi hai toh error na aaye, balki pata chal jaye
    final secretKey = dotenv.env["STRIPE_SECRET_KEY"];
    if (secretKey == null || secretKey.isEmpty) {
      debugPrint("❌ STRIPE_SECRET_KEY is missing in .env file");
      return null;
    }

    // Stripe mein amount paise mein bhejna hota hai (e.g., 100 Rs = 10000 paise)
    final body = {
      'amount': amount, 
      'currency': "inr", // UPI ke liye INR zaroori hai
      // automatic_payment_methods UPI aur Card dono ko automatically handle karega
      'automatic_payment_methods[enabled]': 'true', 
      'description': "Shop Payment",
      'shipping[name]': name,
      'shipping[address][line1]': address,
      'shipping[address][country]': "IN"
    };

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $secretKey",
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: body,
    );

    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      debugPrint("✅ Payment Intent Created Successfully");
      return json;
    } else {
      debugPrint("❌ Error creating payment intent: ${response.body}");
      return null;
    }
  } catch (e) {
    debugPrint("❌ Exception in createPaymentIntent: $e");
    return null;
  }
}
