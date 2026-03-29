import 'package:flutter/material.dart';
import '../../utils/colours.dart';
import '../common/spinning_loader.dart';
import '../../screens/auth/sign_up_screens/signup_screen_two.dart'; 
import '../../services/institutes_service.dart';
import '../../models/institute_model.dart'; 

class SignupForm extends StatefulWidget {
  final VoidCallback onLoginTap;

  const SignupForm({super.key, required this.onLoginTap});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnicController = TextEditingController(); // NEW
  final _dobController = TextEditingController(); // NEW
  String? _selectedUniversity;
  DateTime? _selectedDate; // NEW
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  final InstitutesService _institutesService = InstitutesService();
  List<Institute> _institutes = [];
  bool _isLoadingInstitutes = false;

  @override
  void initState() {
    super.initState();
    _fetchInstitutes();
  }

  Future<void> _fetchInstitutes() async {
    setState(() => _isLoadingInstitutes = true);
    try {
      final institutes = await _institutesService.fetchInstitutes();
      setState(() {
        _institutes = institutes;
        _isLoadingInstitutes = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInstitutes = false;
          // Fallback to empty or show error
        });
        // existing hardcoded list as fallback could be an option, but user wants api.
        // For now, we'll leave it empty or maybe show a snackbar.
      }
      print("Error fetching institutes: $e");
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
         return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary, // Header background color
              onPrimary: AppColors.textOnPrimary, // Header text color
              onSurface: AppColors.textPrimary, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.toLocal()}".split(' ')[0]; // yyyy-mm-dd
      });
    }
  }

  String _capitalize(String input) {
    if (input.trim().isEmpty) return "";
    final val = input.trim();
    return val[0].toUpperCase() + val.substring(1);
  }

  Future<void> _handleNext() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _phoneController.text.trim().isEmpty || // Phone is now mandatory
        _cnicController.text.trim().isEmpty || // CNIC mandatory
        _dobController.text.isEmpty || // DOB mandatory
        _selectedUniversity == null) {
      setState(() => _errorMessage = "Please Fill Out All The Fields");
      return;
    }

    // CNIC Validation (Example: 13 digits)
    if (_cnicController.text.trim().length != 13) {
       setState(() => _errorMessage = "CNIC must be 13 digits");
       return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = "Passwords Don't Match");
      return;
    }

    // Proceed without Form validation as we are handling it manually
    if (true) {
      setState(() {
        _isLoading = true;
        _errorMessage = null; 
      });
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignupScreenTwo(
            firstName: _capitalize(_firstNameController.text),
            lastName: _capitalize(_lastNameController.text),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            phone: "+92${_phoneController.text.trim()}", // Prepend +92
            university: _selectedUniversity!,
            cnic: _cnicController.text.trim(),
            dateOfBirth: _dobController.text.trim(),
          ),
        ),
      );

      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              const SizedBox(height: 20),

              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onLoginTap, 
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.textSecondary.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text("Create Account",
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),

              _buildTextField(_firstNameController, "First Name",
                  Icons.person_outline, action: TextInputAction.next),
              const SizedBox(height: 12),
              _buildTextField(
                  _lastNameController, "Last Name", Icons.person_outline, action: TextInputAction.next),
              const SizedBox(height: 12),
              _buildTextField(_emailController, "Student Email",
                  Icons.email_outlined, action: TextInputAction.next),
              const SizedBox(height: 12),
              _buildTextField(_passwordController, "Password",
                  Icons.lock_outline,
                  isPassword: true, action: TextInputAction.next),
              const SizedBox(height: 12),
              _buildTextField(_confirmPasswordController,
                  "Confirm Password", Icons.lock_outline,
                  isPassword: true, action: TextInputAction.next),
              const SizedBox(height: 12),
              // Phone (Mandatory)
              _buildTextField(_phoneController, "Phone Number",
                  Icons.phone_outlined,
                  isNumber: true, action: TextInputAction.next, prefixText: "+92 "),
              const SizedBox(height: 12),
               // CNIC (Mandatory)
              _buildTextField(_cnicController, "CNIC (13 digits)",
                  Icons.credit_card,
                  isNumber: true, maxLength: 13, action: TextInputAction.next),
              const SizedBox(height: 12),
              // Date of Birth (Mandatory)
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: _buildTextField(_dobController, "Date of Birth",
                      Icons.calendar_today,
                      isReadOnly: true, action: TextInputAction.done),
                ),
              ),
              const SizedBox(height: 12),
              _buildUniversityDropdown(),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12)),
              ],

              const SizedBox(height: 18),

              // Signup Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const SpinningLoader(size: 30, color: AppColors.secondary)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Next Step",
                                style: TextStyle(
                                    color: AppColors.textOnPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward,
                                color: AppColors.textOnPrimary, size: 20),
                          ],
                        ),
                ),
              ),
              // Bottom padding for the form itself
              const SizedBox(height: 24), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isPassword = false, bool isNumber = false, int? maxLength, bool isReadOnly = false, TextInputAction action = TextInputAction.done, String? prefixText}) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.textSecondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16)),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        textInputAction: action, // Controls keyboard return key
        readOnly: isReadOnly,
        maxLength: maxLength,
        onTap: isReadOnly ? () => _selectDate(context) : null,
        decoration: InputDecoration(
          hintText: hint,
          counterText: "", // Hide character counter
prefixIcon: prefixText == null
              ? Icon(icon, color: AppColors.textSecondary)
              : Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        prefixText,
                        style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.5),
                            fontSize: 16),
                      ),
                    ],
                  ),
                ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: AppColors.textSecondary),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _showUniversityPicker(BuildContext context) {
    if (_institutes.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = _institutes
                .where((inst) =>
                    inst.name.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();
            
            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 24,
                right: 24,
                // Avoid keyboard overlay coverage
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    // Handle Bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      "Select University",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Search universities...",
                        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.textSecondary.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final inst = filtered[index];
                          final isSelected = _selectedUniversity == inst.name;
                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedUniversity = inst.name);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      inst.name,
                                      style: TextStyle(
                                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUniversityDropdown() {
    return GestureDetector(
      onTap: _isLoadingInstitutes ? null : () => _showUniversityPicker(context),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: AppColors.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedUniversity ?? "Select University",
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedUniversity != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
            ),
            if (_isLoadingInstitutes)
              const SizedBox(
                width: 20,
                height: 20,
                child: SpinningLoader(size: 20, color: AppColors.secondary),
              )
            else
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}