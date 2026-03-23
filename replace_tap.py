import re

with open('lib/presentation/home/screens/profile_screen.dart', 'r') as f:
    text = f.read()

start_str = "Widget _buildEventCard(dynamic event, BuildContext context) {"
end_str = "child: Container("

start_idx = text.find(start_str)
end_idx = text.find(end_str, start_idx)

new_tap = """Widget _buildEventCard(dynamic event, BuildContext context, {bool isCreator = false}) {
    return GestureDetector(
      onTap: () async {
        if (isCreator) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (context) => EventBloc(),
                child: EditEventScreen(event: event),
              ),
            ),
          );

          if (result == true && context.mounted) {
            context.read<ProfileBloc>().add(const ProfileLoadRequested());
          }
        } else {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (context) => EventBloc(),
                child: RealEventDetailScreen(eventId: event.id),
              ),
            ),
          );
          
          if (result == true && context.mounted) {
            context.read<ProfileBloc>().add(const ProfileLoadRequested());
          }
        }
      },
      """

if start_idx != -1 and end_idx != -1:
    text = text[:start_idx] + new_tap + text[end_idx:]
    with open('lib/presentation/home/screens/profile_screen.dart', 'w') as f:
        f.write(text)
    print("Success")
else:
    print("Error finding strings")
