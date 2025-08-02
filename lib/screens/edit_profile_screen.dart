// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:onecup/common/show_top_banner.dart';
import 'package:onecup/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedAvatarFile;
  bool _isUploadingAvatar = false;
  bool _isUpdatingNickname = false;
  final TextEditingController _nicknameController = TextEditingController();
  String? _currentAvatarUrl;
  String? _initialNickname;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
  }

  void _loadCurrentUserProfile() {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      final authRepository = ref.read(authRepositoryProvider);
      _initialNickname = authRepository.getUserNickname(currentUser) ?? currentUser.email?.split('@').first ?? '';
      _nicknameController.text = _initialNickname!;
      _currentAvatarUrl = authRepository.getAvatarUrl(currentUser);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<CroppedFile?> _cropImage(String filePath) async {
    final theme = Theme.of(context);
    return await ImageCropper().cropImage(
      sourcePath: filePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁剪头像',
          toolbarColor: theme.appBarTheme.backgroundColor,
          toolbarWidgetColor: theme.appBarTheme.titleTextStyle?.color,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          backgroundColor: Colors.white,
          activeControlsWidgetColor: theme.colorScheme.secondary,
          cropStyle: CropStyle.circle,
          dimmedLayerColor: Colors.black.withOpacity(0.5),
        ),
        IOSUiSettings(
          title: '裁剪头像',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          minimumAspectRatio: 1.0,
          aspectRatioPickerButtonHidden: true,
          doneButtonTitle: '完成',
          cancelButtonTitle: '取消',
        ),
      ],
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      showTopBanner(context, '用户未登录', isError: true);
      return;
    }

    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    final CroppedFile? croppedImage = await _cropImage(pickedImage.path);
    if (croppedImage == null) return;

    setState(() {
      _selectedAvatarFile = File(croppedImage.path);
      _isUploadingAvatar = true;
    });

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final newAvatarUrl = await authRepository.uploadAvatar(croppedImage.path, currentUser.id);
      final response = await authRepository.updateUserMetadata({'avatar_url': newAvatarUrl});

      if (response.user != null) {
        if (mounted) {
          showTopBanner(context, '头像更新成功！');
          setState(() {
            _currentAvatarUrl = newAvatarUrl;
            _selectedAvatarFile = null;
          });
        }
      } else {
        if (mounted) showTopBanner(context, '头像更新失败', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showTopBanner(context, '头像处理失败: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _updateNickname() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      showTopBanner(context, '用户未登录', isError: true);
      return;
    }
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isEmpty) {
      showTopBanner(context, '昵称不能为空', isError: true);
      return;
    }
    if (newNickname == _initialNickname) {
      showTopBanner(context, '昵称未更改', isError: false);
      return;
    }

    setState(() => _isUpdatingNickname = true);

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final response = await authRepository.updateUserMetadata({'nickname': newNickname});
      if (response.user != null) {
        if (mounted) {
          showTopBanner(context, '昵称更新成功！');
          setState(() {
            _initialNickname = newNickname;
          });
        }
      } else {
        if (mounted) showTopBanner(context, '昵称更新失败', isError: true);
      }
    } catch (e) {
      if (mounted) showTopBanner(context, '昵称更新错误: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingNickname = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑个人资料')),
        body: const Center(child: Text('用户未登录或数据加载失败。')),
      );
    }

    Widget avatarDisplay;
    if (_isUploadingAvatar && _selectedAvatarFile != null) {
      avatarDisplay = CircleAvatar(
        radius: 50,
        backgroundImage: FileImage(_selectedAvatarFile!),
        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (_selectedAvatarFile != null) {
      avatarDisplay = CircleAvatar(radius: 50, backgroundImage: FileImage(_selectedAvatarFile!));
    } else if (_currentAvatarUrl != null) {
      avatarDisplay = CircleAvatar(radius: 50, backgroundImage: NetworkImage(_currentAvatarUrl!));
    } else {
      avatarDisplay = CircleAvatar(
        radius: 50,
        backgroundColor: theme.primaryColor.withOpacity(0.1),
        child: Icon(Icons.person, size: 50, color: theme.primaryColor),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑个人资料'),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  avatarDisplay,
                  Material(
                    color: theme.colorScheme.secondary,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.edit,
                          color: theme.colorScheme.onSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '昵称不能为空';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _isUpdatingNickname
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: const Text('保存昵称'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isUpdatingNickname || _isUploadingAvatar ? null : _updateNickname,
            ),
          ],
        ),
      ),
    );
  }
}
