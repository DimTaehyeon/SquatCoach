import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/primary_button.dart';

/// 프로필 수정 화면 (Figma: 프로필).
/// - [firstRun] = true : 앱을 처음 켰을 때 로딩 화면 다음에 나오는 프로필 입력 (저장 → 목표 선택으로)
/// - [firstRun] = false: 마이페이지에서 들어오는 프로필 수정 (저장 → 뒤로)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  FitnessGoal _goal = FitnessGoal.postureCorrection;
  Gender? _gender;
  Uint8List? _photo;
  bool _photoChanged = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<ProfileProvider>().user;
    _name = TextEditingController(text: u.name)..addListener(() => setState(() {}));
    _gender = u.gender;
    // 처음 가입(firstRun)일 때는 값을 비워두고 예시(힌트)만 보여줍니다.
    _height = TextEditingController(text: widget.firstRun ? '' : '${u.heightCm}');
    _weight = TextEditingController(text: widget.firstRun ? '' : '${u.weightKg}');
    _goal = u.goal ?? FitnessGoal.postureCorrection;
    _photo = u.photoBytes;
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = context.read<ProfileProvider>();
    await profile.updateProfile(
      name: _name.text.trim(),
      gender: _gender,
      heightCm: int.tryParse(_height.text.trim()),
      weightKg: int.tryParse(_weight.text.trim()),
    );
    await profile.setGoal(_goal);
    if (_photoChanged) await profile.setPhoto(_photo);
    if (!mounted) return;
    if (widget.firstRun) {
      Navigator.of(context).pushReplacementNamed('/goal');
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 갤러리에서 사진을 골라 프로필 사진으로 설정합니다.
  Future<void> _pickFromGallery() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
      if (file == null) return; // 사용자가 취소
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _photoChanged = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했어요. 권한을 확인해 주세요.')));
    }
  }

  void _showPhotoMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('갤러리에서 사진 선택'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFromGallery();
              },
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('기본 이미지로 변경', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _photo = null;
                    _photoChanged = true;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.trim().isEmpty ? '?' : _name.text.trim().substring(0, 1);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ScreenHeader(
                title: '프로필 수정',
                onBack: widget.firstRun ? null : () => Navigator.of(context).pop(),
                trailing: TextButton(
                  onPressed: _save,
                  child: const Text('저장', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _showPhotoMenu,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: _photo != null
                                      ? Image.memory(_photo!, width: 76, height: 76, fit: BoxFit.cover, gaplessPlayback: true)
                                      : Text(initial,
                                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                                ),
                                Positioned(
                                  right: -6,
                                  bottom: -6,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.cardBorder),
                                    ),
                                    child: const Icon(Icons.edit_rounded, size: 13, color: AppColors.textDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _showPhotoMenu,
                            child: const Text('사진 변경',
                                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _field('이름', _name, hint: '예) 홍길동'),
                    const Text('성별', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _genderChip(Gender.male)),
                        const SizedBox(width: 10),
                        Expanded(child: _genderChip(Gender.female)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _field('키 (cm)', _height, hint: '예) 174', keyboardType: TextInputType.number),
                    _field('체중 (kg)', _weight, hint: '예) 68', keyboardType: TextInputType.number),
                    const Text('운동 목표', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FitnessGoal.values.map(_goalChip).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: PrimaryButton(label: widget.firstRun ? '다음' : '변경사항 저장', onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {String? hint, TextInputType? keyboardType}) {
    return _ExampleField(label: label, controller: controller, hint: hint, keyboardType: keyboardType);
  }

  Widget _genderChip(Gender g) {
    final selected = _gender == g;
    return GestureDetector(
      onTap: () => setState(() => _gender = g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 16, color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(g.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textDark,
                )),
          ],
        ),
      ),
    );
  }

  Widget _goalChip(FitnessGoal goal) {
    final selected = goal == _goal;
    return GestureDetector(
      onTap: () => setState(() => _goal = goal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder),
        ),
        child: Text(
          goal.title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}


/// 입력 칸을 누르거나(포커스) 글자를 쓰기 시작하면 회색 예시 문구가 사라지는 입력 칸.
class _ExampleField extends StatefulWidget {
  const _ExampleField({required this.label, required this.controller, this.hint, this.keyboardType});

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  State<_ExampleField> createState() => _ExampleFieldState();
}

class _ExampleFieldState extends State<_ExampleField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: widget.keyboardType,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              // 칸을 누르면(포커스) 예시가 바로 사라집니다.
              hintText: _focus.hasFocus ? null : widget.hint,
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textFaint),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
