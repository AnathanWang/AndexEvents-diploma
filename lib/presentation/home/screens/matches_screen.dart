import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/match/match_refresh_listener.dart';
import '../../../core/utils/match_feed_utils.dart';
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
    with TickerProviderStateMixin, MatchRefreshListener<MatchesScreen> {
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

  @override
  void onMatchesShouldRefresh() {
    _silentRefreshMatches();
  }

  Future<void> _silentRefreshMatches() async {
    if (_currentUser == null || !_isProfileComplete || _isLoading) return;
    // Don't interrupt an active swipe deck with a server reload.
    if (_matches.isNotEmpty) return;
    try {
      await _loadMatches();
    } catch (_) {
      // Keep current deck on transient errors.
    }
  }

  Future<void> _loadMatches({
    bool includeActed = false,
    bool skipSeenFilter = false,
    bool replaceDeck = true,
  }) async {
    try {
      if (_currentUser == null) {
        return;
      }

      final results = await Future.wait<List<UserModel>>([
        _userService.getOtherUsers(
          limit: includeActed ? 40 : 30,
          latitude: _currentUser!.lastLatitude,
          longitude: _currentUser!.lastLongitude,
          radiusKm: 50,
          includeActed: includeActed,
        ),
        _userService.getMutualMatches(),
        _userService.getIncomingLikes(),
      ]);
      final otherUsers = results[0];
      final mutualMatches = results[1];
      final incomingLikes = results[2];
      final mutualIds = mutualMatches.map((u) => u.id).toSet();
      final incomingLikeIds = incomingLikes.map((u) => u.id).toSet();

      final currentUserId = _currentUser!.id;
      final seen = skipSeenFilter
          ? <String>{}
          : await _matchSeenService.getSeenUserIds(currentUserId);
      final Map<String, UserModel> uniqueUsers = <String, UserModel>{};
      for (final u in otherUsers) {
        if (u.id == currentUserId) continue;
        if (mutualIds.contains(u.id)) continue;
        if (seen.contains(u.id)) continue;
        uniqueUsers[u.id] = u;
      }

      final filteredUsers = preserveServerMatchOrder(
        serverOrder: otherUsers,
        filteredById: uniqueUsers,
      );

      final newMatches = filteredUsers
          .map(
            (user) => MatchPreview.fromUserModel(
              user,
              currentUser: _currentUser,
              incomingLikeUserIds: incomingLikeIds,
            ),
          )
          .toList();

      if (!mounted) return;
      if (!replaceDeck && newMatches.isEmpty && _matches.isNotEmpty) {
        return;
      }

      setState(() {
        _matches = newMatches;
      });
    } catch (_) {
      // UI shows empty state
    }
  }

  Future<void> _refreshMatches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUser ??= await _userService.getCurrentUser();
      if (!mounted) return;

      if (_currentUser != null) {
        await _matchSeenService.clear(_currentUser!.id);
      }
      await _loadMatches(
        includeActed: true,
        skipSeenFilter: true,
        replaceDeck: true,
      );
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

  void _removeFromDeck(String matchId) {
    if (!mounted) return;
    setState(() {
      _matches = _matches.where((match) => match.id != matchId).toList();
    });
  }

  void _handleLike(MatchPreview match) {
    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      return;
    }

    _removeFromDeck(match.id);
    if (currentUserId != null) {
      _matchSeenService.markSeen(currentUserId, match.id);
    }

    _userService.sendLike(match.id, refreshMatches: false);
  }

  void _handleDislike(MatchPreview match) {
    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      return;
    }

    _removeFromDeck(match.id);
    if (currentUserId != null) {
      _matchSeenService.markSeen(currentUserId, match.id);
    }

    _userService.sendDislike(match.id, refreshMatches: false);
  }

  void _handleSuperLike(MatchPreview match) {
    final currentUserId = _currentUser?.id;
    if (currentUserId != null && currentUserId == match.id) {
      return;
    }

    _removeFromDeck(match.id);
    if (currentUserId != null) {
      _matchSeenService.markSeen(currentUserId, match.id);
    }

    _userService.sendSuperLike(match.id, refreshMatches: false);
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
              onPressed: _refreshMatches,
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
        if (_currentUser != null) ...[
          _buildRefreshButton(),
          _buildLikesButton(),
        ],
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
              if (!mounted || _matches.isEmpty) return;
            },
          ),
        ),
        if (_currentUser != null) ...[
          _buildRefreshButton(),
          _buildLikesButton(),
        ],
      ],
    );
  }

  Widget _buildRefreshButton() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        elevation: 0,
        shadowColor: AppColors.dark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: _isLoading ? null : _refreshMatches,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'Обновить',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
