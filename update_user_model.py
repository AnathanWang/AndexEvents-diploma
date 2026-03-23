import re

with open('lib/data/models/user_model.dart', 'r') as f:
    content = f.read()

# Add fields
fields_to_add = """  final bool showVisitedEvents;
  final bool showInMatches;
  final bool incognitoMode;
  final bool hideOnlineStatus;"""

content = re.sub(r'(  final bool isOnboardingCompleted;)', r'\1\n' + fields_to_add, content)

# Add to constructor
constructor_to_add = """    this.showVisitedEvents = true,
    this.showInMatches = true,
    this.incognitoMode = false,
    this.hideOnlineStatus = false,"""

content = re.sub(r'(    required this.isOnboardingCompleted,)', r'\1\n' + constructor_to_add, content)

# Add to fromJson
from_json_to_add = """      showVisitedEvents: json['showVisitedEvents'] as bool? ?? true,
      showInMatches: json['showInMatches'] as bool? ?? true,
      incognitoMode: json['incognitoMode'] as bool? ?? false,
      hideOnlineStatus: json['hideOnlineStatus'] as bool? ?? false,"""

content = re.sub(r'(      isOnboardingCompleted: json\[\'import re

with open('lib/data/mode \
with ope,)    content = f.read()

# Add fields
fields_to_add oJson
# Add fields
fields_   fields_toisit  final bool showInMatches;
  final bool incognits'  final bool incognitoModeco  final bool hideOnlineSt,
 
content = re.sub(r'(  final booine
# Add to constructor
constructor_to_add = """    this.showVisitedEvents = true,
    this.sr'\constructor_to_add dd    this.showInMatches = true,
    this.incognitoMode = fdd    this.incognitoMode = falsen    this.hideOnlineStatus = fa  
content = re.sub(r'(    required thOnl
# Add to fromJson
from_json_to_add = """      showVisitedEvents: json['showVisitedEvents'] as bool? addfrom_json_to_addd       showInMatches: json['showInMatches'] as bool? ?? true,
      incognitoMode: json['i ?      incognitoMode: json['incognitoMode'] as bool? ?? falss       hideOnlineStatus: json['hideOnlineStatus'] as bool? ?? t
content = re.sub(r'(      isOnboardingCompleted: json\[\'import re

ide
with open('lib/data/mode \
with ope,)    content = f.read()

# A:\nwith ope,)    content = fpl
# Add fields
fields_to_aingComplefields_to_a1\# Add fields
fieldrnfields_   fnt  final bool incognits'  final bool incognitoMot',  
conts f:
    f.write(content)

