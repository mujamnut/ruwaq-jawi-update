const fs = require('fs');
const path = require('path');

// Icons that DO need the Icon suffix in Phosphor
const needsIconSuffix = [
  'Activity', 'ArrowLeft', 'ArrowCounterClockwise', 'ArrowClockwise', 'BarChart',
  'Bell', 'BookOpen', 'Calendar', 'CaretDown', 'CaretLeft', 'CaretRight', 'CaretUp',
  'CheckCircle', 'Clock', 'CreditCard', 'CurrencyDollar', 'Download', 'DotsThree',
  'DotsThreeVertical', 'Envelope', 'Eye', 'EyeClosed', 'FileText', 'Filter',
  'Folder', 'FloppyDisk', 'Funnel', 'Gear', 'Grid', 'House', 'Image', 'Info',
  'Layout', 'Lightning', 'List', 'MagnifyingGlass', 'Pause', 'Pencil', 'Photo',
  'Play', 'Plus', 'PlusCircle', 'Prohibit', 'SignOut', 'Spinner', 'Square',
  'Star', 'Tag', 'Target', 'Trash', 'TrashSimple', 'TrendDown', 'TrendUp',
  'UploadSimple', 'User', 'UserCheck', 'UserCircle', 'Users', 'Video',
  'Warning', 'WarningCircle', 'Watch', 'X', 'XCircle', 'YoutubeLogo'
];

// Function to process a single file
function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Only process files that import from @phosphor-icons/react
  if (!content.includes('@phosphor-icons/react')) return;

  // Add Icon suffix to icons that need it
  needsIconSuffix.forEach(iconName => {
    // Look for icon usage without Icon suffix
    const regex = new RegExp(`\\b${iconName}\\b(?!Icon)`, 'g');

    // Make sure it's not already in an import statement with Icon suffix
    if (content.includes(iconName) && !content.includes(`${iconName}Icon`) && regex.test(content)) {
      // Add Icon suffix
      content = content.replace(regex, `${iconName}Icon`);
      hasChanges = true;
      console.log(`Added Icon suffix to ${iconName} in ${filePath}`);
    }
  });

  if (hasChanges) {
    fs.writeFileSync(filePath, content);
    console.log(`✅ Updated: ${filePath}`);
  }
}

// Function to recursively process all TypeScript/JavaScript files
function processDirectory(dir) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory() && !file.startsWith('.') && file !== 'node_modules') {
      processDirectory(filePath);
    } else if (stat.isFile() && (file.endsWith('.tsx') || file.endsWith('.ts') || file.endsWith('.jsx') || file.endsWith('.js'))) {
      processFile(filePath);
    }
  });
}

// Process the src directory
const srcDir = path.join(process.cwd(), 'src');
if (fs.existsSync(srcDir)) {
  console.log('🔧 Adding Icon suffix to all Phosphor icons...');
  processDirectory(srcDir);
  console.log('✅ Icon suffix addition complete!');
} else {
  console.log('❌ src directory not found');
}