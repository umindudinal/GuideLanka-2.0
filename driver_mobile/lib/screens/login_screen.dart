import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../widgets/theme_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _obscurePassword = true;
  int _activeTab = 1;
  bool _otpSent = false;

  Future<void> _onLoginSuccess(Map<String, dynamic> result) async {
    debugPrint("👉 Login API Result: $result");

    String? driverIdToSave;
    String driverNameToSave = 'Driver';

    if (result['userId'] != null) {
      driverIdToSave = result['userId'].toString();
    }
    else if (result['id'] != null) {
      driverIdToSave = result['id'].toString();
    }
    else if (result['data'] != null && result['data']['id'] != null) {
      driverIdToSave = result['data']['id'].toString();
    }
    else if (result['data'] != null && result['data']['user'] != null) {
      driverIdToSave = result['data']['user']['id']?.toString();
      if (result['data']['user']['full_name'] != null) {
        driverNameToSave = result['data']['user']['full_name'];
      }
    }
    else if (result['user'] != null) {
      driverIdToSave = result['user']['id']?.toString();
      if (result['user']['full_name'] != null) {
        driverNameToSave = result['user']['full_name'];
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('full_name', driverNameToSave);

    if (driverIdToSave != null) {
      debugPrint("✅ Sending ID to OneSignal: $driverIdToSave");
      OneSignal.login(driverIdToSave);
    }
    else {
      debugPrint("❌ Warning: Could not find Driver ID to send to OneSignal!");
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _handleLogin() async {

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.loginDriver(email, password);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      _onLoginSuccess(result['data']);
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _formatSriLankaPhone(String rawInput) {
    var digits = rawInput.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('94')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (!RegExp(r'^\d{9}$').hasMatch(digits)) {
      return null;
    }
    return '+94$digits';
  }

  Future<void> _handleSendOtp({bool isResend = false}) async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile number first')),
      );
      return;
    }

    final fullPhone = _formatSriLankaPhone(phone);
    if (fullPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 9-digit mobile number (e.g. 771234567 or 0771234567)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    final result = await ApiService.sendOtp(fullPhone);

    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
    });

    if (result['success']) {
      setState(() {
        _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isResend
              ? 'OTP resent successfully! Please check your mobile messages.'
              : 'OTP sent successfully! Please check your mobile messages.'
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    else {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to send OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handlePhoneLogin() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (phone.isEmpty || otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both mobile number and OTP')),
      );
      return;
    }

    final fullPhone = _formatSriLankaPhone(phone);
    if (fullPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 9-digit mobile number (e.g. 771234567)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.verifyOtp(fullPhone, otp);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      _onLoginSuccess(result['data']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    final resetEmail = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPasswordSheet(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (resetEmail != null && resetEmail.isNotEmpty && mounted) {
      setState(() {
        _activeTab = 1;
        _emailController.text = resetEmail;
        _passwordController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password reset successfully! Please sign in with your new password.'),
          backgroundColor: AppColors.online,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.loginGradient,
        ),
        child: SafeArea(

          child: Center(

            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 2.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.explore_outlined,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'GuideLanka',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const Text(
                    'DRIVER PORTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),

                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(28.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        )
                      ],
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [

                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!_isLoading && !_isSendingOtp) {
                                    setState(() => _activeTab = 1);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _activeTab == 1 ? AppColors.primary : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Email',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.normal,
                                      color: _activeTab == 1 ? AppColors.primary : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            Expanded(
                              child: GestureDetector(
                                onTap: () {

                                  if (!_isLoading && !_isSendingOtp) {
                                    setState(() => _activeTab = 0);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _activeTab == 0 ? AppColors.primary : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Phone',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.normal,
                                      color: _activeTab == 0 ? AppColors.primary : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        if (_activeTab == 0) ...[

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              const Text(
                                'Mobile Number',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),

                              const SizedBox(height: 8),

                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,

                                enabled: !_isLoading && !_isSendingOtp && !_otpSent,
                                style: TextStyle(
                                  color: _otpSent ? AppColors.textMuted : AppColors.textDark,
                                  fontWeight: _otpSent ? FontWeight.normal : FontWeight.bold,
                                ),

                                decoration: InputDecoration(

                                  prefixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 16),
                                      Text(
                                        '+94',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _otpSent ? AppColors.textMuted : AppColors.textDark,
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      Container(
                                        height: 24,
                                        width: 1,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                  ),
                                  hintText: '77 123 4567',
                                  hintStyle: TextStyle(color: Colors.grey.shade400),
                                  filled: true,
                                  fillColor: _otpSent ? Colors.grey.shade100 : Colors.grey.shade50,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          if (!_otpSent) ...[
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: AppGradients.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: AppShadows.intenseShadow,
                              ),
                              child: ElevatedButton(
                                onPressed: _isSendingOtp ? null : () => _handleSendOtp(isResend: false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isSendingOtp
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Send OTP',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward, color: Colors.white),
                                        ],
                                      ),
                              ),
                            ),
                          ]

                          else ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'One Time Password',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: AppColors.textDark),
                                  decoration: InputDecoration(
                                    hintText: 'Enter 6-digit code',
                                    hintStyle: TextStyle(color: Colors.grey.shade400),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _otpSent = false;
                                      _otpController.clear();
                                    });
                                  },
                                  child: const Text(
                                    'Change Number',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isSendingOtp ? null : () => _handleSendOtp(isResend: true),
                                  child: _isSendingOtp
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text(
                                          'Resend Code',
                                          style: TextStyle(
                                            color: AppColors.primaryLight,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: AppGradients.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: AppShadows.intenseShadow,
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handlePhoneLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward, color: Colors.white),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ]

                        else ...[

                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppColors.textDark),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: const TextStyle(color: AppColors.textMuted),
                              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppColors.textDark),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: AppColors.textMuted),
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () {

                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),

                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppGradients.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppShadows.intenseShadow,
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, color: Colors.white),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordSheet({required this.initialEmail});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _emailCtrl;
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _newPwdCtrl = TextEditingController();
  final TextEditingController _confirmPwdCtrl = TextEditingController();

  bool _codeSent = false;
  bool _isBusy = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _resetToken;
  String? _errorMsg;
  String? _infoMsg;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String pwd) {
    return pwd.length >= 8 &&
        pwd.contains(RegExp(r'[A-Z]')) &&
        pwd.contains(RegExp(r'[a-z]')) &&
        pwd.contains(RegExp(r'[0-9]')) &&
        pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]'));
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMsg = 'Please enter a valid registered email address.';
        _infoMsg = null;
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMsg = null;
      _infoMsg = null;
    });

    final res = await ApiService.requestPasswordReset(email);
    if (!mounted) return;

    setState(() {
      _isBusy = false;
      if (res['success'] == true) {
        _codeSent = true;
        _resetToken = res['reset_token']?.toString();
        _infoMsg = res['message']?.toString() ?? 'Verification code sent to $email.';
      } else {
        _errorMsg = res['error']?.toString() ?? 'Could not send reset code.';
      }
    });
  }

  Future<void> _submitReset() async {
    final email = _emailCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final newPwd = _newPwdCtrl.text;
    final confirmPwd = _confirmPwdCtrl.text;

    if (otp.length < 6) {
      setState(() => _errorMsg = 'Please enter the 6-digit code sent to your email.');
      return;
    }
    if (!_isStrongPassword(newPwd)) {
      setState(() => _errorMsg = 'Password must be at least 8 characters with uppercase, lowercase, numbers, and symbols (!@#).');
      return;
    }
    if (newPwd != confirmPwd) {
      setState(() => _errorMsg = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMsg = null;
    });

    final res = await ApiService.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPwd,
      resetToken: _resetToken,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      Navigator.of(context).pop(email);
    } else {
      setState(() {
        _isBusy = false;
        _errorMsg = res['error']?.toString() ?? 'Failed to reset password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 26),
                      SizedBox(width: 8),
                      Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _codeSent
                    ? 'Enter the 6-digit code sent to ${_emailCtrl.text.trim()} and choose a strong new password.'
                    : 'Enter your registered driver email address to receive a 6-digit password reset code.',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              if (_errorMsg != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              if (_infoMsg != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    _infoMsg!,
                    style: TextStyle(color: Colors.green.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              TextField(
                controller: _emailCtrl,
                enabled: !_codeSent && !_isBusy,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Registered Email Address',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                  filled: true,
                  fillColor: _codeSent ? Colors.grey.shade100 : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _otpCtrl,
                  enabled: !_isBusy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '6-Digit Verification Code',
                    counterText: '',
                    prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.primary),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _newPwdCtrl,
                  enabled: !_isBusy,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Min 8 chars (Aa, 0-9, !@#)',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirmPwdCtrl,
                  enabled: !_isBusy,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () => setState(() {
                                _codeSent = false;
                                _otpCtrl.clear();
                                _errorMsg = null;
                                _infoMsg = null;
                              }),
                      child: const Text('Change Email', style: TextStyle(color: AppColors.textMuted)),
                    ),
                    TextButton(
                      onPressed: _isBusy ? null : _sendCode,
                      child: const Text(
                        'Resend Code',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isBusy ? null : (_codeSent ? _submitReset : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _codeSent ? 'Reset Password' : 'Send Reset Code',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
