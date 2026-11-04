import 'dart:io';

import 'package:century_ai/core/constants/colors.dart';
import 'package:century_ai/data/services/profile_cloud_sync.dart';
import 'package:century_ai/db/models/user_profile_data.dart';
import 'package:century_ai/db/repositories/local_user_profile_repository.dart';
import 'package:century_ai/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:century_ai/router/app_routes.dart';
import 'package:century_ai/utils/popups/loaders.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

/// The user's profile, saved in the local SQLite database (the name is also
/// set as the Firebase display name).
///
/// - Setup ([viewMode] false): shown after sign-in to users without a complete
///   profile (first name, last name and email); starts editable, Submit goes
///   home.
/// - Profile ([viewMode] true): opened from the drawer; shows the details
///   read-only with an Edit button, and Update saves and returns to viewing.
class ProfileSetupPage extends StatefulWidget {
  final bool viewMode;

  const ProfileSetupPage({super.key, this.viewMode = false});

  static const motherTongues = ['Bangla', 'English', 'Hindi'];
  static const occupations = ['Contractor', 'Woodmaker'];

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  late final _phone = TextEditingController(
    text: FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
  );
  final _address = TextEditingController();

  String? _motherTongue;
  String? _occupation;

  /// Photo already saved for this user (file name in app documents).
  String? _savedPhotoFileName;
  File? _savedPhoto;

  /// Photo picked on this screen, not saved yet.
  File? _pickedPhoto;

  bool _saving = false;

  /// Fields are editable; always true during first-time setup.
  late bool _editing = !widget.viewMode;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _user;
    if (user == null) return;
    final profile = await LocalUserProfileRepository.getProfile(user.uid);
    final photo = await LocalUserProfileRepository.photoFile(
      profile?.photoFileName,
    );
    if (!mounted) return;

    setState(() {
      if (profile != null) {
        _firstName.text = profile.firstName;
        _lastName.text = profile.lastName;
        _email.text = profile.email;
        _address.text = profile.address ?? '';
        _motherTongue = _validOption(
          profile.motherTongue,
          ProfileSetupPage.motherTongues,
        );
        _occupation = _validOption(
          profile.occupation,
          ProfileSetupPage.occupations,
        );
        _savedPhotoFileName = profile.photoFileName;
        _savedPhoto = photo;
      } else {
        // First visit: start from what Firebase already knows, if anything.
        final parts = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
        if (parts.first.isNotEmpty) {
          _firstName.text = parts.first;
          _lastName.text = parts.skip(1).join(' ');
        }
        _email.text = user.email ?? '';
      }
    });
  }

  String? _validOption(String? value, List<String> options) =>
      options.contains(value) ? value : null;

  Future<void> _pickPhoto() async {
    if (!_editing) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TColors.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Iconsax.camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _pickedPhoto = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      TLoaders.errorSnackBar(
        context: context,
        title: 'Could not open photo',
        message: 'Please allow camera and photo access in Settings.',
      );
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final user = _user;
    if (user == null || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      var photoFileName = _savedPhotoFileName;
      if (_pickedPhoto != null) {
        photoFileName = await LocalUserProfileRepository.storePhoto(
          user.uid,
          _pickedPhoto!,
        );
        await LocalUserProfileRepository.deletePhoto(_savedPhotoFileName);
      }

      final first = _firstName.text.trim();
      final last = _lastName.text.trim();
      final profile = UserProfileData(
        uid: user.uid,
        phoneNumber: user.phoneNumber,
        firstName: first,
        lastName: last,
        email: _email.text.trim(),
        address: _address.text.trim(),
        motherTongue: _motherTongue,
        occupation: _occupation,
        photoFileName: photoFileName,
        updatedAt: DateTime.now(),
      );
      await LocalUserProfileRepository.saveProfile(profile);

      // Name, email and photo also go on the Firebase account, so a new
      // phone or reinstall can restore them. Capped so Submit never hangs.
      await ProfileCloudSync.push(
        profile,
        newPhoto: _pickedPhoto != null
            ? LocalUserProfileRepository.photoFileSync(photoFileName)
            : null,
      ).timeout(const Duration(seconds: 20), onTimeout: () {});

      if (!mounted) return;
      if (widget.viewMode) {
        // Back to the read-only profile, now showing the saved details.
        setState(() {
          _saving = false;
          _editing = false;
          _savedPhotoFileName = photoFileName;
          _savedPhoto = _pickedPhoto != null
              ? LocalUserProfileRepository.photoFileSync(photoFileName)
              : _savedPhoto;
          _pickedPhoto = null;
        });
        TLoaders.customToast(context: context, message: 'Profile updated');
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      TLoaders.errorSnackBar(
        context: context,
        title: 'Could not save profile',
        message: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    final photo = _pickedPhoto ?? _savedPhoto;

    return Scaffold(
      backgroundColor: TColors.pureWhite,
      appBar: AppBar(
        backgroundColor: TColors.pureWhite,
        surfaceTintColor: TColors.pureWhite,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: canPop ? 0 : 24,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: TColors.pureBlack),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: TColors.pureBlack,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Image.asset(AuthAssets.starLogo, width: 30),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _ProfilePhoto(photo: photo, onTap: _pickPhoto),
                  ),
                  const SizedBox(height: 14),
                  if (_editing)
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                    )
                  else
                    _NameHeader(
                      name: '${_firstName.text} ${_lastName.text}'.trim(),
                      phone: _user?.phoneNumber,
                    ),
                  const SizedBox(height: 14),
                  _UnderlinedField(
                    label: 'First Name*',
                    controller: _firstName,
                    readOnly: !_editing,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.givenName],
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Please enter your first name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _UnderlinedField(
                    label: 'Last Name*',
                    controller: _lastName,
                    readOnly: !_editing,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.familyName],
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Please enter your last name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _UnderlinedField(
                    label: 'E-mail*',
                    controller: _email,
                    readOnly: !_editing,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Please enter your email';
                      final ok = RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value);
                      return ok ? null : 'Please enter a valid email';
                    },
                  ),
                  const SizedBox(height: 14),
                  _UnderlinedField(
                    label: 'Mobile Number',
                    controller: _phone,
                    readOnly: true,
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 14),
                  _UnderlinedField(
                    label: 'Address',
                    controller: _address,
                    readOnly: !_editing,
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.streetAddress,
                    autofillHints: const [AutofillHints.fullStreetAddress],
                    textInputAction: TextInputAction.done,
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Take Personalization to the next level by adding more '
                    'details to your profile',
                    style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                  ),
                  const SizedBox(height: 16),
                  _OptionDropdown(
                    hint: 'Select Your Mother Tongue',
                    value: _motherTongue,
                    options: ProfileSetupPage.motherTongues,
                    enabled: _editing,
                    onChanged: (v) => setState(() => _motherTongue = v),
                  ),
                  const SizedBox(height: 10),
                  _OptionDropdown(
                    hint: 'Select Your Occupation',
                    value: _occupation,
                    options: ProfileSetupPage.occupations,
                    enabled: _editing,
                    onChanged: (v) => setState(() => _occupation = v),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: _editing
                        ? AuthPrimaryButton(
                            label: widget.viewMode ? 'Update' : 'Submit',
                            loading: _saving,
                            onPressed: _submit,
                          )
                        : AuthPrimaryButton(
                            label: 'Edit',
                            onPressed: () => setState(() => _editing = true),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  final File? photo;
  final VoidCallback onTap;

  const _ProfilePhoto({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: const Color(0xFFEDEDED), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: photo != null
            ? Image.file(photo!, fit: BoxFit.cover)
            : const Icon(Iconsax.user, size: 56, color: Color(0xFF9E9E9E)),
      ),
    );
  }
}

class _UnderlinedField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final bool readOnly;

  const _UnderlinedField({
    required this.label,
    required this.controller,
    required this.validator,
    this.readOnly = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
  });

  static const _line = UnderlineInputBorder(
    borderSide: BorderSide(color: Color(0xFF555555)),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF555555),
          ),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          readOnly: readOnly,
          enableInteractiveSelection: !readOnly,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: TColors.pureBlack,
          ),
          decoration: const InputDecoration(
            isDense: true,
            filled: false,
            contentPadding: EdgeInsets.fromLTRB(0, 6, 0, 6),
            border: _line,
            enabledBorder: _line,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: TColors.pureBlack, width: 1.5),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: TColors.vividRed),
            ),
            focusedErrorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: TColors.vividRed, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _OptionDropdown({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  static final _box = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
  );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: DropdownButtonFormField<String>(
        // initialValue is only read once; the key rebuilds it when the saved
        // profile loads or the value changes.
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        isDense: true,
        icon: enabled
            ? const Icon(Icons.keyboard_arrow_down_rounded, size: 22)
            : const SizedBox.shrink(),
        dropdownColor: TColors.pureWhite,
        borderRadius: BorderRadius.circular(10),
        hint: Text(
          hint,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: TColors.pureBlack,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFCFCFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          border: _box,
          enabledBorder: _box,
          focusedBorder: _box,
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// Name and mobile number under the photo on the read-only profile.
class _NameHeader extends StatelessWidget {
  final String name;
  final String? phone;

  const _NameHeader({required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          name.isEmpty ? 'Your Name' : name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: TColors.pureBlack,
          ),
        ),
        if (phone != null && phone!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            phone!,
            style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
          ),
        ],
      ],
    );
  }
}
