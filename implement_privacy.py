import re
with open('lib/presentation/home/screens/profile_screen.dart', 'r') as f:
    content = f.read()

method_to_add = """  Future<void> _openPrivacySettings(UserModel user) async {
    final result = await Navigator.of(context).push<Map<String, bool>>(
      MaterialPageRoute<Map<String, bool>>(
        builder: (context) => PrivacySettingsScreen(
          showVisitedEvents: user.showVisitedEvents,
          showInMatches: user.showInMatches,
          incognitoMode: user.incognitoMode,
          hideOnlineStatus: user.hideOnlineStatus,
        ),
      ),
    );
    if (result == null || !mounted) return;
    context.read<ProfileBloc>().add(
      ProfileUpdateRequested(
        showVisitedEvents: result['showVisitedEvents'],
        showInMatches: result['showInMatches'],
        incognitoMode: result['incognitoMode'],
        hideOnlineStatus: result['hideOnlineStatus'],
      ),
    );
  }"""

content = re.sub(r'(  @override\n  Widget build\(BuildContext contextimport re
with open('lib/presentatintwith opete    content = f.read()

method_to_add = """  Future<void> _openPrivacySetr
method_to_add = """ ifi    final result = await Navigator.of(context).push<Map<String, bool>>(
     tt      MaterialPageRoute<Map<String, bool>>(
        builder: (context)h  pen('lib/presentation/home/screens/profile_screen.dart', 'w') as f:
    f.write(content)
