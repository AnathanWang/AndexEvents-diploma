import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/services/user_service.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../screens/edit_profile_screen.dart';

Future<bool?> openEditProfile(BuildContext context) {
  try {
    final profileBloc = context.read<ProfileBloc>();
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BlocProvider.value(
          value: profileBloc,
          child: const EditProfileScreen(),
        ),
      ),
    );
  } catch (_) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BlocProvider(
          create: (_) => ProfileBloc(userService: UserService())
            ..add(const ProfileLoadRequested()),
          child: const EditProfileScreen(),
        ),
      ),
    );
  }
}
