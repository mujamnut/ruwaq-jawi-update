#!/usr/bin/env python3
"""
Remove all print() and debugPrint() statements from lib/core folder
Keeps if (kDebugMode) blocks but removes only the prints inside
Preserves app_logger.dart as it's a logging utility
"""

import os
import re
from pathlib import Path

def remove_prints_from_file(file_path):
    """Remove print statements from a single file"""

    # Skip app_logger.dart - it's a logging utility
    if 'app_logger.dart' in str(file_path):
        print(f"⏭️  Skipping {file_path} (logging utility)")
        return 0

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content
        removed_count = 0

        # Pattern 1: Remove standalone print() statements
        # Matches: print('...');
        pattern1 = r"(\s*)print\([^)]*\);"
        matches1 = re.findall(pattern1, content)
        removed_count += len(matches1)
        content = re.sub(pattern1, r"\1// Debug logging removed", content)

        # Pattern 2: Remove debugPrint() statements
        pattern2 = r"(\s*)debugPrint\([^)]*\);"
        matches2 = re.findall(pattern2, content)
        removed_count += len(matches2)
        content = re.sub(pattern2, r"\1// Debug logging removed", content)

        # Pattern 3: Remove multi-line print statements
        # Matches: print('...'
        #               '...');
        pattern3 = r"(\s*)print\([^;]*\);"
        content = re.sub(pattern3, r"\1// Debug logging removed", content, flags=re.MULTILINE | re.DOTALL)

        # Pattern 4: Remove multi-line debugPrint statements
        pattern4 = r"(\s*)debugPrint\([^;]*\);"
        content = re.sub(pattern4, r"\1// Debug logging removed", content, flags=re.MULTILINE | re.DOTALL)

        # Only write if content changed
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ {file_path}: Removed ~{removed_count} print statements")
            return removed_count
        else:
            print(f"⏭️  {file_path}: No prints found")
            return 0

    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return 0

def main():
    # Path to lib/core folder
    core_path = Path("ruwaq_jawi/lib/core")

    if not core_path.exists():
        print(f"❌ Path not found: {core_path}")
        return

    print("🚀 Starting print statement removal from lib/core")
    print("=" * 60)

    total_removed = 0
    files_processed = 0

    # Process all .dart files in lib/core
    for dart_file in core_path.rglob("*.dart"):
        removed = remove_prints_from_file(dart_file)
        total_removed += removed
        files_processed += 1

    print("=" * 60)
    print(f"✅ Complete! Processed {files_processed} files")
    print(f"📊 Total print statements removed: ~{total_removed}")
    print("")
    print("Run this to verify:")
    print("  grep -r 'print(' ruwaq_jawi/lib/core --include='*.dart' | wc -l")

if __name__ == "__main__":
    main()
