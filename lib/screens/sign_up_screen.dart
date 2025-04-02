// ignore_for_file: use_build_context_synchronously

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../global/global.dart';
import '../utils/app_colors.dart';
import '../services/auth_service.dart';
import '../utils/message_utils.dart';
import 'main_screen.dart';
import 'sign_in_screen.dart';
import 'dart:async';
import '../utils/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _mobileOtpController = TextEditingController();
  final _emailOtpController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _showMobileOtpStep = false;
  bool _isMobileVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifying = false;
  String? _verificationId;
  bool _isResendingOtp = false;
  String? _phoneNumber;
  Timer? _mobileResendTimer;
  int _mobileResendCountdown = 0;
  bool _otpSent = false;
  Timer? _emailResendTimer;
  int _emailResendCountdown = 0;
  bool _isResendingEmailOtp = false;
  bool _isVerifyingEmail = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mobileOtpController.dispose();
    _emailOtpController.dispose();
    _mobileResendTimer?.cancel();
    _emailResendTimer?.cancel();
    super.dispose();
  }

  void _startMobileResendTimer() {
    _mobileResendCountdown = 30;
    _mobileResendTimer?.cancel();
    _mobileResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_mobileResendCountdown > 0) {
          _mobileResendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _startEmailResendTimer() {
    _emailResendCountdown = 30;
    _emailResendTimer?.cancel();
    _emailResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_emailResendCountdown > 0) {
          _emailResendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendMobileOtp() async {
    if (_mobileController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your mobile number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String mobileNumber = _mobileController.text.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobileNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid 10-digit mobile number starting with 6-9',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isSendingOtp) return;

    setState(() {
      _isSendingOtp = true;
      _phoneNumber = mobileNumber;
      _isMobileVerified = false;
      _mobileOtpController.clear();
    });

    final scaffoldContext = ScaffoldMessenger.of(context);

    try {
      final phoneNumber = '+91$mobileNumber';
      final result = await _authService.verifyPhoneNumber(phoneNumber);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _verificationId = result['verificationId'];
          _otpSent = true;
          _showMobileOtpStep = true;
        });
        _startMobileResendTimer();

        Timer(const Duration(minutes: 5), () {
          if (mounted && !_isMobileVerified) {
            setState(() {
              _otpSent = false;
              _showMobileOtpStep = false;
            });
            scaffoldContext.showSnackBar(
              const SnackBar(
                content: Text(
                  'Mobile OTP has expired. Please request a new one.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      } else {
        scaffoldContext.showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to send OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldContext.showSnackBar(
        SnackBar(
          content: Text('Error sending OTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  Future<void> _verifyMobileOtp() async {
    if (!_showMobileOtpStep ||
        _isVerifying ||
        _mobileOtpController.text.length != 6) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    final scaffoldContext = ScaffoldMessenger.of(context);

    try {
      // Simple verification call without complex data handling
      final result = await _authService.verifyOTP(
        _verificationId!,
        _mobileOtpController.text,
      );

      if (!mounted) return;

      // Simplified response handling with proper type safety
      if (result['success'] == true) {
        setState(() {
          _isMobileVerified = true;
          _mobileResendTimer?.cancel();
        });

        scaffoldContext.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Mobile number verified successfully'),
          ),
        );
      } else {
        // Safe access to error message
        final errorMessage =
            result['message'] as String? ?? 'Failed to verify OTP';

        scaffoldContext.showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        AppLogger.error('Error in _verifyMobileOtp', e);

        scaffoldContext.showSnackBar(
          SnackBar(
            content: Text('Verification error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendMobileOtp() async {
    if (_mobileResendCountdown > 0 || _isResendingOtp || _isSendingOtp) return;

    setState(() {
      _isResendingOtp = true;
      _mobileOtpController.clear();
    });

    final scaffoldContext = ScaffoldMessenger.of(context);

    try {
      final phoneNumber = '+91$_phoneNumber';
      final result = await _authService.verifyPhoneNumber(phoneNumber);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _verificationId = result['verificationId'];
          _isResendingOtp = false;
        });
        _startMobileResendTimer();
        scaffoldContext.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Mobile OTP resent successfully'),
          ),
        );
      } else {
        setState(() {
          _isResendingOtp = false;
        });
        scaffoldContext.showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResendingOtp = false;
      });
      scaffoldContext.showSnackBar(
        SnackBar(
          content: Text('Error resending OTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendEmailVerification() async {
    if (_emailResendCountdown > 0 || _isResendingEmailOtp) return;

    setState(() {
      _isResendingEmailOtp = true;
    });

    final scaffoldContext = ScaffoldMessenger.of(context);

    try {
      final result = await _authService.resendVerification(
        _emailController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        _startEmailResendTimer();
        scaffoldContext.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Email verification OTP resent successfully'),
          ),
        );
      } else {
        scaffoldContext.showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to resend verification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldContext.showSnackBar(
        SnackBar(
          content: Text('Error resending verification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResendingEmailOtp = false;
        });
      }
    }
  }

  void _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      final scaffoldContext = ScaffoldMessenger.of(context);

      if (!_isMobileVerified) {
        scaffoldContext.showSnackBar(
          const SnackBar(
            content: Text('Please verify your mobile number first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        scaffoldContext.showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final navigator = Navigator.of(context);

      try {
        AppLogger.info('Creating user account with Firebase');
        if (!mounted) return;
        await firebaseAuth
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            )
            .then((auth) async {
              currentUser = auth.user;
              if (currentUser != null) {
                Map userMap = {
                  "id": currentUser!.uid,
                  "name": _nameController.text.trim(),
                  "email": _emailController.text.trim(),
                  "phone": _mobileController.text.trim(),
                  "wallet_amount": "0",
                };

                DatabaseReference userRef = FirebaseDatabase.instance
                    .ref()
                    .child("users");
                userRef.child(currentUser!.uid).set(userMap);
              }
              scaffoldContext.showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.green,
                  content: Text('Account created successfully'),
                ),
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => SignInScreen()),
              );
            })
            .catchError((errorMessage) {
              scaffoldContext.showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green,
                  content: Text('Error occurred: $errorMessage'),
                ),
              );
            });
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'Email is already in use.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address.';
            break;
          case 'weak-password':
            errorMessage = 'Password is too weak.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Email/password accounts are not enabled.';
            break;
          default:
            errorMessage =
                e.message ?? 'An error occurred during registration.';
        }

        AppLogger.error('FirebaseAuthException during signup', e);
        scaffoldContext.showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      } catch (e) {
        AppLogger.error('Error during signup', e);
        scaffoldContext.showSnackBar(
          SnackBar(
            content: Text('Error creating account: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Make the background transparent
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Center(
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontFamily: 'AlbertSans',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(
                            fontFamily: 'AlbertSans',
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Full Name*',
                            labelStyle: const TextStyle(
                              fontFamily: 'AlbertSans',
                              color: Color.fromARGB(255, 105, 101, 101),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _mobileController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  fontFamily: 'AlbertSans',
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Mobile Number*',
                                  labelStyle: const TextStyle(
                                    fontFamily: 'AlbertSans',
                                    color: Color.fromARGB(255, 105, 101, 101),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.never,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[400]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[400]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your mobile number';
                                  }
                                  if (!RegExp(
                                    r'^[6-9]\d{9}$',
                                  ).hasMatch(value)) {
                                    return 'Enter valid number starting with 6-9';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              reverseDuration: const Duration(
                                milliseconds: 200,
                              ),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (
                                Widget child,
                                Animation<double> animation,
                              ) {
                                return FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOut,
                                  ),
                                  child: ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child:
                                  !_otpSent
                                      ? ElevatedButton(
                                        key: const ValueKey('send_otp'),
                                        onPressed:
                                            _isSendingOtp
                                                ? null
                                                : _sendMobileOtp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryColor,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                        ),
                                        child: Text(
                                          _isSendingOtp
                                              ? 'Sending...'
                                              : 'Send OTP',
                                        ),
                                      )
                                      : Container(
                                        key: const ValueKey('otp_sent'),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withAlpha(25),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Colors.green,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'OTP Sent',
                                              style: TextStyle(
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                            ),
                          ],
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 400),
                          reverseDuration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child:
                              _showMobileOtpStep
                                  ? Column(
                                    children: [
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _mobileOtpController,
                                              keyboardType:
                                                  TextInputType.number,
                                              maxLength: 6,
                                              enabled:
                                                  _otpSent &&
                                                  !_isMobileVerified &&
                                                  !_isVerifying,
                                              style: const TextStyle(
                                                fontFamily: 'AlbertSans',
                                                fontSize: 15,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Enter OTP',
                                                labelStyle: const TextStyle(
                                                  fontFamily: 'AlbertSans',
                                                  color: Color.fromARGB(
                                                    255,
                                                    105,
                                                    101,
                                                    101,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                                counterText: '',
                                                floatingLabelBehavior:
                                                    FloatingLabelBehavior.never,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                    color: Colors.grey[400]!,
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color:
                                                            Colors.grey[400]!,
                                                      ),
                                                    ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: const BorderSide(
                                                    color:
                                                        AppColors.primaryColor,
                                                  ),
                                                ),
                                                suffixIcon:
                                                    _isMobileVerified
                                                        ? const Icon(
                                                          Icons.check_circle,
                                                          color: Colors.green,
                                                        )
                                                        : null,
                                              ),
                                              validator: (value) {
                                                if (_showMobileOtpStep &&
                                                    !_isMobileVerified) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Please enter the OTP';
                                                  }
                                                  if (value.length != 6) {
                                                    return 'Please enter a valid 6-digit OTP';
                                                  }
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!_isMobileVerified)
                                            ElevatedButton(
                                              onPressed:
                                                  (_otpSent &&
                                                          !_isVerifying &&
                                                          _mobileOtpController
                                                                  .text
                                                                  .length ==
                                                              6)
                                                      ? _verifyMobileOtp
                                                      : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primaryColor,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 16,
                                                    ),
                                              ),
                                              child: Text(
                                                _isVerifying
                                                    ? 'Verifying...'
                                                    : 'Verify OTP',
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (!_isMobileVerified &&
                                          _mobileResendCountdown > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            'Resend OTP in $_mobileResendCountdown seconds',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontFamily: 'AlbertSans',
                                            ),
                                          ),
                                        ),
                                      if (!_isMobileVerified &&
                                          _mobileResendCountdown == 0)
                                        TextButton(
                                          onPressed:
                                              _isResendingOtp
                                                  ? null
                                                  : _resendMobileOtp,
                                          child: Text(
                                            _isResendingOtp
                                                ? 'Resending...'
                                                : 'Resend OTP',
                                            style: const TextStyle(
                                              fontFamily: 'AlbertSans',
                                            ),
                                          ),
                                        ),
                                    ],
                                  )
                                  : Container(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            fontFamily: 'AlbertSans',
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Email Id*',
                            labelStyle: const TextStyle(
                              fontFamily: 'AlbertSans',
                              color: Color.fromARGB(255, 105, 101, 101),
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          style: const TextStyle(
                            fontFamily: 'AlbertSans',
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Password*',
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontFamily: 'AlbertSans',
                              color: Color.fromARGB(255, 105, 101, 101),
                              fontSize: 15,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primaryColor,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_showConfirmPassword,
                          style: const TextStyle(
                            fontFamily: 'AlbertSans',
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password*',
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontFamily: 'AlbertSans',
                              color: Color.fromARGB(255, 105, 101, 101),
                              fontSize: 15,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primaryColor,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _showConfirmPassword = !_showConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontFamily: 'AlbertSans',
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: Color.fromARGB(255, 59, 59, 57),
                        fontSize: 15,
                        fontFamily: 'AlbertSans',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const SignInScreen(),
                            transitionsBuilder: (
                              context,
                              animation,
                              secondaryAnimation,
                              child,
                            ) {
                              const begin = Offset(-1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOutCubic;
                              var tween = Tween(
                                begin: begin,
                                end: end,
                              ).chain(CurveTween(curve: curve));
                              var offsetAnimation = animation.drive(tween);
                              return SlideTransition(
                                position: offsetAnimation,
                                child: FadeTransition(
                                  opacity: animation.drive(
                                    CurveTween(curve: Curves.easeInOut),
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            transitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                            reverseTransitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryColor,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Color.fromARGB(255, 59, 59, 57),
                          fontSize: 15,
                          fontFamily: 'AlbertSans',
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
