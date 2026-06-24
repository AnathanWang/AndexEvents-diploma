import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/match/match_refresh_listener.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_service.dart';
import '../../models/match_preview.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../widgets/match_card.dart';

enum _MatchLikesFilter { mutual, incoming, liked }

class MatchLikesSheet extends StatefulWidget {
  const MatchLikesSheet({
    super.key,
    required this.currentUser,
    this.eventId,
  });

  final UserModel currentUser;
  final String? eventId;

  static Future<void> show(
    BuildContext context, {
    required UserModel currentUser,
    String? eventId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => MatchLikesSheet(
        currentUser: currentUser,
        eventId: eventId,
      ),
    );
  }

  @override
  State<MatchLikesSheet> createState() => _MatchLikesSheetState();
}

class _MatchLikesSheetState extends State<MatchLikesSheet>
    with MatchRefreshListener<MatchLikesSheet> {
  final UserService _userService = UserService();

  _MatchLikesFilter _filter = _MatchLikesFilter.mutual;
  bool _loading = true;
  String? _error;
  final Map<_MatchLikesFilter, List<MatchPreview>> _matchesByFilter =
      <_MatchLikesFilter, List<MatchPreview>>{};

  @override
  void initState() {
    super.initState();
    _loadMatchesFor(_filter);
  }

  @override
  void onMatchesShouldRefresh() {
    _invalidateAndReload();
  }

  void _invalidateAndReload() {
    _matchesByFilter.clear();
    if (!mounted) return;
    _loadMatchesFor(_filter);
  }

  Future<void> _loadMatchesFor(_MatchLikesFilter filter) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      List<UserModel> users;
      switch (filter) {
        case _MatchLikesFilter.mutual:
          users = await _userService.getMutualMatches(eventId: widget.eventId);
          break;
        case _MatchLikesFilter.incoming:
          users = await _userService.getIncomingLikes(eventId: widget.eventId);
          break;
        case _MatchLikesFilter.liked:
          users = await _userService.getUsersByMatchAction(
            action: 'LIKE',
            eventId: widget.eventId,
          );
          break;
      }

      if (filter != _MatchLikesFilter.mutual) {
        final mutualUsers = await _userService.getMutualMatches(
          eventId: widget.eventId,
        );
        final mutualIds = mutualUsers.map((u) => u.id).toSet();
        users = users.where((u) => !mutualIds.contains(u.id)).toList();
      }

      final previews = users
          .map(
            (u) => MatchPreview.fromUserModel(
              u,
              currentUser: widget.currentUser,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _matchesByFilter[filter] = previews;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _matchesByFilter[filter] = <MatchPreview>[];
      });
    }
  }

  bool get _canViewSensitiveInfo =>
      _filter == _MatchLikesFilter.mutual ||
      _filter == _MatchLikesFilter.incoming;

  Widget _buildFilterChip(_MatchLikesFilter filter, String label, IconData icon) {
    final selected = _filter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          if (selected) {
            _loadMatchesFor(filter);
            return;
          }
          setState(() => _filter = filter);
          _loadMatchesFor(filter);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: <Color>[Color(0xFF5F76FF), Color(0xFF2E8BFF)],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : AppColors.primary.withValues(alpha: 0.16),
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.24),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : AppColors.dark.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    final matches = _matchesByFilter[_filter] ?? <MatchPreview>[];

    if (_loading && matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null && matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
        child: Text(
          'Не удалось загрузить: $_error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    if (matches.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadMatchesFor(_filter),
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 42,
                    color: AppColors.dark.withValues(alpha: 0.28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _emptyMessage(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.dark.withValues(alpha: 0.58),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadMatchesFor(_filter),
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: matches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final match = matches[index];
          return MatchCard(
            match: match,
            onOpenProfile: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => UserProfileScreen.fromUser(
                    user: match.userModel,
                    matchPercentage: match.matchPercentage,
                    commonInterests: match.commonInterests,
                    canViewSensitiveInfo: _canViewSensitiveInfo,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _emptyMessage() {
    switch (_filter) {
      case _MatchLikesFilter.mutual:
        return 'Пока нет взаимных лайков.\nСвайпайте вправо — возможно, совпадение уже близко.';
      case _MatchLikesFilter.incoming:
        return 'Пока никто не лайкнул вас.\nЗаполните профиль и продолжайте смотреть анкеты.';
      case _MatchLikesFilter.liked:
        return 'Вы ещё никого не лайкнули.\nСвайпните вправо, чтобы поставить лайк.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFFF5F9FF),
                    Color(0xFFE8F1FF),
                    Color(0xFFF0F6FF),
                  ],
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFFD7E4FF)),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.dark.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[Color(0xFF5F76FF), Color(0xFF2E8BFF)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.22),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Ваши лайки',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F3552),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Взаимные и входящие симпатии',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF66739B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _invalidateAndReload,
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: AppColors.dark.withValues(alpha: 0.5),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.dark.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: <Widget>[
                          _buildFilterChip(
                            _MatchLikesFilter.mutual,
                            'Взаимные',
                            Icons.favorite_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            _MatchLikesFilter.incoming,
                            'Меня лайкнули',
                            Icons.favorite_border_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            _MatchLikesFilter.liked,
                            'Лайкнул',
                            Icons.thumb_up_alt_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildBody(scrollController)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MatchLikesButton extends StatelessWidget {
  const MatchLikesButton({
    super.key,
    required this.currentUser,
    this.eventId,
  });

  final UserModel currentUser;
  final String? eventId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => MatchLikesSheet.show(
          context,
          currentUser: currentUser,
          eventId: eventId,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF5F76FF), Color(0xFF2E8BFF)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Мои лайки',
                    style: TextStyle(
                      color: Color(0xFF1F3552),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
