import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../data/services/user_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/match_seen_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../matches/widgets/match_likes_sheet.dart';
import '../../matches/widgets/match_swipe_deck.dart';
import '../../models/match_preview.dart';
import '../../profile/navigation/open_edit_profile.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../widgets/common/custom_notification.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, this.matches = const []});

  final List<MatchPreview> matches;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  UserModel? _currentUser;
  late List<MatchPreview> _matches;
  int _deckEpoch = 0;

  final UserService _userService = UserService();
  final MatchSeenService _matchSeenService = MatchSeenService();

  @override
  void initState() {
    super.initState();
    _matches = widget.matches;
    _loadUserData();
  }

  Future<void> _loadMatches() async {
    try {
      if (_currentUser == null) {
        return;
      }

      final results = await Future.wait<List<UserModel>>([
        _userService.getOtherUsers(
          limit: 30,
          latitude: _currentUser!.lastLatitude,
          longitude: _currentUser!.lastLongitude,
          radiusKm: 50,
        ),
        _userService.getMutualMatches(),
      ]);
      final otherUsers = results[0];
      final mutualMatches = results[1];
      final mutualIds = mutualMatches.map((u) => u.id).toSet();

      final currentUserId = _currentUser!.id;
      final seen = await _matchSeenService.getSeenUserIds(currentUserId);
      final Map<String, UserModel> uniqueUsers = <String, UserModel>{};
      for (final u in otherUsers) {
        if (u.id == currentUserId) continue;
        if (mutualIds.contains(u.id)) continue;
        if (seen.contains(u.id)) continue;
        uniqueUsers[u.id] = u;
      }

      final filteredUsers = uniqueUsers.values.toList();

      if (mounted) {
        setState(() {
          _matches = filteredUsers
              .map(
                (user) => MatchPreview.fromUserModel(
                  user,
                  currentUserInterests: _currentUser?.interests ?? const <String>[],
                ),
              )
              .toList();
        });
      }
    } catch (_) {
      // UI shows empty state
    }
  }

  Future<void> _refreshMatches({bool resetSeen = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUser ??= await _userService.getCurrentUser();
      if (!mounted) return;

      if (resetSeen && _currentUser != null) {
        await _matchSeenService.clear(_currentUser!.id);
      }
      await _loadMatches();
      if (!mounted) return;

      setState(() {
        _deckEpoch++;
      });

      if (_matches.isEmpty) {
        CustomNotification.show(context, 'Новых анкет пока нет');
      } else {
        CustomNotification.success(context, 'Подборка обновлена');
      }
    } catch (_) {
      if (mounted) {
        CustomNotification.show(
          context,
          'Не удалось обновить подборку',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openUserProfile(MatchPreview match) async {
    UserModel userToOpen = match.userModel;

    try {
      userToOpen = await _userService.getUserById(match.id);
    } catch (_) {
      // Use card data when refresh fails.
    }

    if (!mounted) return;

    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => UserProfileScreen.fromUser(
          user: userToOpen,
          matchPercentage: match.matchPercentage,
          commonInterests: match.commonInterests,
          canViewSensitiveInfo: false,
        ),
      ),
    );
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getCurrentUser();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });

        if (user.isOnboardingCompleted) {
          await _loadMatches();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isProfileComplete {
    if (_currentUser == null) return false;
    // Profile is complete when onboarding is finished
    return _currentUser!.isOnboardingCompleted;
  }

  Future<void> _openEditProfile() async {
    final result = await openEditProfile(context);
    if (result == true && mounted) {
      CustomNotification.success(context, 'Профиль успешно обновлен!');
    }
    await _loadUserData();
  }

  void _handleLike(MatchPreview match) {
    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      return;
    }

    _userService.sendLike(match.id).then((_) {
      if (currentUserId != null) {
        _matchSeenService.markSeen(currentUserId, match.id);
      }
    });
  }

  void _handleDislike(MatchPreview match) {
    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      return;
    }

    _userService.sendDislike(match.id).then((_) {
      if (currentUserId != null) {
        _matchSeenService.markSeen(currentUserId, match.id);
      }
    });
  }

  void _handleSuperLike(MatchPreview match) {
    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      return;
    }

    _userService.sendSuperLike(match.id).then((_) {
      if (currentUserId != null) {
        _matchSeenService.markSeen(currentUserId, match.id);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (!_isProfileComplete) {
      return _buildProfileIncompleteScreen();
    }

    if (_matches.isEmpty) {
      return _buildNoMatchesScreen();
    }

    return _buildMainContent();
  }

  Widget _buildProfileIncompleteScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Заполните профиль для матчей',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Добавьте имя, фото, описание о себе и интересы, чтобы найти людей с похожими увлечениями',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.dark.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit, size: 20),
              label: const Text('Заполнить профиль'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchesScreen() {
    return Stack(
      children: <Widget>[
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.56),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 64,
                color: AppColors.dark.withValues(alpha: 0.46),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Совпадений пока нет',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Посещайте мероприятия, чтобы встретить людей с похожими интересами',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.dark.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _refreshMatches(resetSeen: true),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Обновить подборку'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Редактировать профиль'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.6,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
            ),
          ),
        ),
        if (_currentUser != null) _buildLikesButton(),
      ],
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        Positioned.fill(
          child: MatchSwipeDeck(
            key: ValueKey('matches-deck-$_deckEpoch'),
            matches: _matches,
            onOpenProfile: _openUserProfile,
            onSwipe: (action, match) {
              switch (action) {
                case MatchSwipeAction.like:
                  _handleLike(match);
                  break;
                case MatchSwipeAction.dislike:
                  _handleDislike(match);
                  break;
                case MatchSwipeAction.later:
                  _handleSuperLike(match);
                  break;
                case MatchSwipeAction.info:
                  break;
              }
            },
            onDeckEmpty: () {
              if (!mounted) return;
              setState(() => _matches = <MatchPreview>[]);
            },
          ),
        ),
        if (_currentUser != null) _buildLikesButton(),
      ],
    );
  }

  Widget _buildLikesButton() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      right: 16,
      child: MatchLikesButton(currentUser: _currentUser!),
    );
  }

}
