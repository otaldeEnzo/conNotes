import re
import sys

# Comprehensive Unicode regex for Emoji characters per Unicode Technical Standard #51
EMOJI_PATTERN = re.compile(
    r'['
    r'\U0001F600-\U0001F64F'  # Emoticons
    r'\U0001F300-\U0001F5FF'  # Misc Symbols and Pictographs
    r'\U0001F680-\U0001F6FF'  # Transport and Map
    r'\U0001F1E0-\U0001F1FF'  # Flags (iOS & Android)
    r'\U0001F900-\U0001F9FF'  # Supplemental Symbols and Pictographs
    r'\U0001FA70-\U0001FAFF'  # Symbols and Pictographs Extended-A
    r'\U00002702-\U000027B0'  # Dingbats
    r'\U000024C2-\U0001F251'  # Enclosed Characters
    r'\U0001F004\U0001F0CF'
    r'\U000020E3\U000021A9-\U000021AA\U0000231A-\U0000231B\U000023E9-\U000023EC'
    r'\U000023F0\U000023F3\U000025FD-\U000025FE\U00002614-\U00002615\U00002648-\U00002653'
    r'\U0000267F\U00002693\U000026A1\U000026AA-\U000026AB\U000026BD-\U000026BE\U000026C4-\U000026C5'
    r'\U000026CE\U000026D4\U000026EA\U000026F2-\U000026F3\U000026F5\U000026FA\U000026FD'
    r'\U00002705\U0000270A-\U0000270B\U00002728\U0000274C\U0000274E\U00002753-\U00002755'
    r'\U00002757\U00002795-\U00002797\U000027B0\U000027BF\U00002B1B-\U00002B1C\U00002B50\U00002B55'
    r']+',
    flags=re.UNICODE
)

files_to_check = [
    r'app/lib/widgets/canvas_card_pdf_view.dart',
    r'app/lib/widgets/pdf_page_subcard_widget.dart',
    r'app/lib/widgets/pdf_corner_resize_handle.dart',
    r'app/lib/widgets/canvas_card_widget.dart',
    r'app/test/pdf_card_widget_test.dart',
    r'app/test/pdf_sliding_window_virtualization_test.dart',
]

total_found = 0
print("=== EMOJI FORENSIC AUDIT (UTS #51) ===")
for file_path in files_to_check:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    matches = list(EMOJI_PATTERN.finditer(content))
    if matches:
        print(f"VIOLATION: Found {len(matches)} emoji(s) in {file_path}:")
        for m in matches:
            line_no = content[:m.start()].count('\n') + 1
            print(f"  Line {line_no}: {repr(m.group())}")
        total_found += len(matches)
    else:
        print(f"PASS: 0 emojis in {file_path}")

if total_found == 0:
    print("\nVERDICT: CLEAN — ZERO EMOJIS FOUND ACROSS ALL AUDITED FILES.")
    sys.exit(0)
else:
    print(f"\nVERDICT: INTEGRITY VIOLATION — {total_found} EMOJIS DETECTED.")
    sys.exit(1)
