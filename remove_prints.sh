#!/bin/bash
# Remove all print() and debugPrint() statements from lib/core folder
# Keeps if (kDebugMode) blocks but removes only the prints inside

echo "🚀 Starting print statement removal from lib/core"
echo "============================================================"

# Counter
total_removed=0
files_processed=0

# Find all dart files in lib/core except app_logger.dart
find ruwaq_jawi/lib/core -name "*.dart" -type f ! -name "app_logger.dart" | while read -r file; do
    echo "Processing: $file"

    # Create backup
    cp "$file" "$file.bak"

    # Remove print statements using sed
    # Pattern 1: Remove print(...);
    sed -i "s/print([^;]*);/\/\/ Debug logging removed/g" "$file"

    # Pattern 2: Remove debugPrint(...);
    sed -i "s/debugPrint([^;]*);/\/\/ Debug logging removed/g" "$file"

    # Count differences
    diff_count=$(diff -u "$file.bak" "$file" | grep "^-.*print(" | wc -l)

    if [ "$diff_count" -gt 0 ]; then
        echo "  ✅ Removed ~$diff_count print statements"
        total_removed=$((total_removed + diff_count))
    else
        echo "  ⏭️  No prints found"
    fi

    # Remove backup
    rm "$file.bak"

    files_processed=$((files_processed + 1))
done

echo "============================================================"
echo "✅ Complete! Processed $files_processed files"
echo "📊 Total print statements removed: ~$total_removed"
echo ""
echo "Run this to verify:"
echo "  grep -r 'print(' ruwaq_jawi/lib/core --include='*.dart' | wc -l"
