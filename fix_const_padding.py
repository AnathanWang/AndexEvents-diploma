import re

with open('lib/presentation/profile/screens/user_profile_screen.dart', 'r') as f:
    text = f.read()

text = text.replace(
    'const Padding(\n                    padding: EdgeInsets.symmetric(horizontal: 20),\n                    child: _SectionTitleRow(',
    'Padding(\n                    padding: const EdgeInsets.symmetric(horizontal: 20),\n                    child: _SectionTitleRow('
)

with open('lib/presentation/profile/screens/user_profile_screen.dart', 'w') as f:
    f.write(text)

print("Fixed const padding")
