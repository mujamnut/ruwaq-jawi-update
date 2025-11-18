const fs = require('fs');
const path = require('path');

// Define the correct mappings for problematic icons
const finalMappings = {
  'Activity': 'Activity',
  'ActivityIcon': 'Activity',
  'ArrowLeftIcon': 'ArrowLeft',
  'Ban': 'Prohibit',
  'BanIcon': 'Prohibit',
  'BookOpenIcon': 'BookOpen',
  'CalendarIcon': 'Calendar',
  'CheckCircleIcon': 'CheckCircle',
  'ClockIcon': 'Clock',
  'DownloadIcon': 'Download',
  'EditIcon': 'Pencil',
  'EnvelopeIcon': 'Envelope',
  'EyeIcon': 'Eye',
  'FileTextIcon': 'FileText',
  'FilterIcon': 'Funnel',
  'FloppyDiskIcon': 'FloppyDisk',
  'FolderIcon': 'Folder',
  'FunnelIcon': 'Funnel',
  'GearIcon': 'Gear',
  'Icon': '', // Remove Icon suffix when it's wrong
  'ImageIcon': 'Image',
  'LightningIcon': 'Lightning',
  'ListIcon': 'List',
  'MagnifyingGlassIcon': 'MagnifyingGlass',
  'Mail': 'Envelope',
  'MailIcon': 'Envelope',
  'MenuIcon': 'List',
  'MoreHorizontal': 'DotsThree',
  'PencilIcon': 'Pencil',
  'Photo': 'Image',
  'PlayIcon': 'Play',
  'PlusIcon': 'Plus',
  'Prohibit': 'Prohibit',
  'ProhibitIcon': 'Prohibit',
  'Save': 'FloppyDisk',
  'Search': 'MagnifyingGlass',
  'SettingsIcon': 'Gear',
  'ShieldIcon': 'Shield',
  'SpinnerIcon': 'Spinner',
  'SquareIcon': 'Square',
  'StarIcon': 'Star',
  'TargetIcon': 'Target',
  'Trash': 'Trash',
  'Trash2': 'TrashSimple',
  'TrashIcon': 'Trash',
  'TrashSimpleIcon': 'TrashSimple',
  'TrendDownIcon': 'TrendDown',
  'TrendUpIcon': 'TrendUp',
  'UploadIcon': 'UploadSimple',
  'UploadSimpleIcon': 'UploadSimple',
  'UserCheckIcon': 'UserCheck',
  'UserCircleIcon': 'UserCircle',
  'UserIcon': 'User',
  'UsersIcon': 'Users',
  'VideoIcon': 'Video',
  'WarningCircleIcon': 'WarningCircle',
  'WarningIcon': 'Warning',
  'WatchIcon': 'Watch',
  'XIcon': 'X',
  'XCircleIcon': 'XCircle',
  'YoutubeLogoIcon': 'YoutubeLogo'
};

// Function to process a single file
function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Only process files that import from @phosphor-icons/react
  if (!content.includes('@phosphor-icons/react')) return;

  // Apply mappings for problematic icons
  Object.entries(finalMappings).forEach(([wrongIcon, correctIcon]) => {
    if (!correctIcon) return; // Skip empty mappings

    // Replace imports and usage
    const regex = new RegExp(`\\b${wrongIcon}\\b`, 'g');
    if (content.match(regex)) {
      content = content.replace(regex, correctIcon);
      hasChanges = true;
      console.log(`Fixed ${wrongIcon} -> ${correctIcon} in ${filePath}`);
    }
  });

  // Fix any remaining inconsistent Icon suffixes
  // Icons that should NOT have Icon suffix
  const noSuffixIcons = [
    'Activity', 'ArrowLeft', 'ArrowCounterClockwise', 'ArrowClockwise', 'BarChart',
    'Bell', 'BookOpen', 'Calendar', 'CaretDown', 'CaretLeft', 'CaretRight', 'CaretUp',
    'CheckCircle', 'Clock', 'Download', 'DotsThree', 'DotsThreeVertical', 'Envelope',
    'Eye', 'FileText', 'Filter', 'Folder', 'FloppyDisk', 'Funnel', 'Gear', 'Grid',
    'House', 'Image', 'Layout', 'Lightning', 'List', 'MagnifyingGlass', 'Pause',
    'Pencil', 'Photo', 'Play', 'Plus', 'PlusCircle', 'Prohibit', 'SignOut', 'Spinner',
    'Square', 'Star', 'Target', 'Trash', 'TrashSimple', 'TrendDown', 'TrendUp',
    'UploadSimple', 'User', 'UserCheck', 'UserCircle', 'Users', 'Video', 'Warning',
    'WarningCircle', 'Watch', 'X', 'XCircle', 'YoutubeLogo'
  ];

  noSuffixIcons.forEach(iconName => {
    // Remove Icon suffix if it shouldn't be there
    const wrongSuffixRegex = new RegExp(`\\b${iconName}Icon\\b`, 'g');
    if (content.match(wrongSuffixRegex)) {
      content = content.replace(wrongSuffixRegex, iconName);
      hasChanges = true;
      console.log(`Removed Icon suffix from ${iconName}Icon in ${filePath}`);
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
  console.log('🔧 Final icon fix...');
  processDirectory(srcDir);
  console.log('✅ Final icon fix complete!');
} else {
  console.log('❌ src directory not found');
}