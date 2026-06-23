import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
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
        LoggerService.warning(
          '🟡 [MatchesScreen] _currentUser is null, cannot load matches',
        );
        return;
      }

      LoggerService.debug('🔵 [MatchesScreen] Starting to load matches...');
      LoggerService.debug(
        '🔵 [MatchesScreen] Current user location: lat=${_currentUser!.lastLatitude}, lon=${_currentUser!.lastLongitude}',
      );

      final otherUsers = await _userService.getOtherUsers(
        limit: 30,
        latitude: _currentUser!.lastLatitude,
        longitude: _currentUser!.lastLongitude,
        radiusKm: 50,
      );
      final mutualMatches = await _userService.getMutualMatches();
      final mutualIds = mutualMatches.map((u) => u.id).toSet();

      LoggerService.debug(
        '🔵 [MatchesScreen] Received ${otherUsers.length} users from service',
      );

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

      if (otherUsers.isNotEmpty) {
        LoggerService.debug(
          '🔵 [MatchesScreen] First user: name=${otherUsers.first.displayName}, photoUrl=${otherUsers.first.photoUrl}',
        );
      }

      if (mounted) {
        setState(() {
          // Конвертируем UserModel в MatchPreview
          _matches = filteredUsers.map((user) {
            final match = MatchPreview.fromUserModel(
              user,
              currentUserInterests: _currentUser?.interests ?? const <String>[],
            );
            LoggerService.info(
              '🟢 [MatchesScreen] Created match: name=${match.name}, age=${match.age}, photoUrl=${match.photoUrl}',
            );
            return match;
          }).toList();
          LoggerService.info(
            '🟢 [MatchesScreen] Loaded ${_matches.length} matches into state',
          );
        });
      }
    } catch (e) {
      LoggerService.error('🔴 [MatchesScreen] Error loading matches: $e');
    }
  }

  Future<void> _refreshMatches({bool resetSeen = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getCurrentUser();
      if (!mounted) return;
      _currentUser = user;

      if (resetSeen) {
        await _matchSeenService.clear(user.id);
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
    } catch (e) {
      LoggerService.error('🔴 [MatchesScreen] Error refreshing matches: $e');
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
    } catch (e) {
      LoggerService.warning(
        '🟡 [MatchesScreen] Не удалось загрузить свежий профиль, используем данные карточки: $e',
      );
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
      LoggerService.debug('🔵 [MatchesScreen] Loading current user...');
      final user = await _userService.getCurrentUser();

      LoggerService.info(
        '🟢 [MatchesScreen] User loaded: name=${user.displayName}, onboardingCompleted=${user.isOnboardingCompleted}',
      );

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });

        // После загрузки текущего пользователя, загружаем матчи
        if (user.isOnboardingCompleted) {
          LoggerService.debug(
            '🔵 [MatchesScreen] Onboarding completed, loading matches...',
          );
          await _loadMatches();
        } else {
          LoggerService.warning(
            '🟡 [MatchesScreen] Onboarding not completed, showing incomplete screen',
          );
        }
      }
    } catch (e) {
      LoggerService.error('🔴 [MatchesScreen] Error loading user data: $e');
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
    LoggerService.info('🟢 [_handleLike] Like: ${match.name}');

    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      LoggerService.warning('🟡 [_handleLike] Skip self-like for userId=$currentUserId');
      return;
    }

    _userService
        .sendLike(match.id)
        .then((_) {
          if (currentUserId != null) {
            _matchSeenService.markSeen(currentUserId, match.id);
          }
          LoggerService.info(
            '🟢 [_handleLike] Successfully sent like for ${match.name}',
          );
        })
        .catchError((e) {
          LoggerService.error('🔴 [_handleLike] Error sending like: $e');
        });
  }

  void _handleDislike(MatchPreview match) {
    LoggerService.debug('🔴 [_handleDislike] Dislike: ${match.name}');

    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      LoggerService.warning('🟡 [_handleDislike] Skip self-dislike for userId=$currentUserId');
      return;
    }

    _userService
        .sendDislike(match.id)
        .then((_) {
          if (currentUserId != null) {
            _matchSeenService.markSeen(currentUserId, match.id);
          }
          LoggerService.info(
            '🟢 [_handleDislike] Successfully sent dislike for ${match.name}',
          );
        })
        .catchError((e) {
          LoggerService.error('🔴 [_handleDislike] Error sending dislike: $e');
        });
  }

  void _handleSuperLike(MatchPreview match) {
    LoggerService.debug('🔵 [_handleSuperLike] Super Like: ${match.name}');

    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      LoggerService.warning('🟡 [_handleSuperLike] Skip self-super-like for userId=$currentUserId');
      return;
    }

    _userService
        .sendSuperLike(match.id)
        .then((_) {
          if (currentUserId != null) {
            _matchSeenService.markSeen(currentUserId, match.id);
          }
          LoggerService.info(
            '🟢 [_handleSuperLike] Successfully sent super like for ${match.name}',
          );
        })
        .catchError((e) {
          LoggerService.error('🔴 [_handleSuperLike] Error sending super like: $e');
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
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFEAF2FF),
                  Color(0xFFD9E8FF),
                  Color(0xFFEFF5FF),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -70,
          left: -60,
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -40,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.24),
            ),
          ),
        ),
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
