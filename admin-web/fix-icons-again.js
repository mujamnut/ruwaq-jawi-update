const fs = require('fs');
const path = require('path');

// Define the correct icon mappings from Lucide to Phosphor
const iconMappings = {
  // Activity → ActivityIcon
  'Activity': 'Activity',
  'AlertTriangle': 'Warning',
  'ArrowClockwise': 'ArrowClockwise',
  'BarChart': 'BarChart',
  'Bell': 'Bell',
  'BookOpen': 'BookOpen',
  'Calendar': 'Calendar',
  'CheckCircle': 'CheckCircle',
  'ChevronDown': 'CaretDown',
  'ChevronLeft': 'CaretLeft',
  'ChevronRight': 'CaretRight',
  'ChevronUp': 'CaretUp',
  'Clock': 'Clock',
  'Download': 'Download',
  'Edit': 'Pencil',
  'ExclamationTriangleIcon': 'Warning',
  'Eye': 'Eye',
  'FileText': 'FileText',
  'Filter': 'Funnel',
  'Folder': 'Folder',
  'Gauge': 'Gauge',
  'Grid': 'Grid',
  'Home': 'House',
  'LayoutDashboard': 'Layout',
  'Lightning': 'Lightning',
  'Loader': 'Spinner',
  'LogOut': 'SignOut',
  'Mail': 'Envelope',
  'Menu': 'List',
  'MoreHorizontal': 'DotsThree',
  'MoreVertical': 'DotsThreeVertical',
  'Pause': 'Pause',
  'Photo': 'Image',
  'Play': 'Play',
  'Plus': 'Plus',
  'PlusCircle': 'PlusCircle',
  'RefreshCw': 'ArrowClockwise',
  'RotateCcw': 'ArrowCounterClockwise',
  'Save': 'FloppyDisk',
  'Search': 'MagnifyingGlass',
  'Settings': 'Gear',
  'Shield': 'Shield',
  'Square': 'Square',
  'Star': 'Star',
  'Target': 'Target',
  'Trash': 'Trash',
  'Trash2': 'TrashSimple',
  'TrendingDown': 'TrendDown',
  'TrendingUp': 'TrendUp',
  'Upload': 'UploadSimple',
  'User': 'User',
  'UserCheck': 'UserCheck',
  'UserCircle': 'UserCircle',
  'Users': 'Users',
  'Video': 'Video',
  'View': 'Eye',
  'Watch': 'Watch',
  'X': 'X',
  'XCircle': 'XCircle',
  'Youtube': 'YoutubeLogo'
};

// Function to process a single file
function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Replace imports
  Object.entries(iconMappings).forEach(([lucideIcon, phosphorIcon]) => {
    const importRegex = new RegExp(`from ["']@phosphor-icons/react["']\\s*;?([\\s\\S]*?)(export\\s*{[^}]*})?`, 'g');

    // Check if file imports from @phosphor-icons/react
    if (content.includes('@phosphor-icons/react')) {
      // Replace icon names in imports
      const oldImportPattern = new RegExp(`\\b${lucideIcon}\\b`, 'g');
      const newImportPattern = `${phosphorIcon}`;

      if (oldImportPattern.test(content)) {
        content = content.replace(oldImportPattern, newImportPattern);
        hasChanges = true;
        console.log(`Updated ${lucideIcon} to ${phosphorIcon} in ${filePath}`);
      }
    }
  });

  // Fix any remaining lucide-react imports
  content = content.replace(/from ["']lucide-react["']/g, "from '@phosphor-icons/react'");

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
  console.log('🔧 Fixing Phosphor icon imports...');
  processDirectory(srcDir);
  console.log('✅ Icon import fixing complete!');
} else {
  console.log('❌ src directory not found');
}