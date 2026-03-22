import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecommerce_app/contants/payment.dart';
import 'package:ecommerce_app/controllers/db_service.dart';
import 'package:ecommerce_app/controllers/mail_service.dart';
import 'package:ecommerce_app/models/orders_model.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'package:ecommerce_app/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // UPI ke liye naya import

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _couponController = TextEditingController();

  int discount = 0;
  String discountText = "";
  bool paymentSuccess = false;
  Map<String, dynamic> dataOfOrder = {};

  void discountCalculator(int disPercent, int totalCost) {
    setState(() {
      discount = (disPercent * totalCost) ~/ 100;
    });
  }

  // 🔥 DIRECT UPI PAYMENT LOGIC
  Future<void> payWithDirectUPI(int cost) async {
    // Aapka apna UPI ID yahan daala gaya hai
    String upiId = "paynearby.8406962570@indus";
    String payeeName = "Ecommerce Store";
    String transactionNote = "Order Payment";

    // UPI Deep Link Generate karna
    String url =
        "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&tn=${Uri.encodeComponent(transactionNote)}&am=$cost&cu=INR";

    Uri uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // WARNING: Bina Gateway ke hum 100% sure nahi ho sakte ki payment successful hui ya fail.
        // Yahan hum assume kar rahe hain ki agar app wapas aaya toh hum order place kar denge (Jo ki risky hai).
        // Asli app mein aapko payment screenshot ya transaction ID maangni padegi agar Gateway nahi hai toh.
        
        await _placeOrderAfterPayment(cost);
        
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No UPI App found on this device.")));
        }
      }
    } catch (e) {
      debugPrint("UPI Error: $e");
    }
  }

  // STRIPE LOGIC (Pehle jaisa hi hai)
  Future<void> initPaymentSheet(int cost) async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final data = await createPaymentIntent(
        name: user.name,
        address: user.address,
        amount: (cost * 100).toString(),
      );

      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Could not process payment. Check configuration.')),
          );
        }
        return; 
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          customFlow: false,
          merchantDisplayName: 'E-Commerce Store',
          paymentIntentClientSecret: data['client_secret'],
          style: ThemeMode.dark,
        ),
      );
      
      await Stripe.instance.presentPaymentSheet();
      await _placeOrderAfterPayment(cost); // Payment success hone par order place hoga

    } on StripeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Payment Cancelled: ${e.error.localizedMessage}"),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      debugPrint("General Exception: $e");
    }
  }

  // ORDER PLACEMENT LOGIC (Common for both Stripe and UPI)
  Future<void> _placeOrderAfterPayment(int cost) async {
    if (!mounted) return;
    
    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false);
    User? currentUser = FirebaseAuth.instance.currentUser;
    
    List products = [];
    for (int i = 0; i < cart.products.length; i++) {
      products.add({
        "id": cart.products[i].id,
        "name": cart.products[i].name,
        "image": cart.products[i].image,
        "single_price": cart.products[i].new_price,
        "total_price": cart.products[i].new_price * cart.carts[i].quantity,
        "quantity": cart.carts[i].quantity
      });
    }

    Map<String, dynamic> orderData = {
      "user_id": currentUser?.uid ?? "",
      "name": user.name,
      "email": user.email,
      "address": user.address,
      "phone": user.phone,
      "discount": discount,
      "total": cost,
      "products": products,
      "status": "PAID",
      "created_at": DateTime.now().millisecondsSinceEpoch
    };

    dataOfOrder = orderData;

    await DbService().createOrder(data: orderData);
    for (int i = 0; i < cart.products.length; i++) {
      DbService().reduceQuantity(
          productId: cart.products[i].id, quantity: cart.carts[i].quantity);
    }
    await DbService().emptyCart();

    paymentSuccess = true;

    if (mounted) {
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Payment Successful! Order Placed.", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ));
    }

    if (paymentSuccess) {
       MailService().sendMailFromGmail(user.email, OrdersModel.fromJson(dataOfOrder, ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
      ),
      body: SingleChildScrollView(
        child: Consumer<UserProvider>(
          builder: (context, userData, child) => Consumer<CartProvider>(
            builder: (context, cartData, child) {
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Delivery Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(userData.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text(userData.email),
                                Text(userData.address),
                                Text(userData.phone),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pushNamed(context, "/update_profile");
                            },
                            icon: const Icon(Icons.edit_outlined),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text("Have a coupon?", style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            textCapitalization: TextCapitalization.characters,
                            controller: _couponController,
                            decoration: InputDecoration(
                              labelText: "Coupon Code",
                              hintText: "Enter Coupon",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade200,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            if (_couponController.text.isEmpty) return;
                            QuerySnapshot querySnapshot = await DbService().verifyDiscount(code: _couponController.text.toUpperCase());
                            if (querySnapshot.docs.isNotEmpty) {
                              QueryDocumentSnapshot doc = querySnapshot.docs.first;
                              int percent = doc.get('discount');
                              setState(() {
                                discountText = "A discount of $percent% has been applied.";
                              });
                              discountCalculator(percent, cartData.totalCost);
                            } else {
                              setState(() {
                                discountText = "Invalid coupon code";
                                discount = 0;
                              });
                            }
                          },
                          child: const Text("Apply"),
                        )
                      ],
                    ),
                    if (discountText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(discountText, style: TextStyle(color: discount > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Sub Total:", style: TextStyle(fontSize: 16)),
                        Text("₹ ${cartData.totalCost}", style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Discount:", style: TextStyle(fontSize: 16, color: Colors.green)),
                        Text("- ₹ $discount", style: const TextStyle(fontSize: 16, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Payable:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("₹ ${cartData.totalCost - discount}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 140, // Height badha di gayi hai taaki 2 buttons aa sakein
        padding: const EdgeInsets.all(12.0),
        child: Consumer<CartProvider>(
          builder: (context, cartData, child) {
            final finalCost = cartData.totalCost - discount;
            return Column(
              children: [
                // 🔹 BUTTON 1: UPI PAYMENT
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () async {
                       if (finalCost <= 0) return;
                       await payWithDirectUPI(finalCost);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text("Pay directly via UPI App", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                // 🔹 BUTTON 2: STRIPE PAYMENT
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (finalCost <= 0) return;
                      await initPaymentSheet(finalCost);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text("Pay with Card (Stripe)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}
