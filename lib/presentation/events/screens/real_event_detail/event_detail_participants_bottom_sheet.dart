import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/event_model.dart';
import '../../bloc/event_bloc.dart';
import '../../bloc/event_state.dart';
import '../../widgets/event_participants_dialog.dart';

class EventDetailParticipantsBottomSheet extends StatelessWidget {
  const EventDetailParticipantsBottomSheet({
    super.key,
    required this.event,
    required this.eventBloc,
  });

  final EventModel event;
  final EventBloc eventBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: eventBloc,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: BlocBuilder<EventBloc, EventState>(
            builder: (context, state) {
              if (state is EventParticipantsLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (state is EventParticipantsLoaded) {
                return EventParticipantsDialog(
                  participants: state.participants,
                  eventTitle: event.title,
                  scrollController: controller,
                );
              }

              if (state is EventError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(state.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Закрыть'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

