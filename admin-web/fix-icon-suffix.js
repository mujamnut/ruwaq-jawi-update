const fs = require('fs');
const path = require('path');

// Remove "Icon" suffix from all lucide icon imports
const iconSuffixFixes = {
  'ArrowLeftIcon': 'ArrowLeft',
  'SaveIcon': 'Save',
  'UploadSimpleIcon': 'Upload',
  'XIcon': 'X',
  'BookOpenIcon': 'BookOpen',
  'FileTextIcon': 'FileText',
  'ImageIcon': 'Image',
  'AlertTriangleCircleIcon': 'AlertTriangle',
  'CheckCircleIcon': 'CheckCircle',
  'PlusIcon': 'Plus',
  'EditIcon': 'Edit',
  'TrashIcon': 'Trash',
  'SearchIcon': 'Search',
  'FilterIcon': 'Filter',
  'DownloadIcon': 'Download',
  'EyeIcon': 'Eye',
  'ClockIcon': 'Clock',
  'TrendingUpIcon': 'TrendingUp',
  'TrendingDownIcon': 'TrendingDown',
  'UsersIcon': 'Users',
  'ActivityIcon': 'Activity',
  'BarChartIcon': 'BarChart',
  'PieChartIcon': 'PieChart',
  'SettingsIcon': 'Settings',
  'MenuIcon': 'Menu',
  'XCircleIcon': 'XCircle',
  'InfoIcon': 'Info',
  'CalendarIcon': 'Calendar',
  'MailIcon': 'Mail',
  'LockIcon': 'Lock',
  'UnlockIcon': 'Unlock',
  'HomeIcon': 'Home',
  'UserIcon': 'User',
  'LogOutIcon': 'LogOut',
  'ChevronDownIcon': 'ChevronDown',
  'ChevronUpIcon': 'ChevronUp',
  'ChevronLeftIcon': 'ChevronLeft',
  'ChevronRightIcon': 'ChevronRight'
};

// Function to process a single file
function processFile(filePath) {
  if (\!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Remove Icon suffixes
  Object.entries(iconSuffixFixes).forEach(([withSuffix, withoutSuffix]) => {
    const regex = new RegExp(\, 'g');
    if (content.match(regex)) {
      content = content.replace(regex, withoutSuffix);
      hasChanges = true;
      console.log(\);
    }
  });

  if (hasChanges) {
    fs.writeFileSync(filePath, content);
    console.log(\);
  }
}

// Function to recursively process all TypeScript/JavaScript files
function processDirectory(dir) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory() && \!file.startsWith('.') && file \!== 'node_modules') {
      processDirectory(filePath);
    } else if (stat.isFile() && (file.endsWith('.tsx') || file.endsWith('.ts') || file.endsWith('.jsx') || file.endsWith('.js'))) {
      processFile(filePath);
    }
  });
}

// Process the src directory
const srcDir = path.join(process.cwd(), 'src');
if (fs.existsSync(srcDir)) {
  console.log('🔧 Removing Icon suffixes...');
  processDirectory(srcDir);
  console.log('✅ Icon suffix fix complete\!');
} else {
  console.log('❌ src directory not found');
}
