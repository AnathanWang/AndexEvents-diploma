import re

with open('lib/presentation/profile/bloc/profile_bloc.dart', 'r') as f:
    content = f.read()

args_to_add = """        showVisitedEvents: event.showVisitedEvents,
        showInMatches: event.showInMatches,
        incognitoMode: event.incognitoMode,
        hideOnlineStatus: event.hideOnlineStatus,"""

content = re.sub(r'(        socialLinks: event\.socialLinks,)', r'\1\n' + args_to_add, content)

with open('lib/presentation/profile/bloc/profile_bloc.dart', 'w') as f:
    f.write(content)
