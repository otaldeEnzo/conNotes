import sys
import unicodedata
from pathlib import Path

FILES_TO_CHECK = [
    r"c:\Users\Enzo\Documents\conNotes\app\pubspec.yaml",
    r"c:\Users\Enzo\Documents\conNotes\app\lib\models\canvas_card_model.dart",
    r"c:\Users\Enzo\Documents\conNotes\app\lib\services\pdf_document_service.dart",
    r"c:\Users\Enzo\Documents\conNotes\app\test\pdf_card_model_test.dart",
]

# Standard Unicode Emoji ranges based on Unicode Technical Standard #51
EMOJI_RANGES = [
    (0x1F600, 0x1F64F),  # Emoticons
    (0x1F300, 0x1F5FF),  # Misc Symbols and Pictographs
    (0x1F680, 0x1F6FF),  # Transport and Map
    (0x1F700, 0x1F77F),  # Alchemical Symbols
    (0x1F780, 0x1F7FF),  # Geometric Shapes Extended
    (0x1F800, 0x1F8FF),  # Supplemental Arrows-C
    (0x1F900, 0x1F9FF),  # Supplemental Symbols and Pictographs
    (0x1FA00, 0x1FA6F),  # Chess Symbols
    (0x1FA70, 0x1FAFF),  # Symbols and Pictographs Extended-A
    (0x2600, 0x26FF),    # Misc symbols
    (0x2700, 0x27BF),    # Dingbats
    (0xFE00, 0xFE0F),    # Variation Selectors
    (0x1F000, 0x1F02F),  # Mahjong Tiles
    (0x1F0A0, 0x1F0FF),  # Playing Cards
    (0x231A, 0x231B),    # Watch, Hourglass
    (0x23E9, 0x23EC),    # Fast forward, etc.
    (0x23F0, 0x23F3),    # Alarm clock, etc.
    (0x25FD, 0x25FE),    # Small squares
    (0x2B50, 0x2B50),    # Star
    (0x2B55, 0x2B55),    # Heavy large circle
]

def is_emoji(char):
    cp = ord(char)
    for start, end in EMOJI_RANGES:
        if start <= cp <= end:
            return True
    return False

violations = []

for file_path in FILES_TO_CHECK:
    p = Path(file_path)
    if not p.exists():
        print(f"File not found: {file_path}")
        continue
    content = p.read_text(encoding="utf-8")
    lines = content.splitlines()
    for line_idx, line in enumerate(lines, start=1):
        for col_idx, ch in enumerate(line, start=1):
            if is_emoji(ch):
                violations.append({
                    "file": file_path,
                    "line": line_idx,
                    "col": col_idx,
                    "char": ch,
                    "code_point": f"U+{ord(ch):04X}",
                    "name": unicodedata.name(ch, "UNKNOWN"),
                    "line_text": line,
                })

print("=== EMOJI FORENSIC AUDIT REPORT ===")
if violations:
    print(f"FAILED: Found {len(violations)} emoji violations!")
    for v in violations:
        print(f"  {v['file']}:{v['line']}:{v['col']} [{v['code_point']}] ({v['name']}) -> {v['line_text']}")
    sys.exit(1)
else:
    print("PASSED: 0 emojis found across all audited files. Clean adherence to No Emojis rule.")
    sys.exit(0)
