#!/usr/bin/env node
/**
 * Remove all print() and debugPrint() statements from lib/core folder
 * Preserves if (kDebugMode) blocks but removes only the prints inside
 * Skips app_logger.dart as it's a logging utility
 */

const fs = require('fs');
const path = require('path');

function getAllDartFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      getAllDartFiles(filePath, fileList);
    } else if (file.endsWith('.dart')) {
      fileList.push(filePath);
    }
  });

  return fileList;
}

function removePrintStatements(content) {
  let modified = content;
  let count = 0;

  // Pattern 1: Match simple print statements on single lines
  // print('...');  or  print("...");
  const pattern1 = /(\s*)print\([^;]*?\);/g;
  const matches1 = modified.match(pattern1) || [];
  count += matches1.length;
  modified = modified.replace(pattern1, '$1// Debug logging removed');

  // Pattern 2: Match debugPrint statements
  const pattern2 = /(\s*)debugPrint\([^;]*?\);/g;
  const matches2 = modified.match(pattern2) || [];
  count += matches2.length;
  modified = modified.replace(pattern2, '$1// Debug logging removed');

  // Pattern 3: Match multi-line print statements (more aggressive)
  // This handles cases where print spans multiple lines
  const pattern3 = /(\s*)print\([^)]*\n[^)]*\);/g;
  modified = modified.replace(pattern3, '$1// Debug logging removed');

  // Pattern 4: Match multi-line debugPrint statements
  const pattern4 = /(\s*)debugPrint\([^)]*\n[^)]*\);/g;
  modified = modified.replace(pattern4, '$1// Debug logging removed');

  return { modified, count };
}

function processFile(filePath) {
  // Skip app_logger.dart - it's a logging utility
  if (filePath.includes('app_logger.dart')) {
    console.log(`⏭️  Skipping ${filePath} (logging utility)`);
    return 0;
  }

  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const { modified, count } = removePrintStatements(content);

    if (modified !== content) {
      fs.writeFileSync(filePath, modified, 'utf8');
      console.log(`✅ ${filePath}: Removed ~${count} print statements`);
      return count;
    } else {
      console.log(`⏭️  ${filePath}: No prints found`);
      return 0;
    }
  } catch (error) {
    console.error(`❌ Error processing ${filePath}:`, error.message);
    return 0;
  }
}

function main() {
  const corePath = path.join(__dirname, 'ruwaq_jawi', 'lib', 'core');

  if (!fs.existsSync(corePath)) {
    console.error(`❌ Path not found: ${corePath}`);
    process.exit(1);
  }

  console.log('🚀 Starting print statement removal from lib/core');
  console.log('='.repeat(60));

  const dartFiles = getAllDartFiles(corePath);
  let totalRemoved = 0;
  let filesProcessed = 0;

  dartFiles.forEach(file => {
    const removed = processFile(file);
    totalRemoved += removed;
    filesProcessed++;
  });

  console.log('='.repeat(60));
  console.log(`✅ Complete! Processed ${filesProcessed} files`);
  console.log(`📊 Total print statements removed: ~${totalRemoved}`);
  console.log('');
  console.log('Run this to verify:');
  console.log('  grep -r "print(" ruwaq_jawi/lib/core --include="*.dart" | wc -l');
}

main();
