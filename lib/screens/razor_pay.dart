import 'package:trippo_maps/global/global.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../utils/logger.dart';
import '../utils/app_colors.dart';

class RazorPay extends StatefulWidget {
  const RazorPay({super.key});
  @override
  State<RazorPay> createState() => _RazorPayState();
}

class _RazorPayState extends State<RazorPay> {
  late Razorpay _razorpay;
  DatabaseReference userRef = FirebaseDatabase.instance.ref().child("users");
  TextEditingController amtController = TextEditingController();

  void openCheckout(amount) async {
    amount = amount * 100;
    var options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag',
      'amount': amount,
      'name': 'Divyam',
      'prefill': {
        'contact': '8888888888',
        'email': 'william.johnson@example-pet-store.com',
      },
      'external': {
        'wallets': ['paytm'],
      },
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      AppLogger.error('Payment error', e);
    }
  }

  void handlePaymentSuccess(PaymentSuccessResponse response) {
    int addedAmount = int.parse(amtController.text.toString());
    var currentWalletBalance =
        int.tryParse(userModelCurrentInfo!.wallet_amount!)!;
    currentWalletBalance += addedAmount;
    var walletAmount = currentWalletBalance.toString();

    // Update Firebase
    userRef
        .child(firebaseAuth.currentUser!.uid)
        .update({"wallet_amount": walletAmount})
        .then((value) {
          // Update local data
          userModelCurrentInfo!.wallet_amount = walletAmount;

          amtController.clear();
          Fluttertoast.showToast(msg: "Wallet Updated Successfully");

          // Navigate back to wallet screen
          Navigator.pop(context);
        })
        .catchError((errorMessage) {
          Fluttertoast.showToast(msg: "Error Occurred. \n $errorMessage");
        });
  }

  void handlePaymentError(PaymentFailureResponse response) {
    Fluttertoast.showToast(
      msg: "Payment Failed" + response.message!,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void handleExternalWallet(ExternalWalletResponse response) {
    Fluttertoast.showToast(
      msg: "External Wallet" + response.walletName!,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _razorpay.clear();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWallet);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Recharge Wallet",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(height: 30),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 60,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Enter Amount to Recharge",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      cursorColor: AppColors.primaryColor,
                      autofocus: false,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.grey[800], fontSize: 16),
                      decoration: InputDecoration(
                        labelText: "Amount (₹)",
                        labelStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        prefixIcon: Icon(
                          Icons.currency_rupee,
                          color: Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primaryColor),
                        ),
                        errorStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.redAccent,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      controller: amtController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter an amount";
                        }
                        if (int.tryParse(value) == null) {
                          return "Please enter a valid amount";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (amtController.text.toString().isNotEmpty) {
                            setState(() {
                              int amount = int.parse(
                                amtController.text.toString(),
                              );
                              openCheckout(amount);
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          "Proceed to Payment",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
