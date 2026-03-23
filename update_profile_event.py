import re

with open('lib/presentation/profile/bloc/profile_event.dart', 'r') as f:
    content = f.read()

fields_to_add = """  final bool? showVisitedEvents;
  final bool? showInMatches;
  final bool? incognitoMode;
  final bool? hideOnlineStatus;"""

content = re.sub(r'(  final Map<String, String>\? socialLinks;)', r'\1\n' + fields_to_add, content)

constructor_to_add = """    this.showVisitedEvents,
    this.showInMatches,
    this.incognitoMode,
    this.hideOnlineStatus,"""

content = re.sub(r'(    this\.socialLinks,)', r'\1\n' + constructor_to_add, content)

props_to_add = """    showVisitedEvents,
    showInMatches,
    incognitoMode,
    hideOnlineStatus,"""

content = re.sub(r'(    socialLinks,)', r'\1\n' + props_to_add, content)

with open('lib/presentation/profile/bloc/profile_event.dart', 'w') as f:
    f.write(content)
