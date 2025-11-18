const fs = require('fs');
const path = require('path');

// Revert to lucide-react imports temporarily to get build working
const revertMappings = {
  "from '@phosphor-icons/react'": "from 'lucide-react'",

  // Revert icon names back to lucide
  'ActivityLogo,': 'Activity,',
  'ActivityLogo': 'Activity',
  'Warning,': 'AlertTriangle,',
  'Warning': 'AlertTriangle',
  'Pencil,': 'Edit,',
  'Pencil': 'Edit',
  'SquaresFour,': 'LayoutDashboard,',
  'SquaresFour': 'LayoutDashboard',
  'Envelope,': 'Mail,',
  'Envelope': 'Mail',
  'DotsThree,': 'MoreHorizontal,',
  'DotsThree': 'MoreHorizontal',
  'FloppyDisk,': 'Save,',
  'FloppyDisk': 'Save',
  'Gear,': 'Settings,',
  'Gear': 'Settings',
  'Trash,': 'Trash2,',
  'Trash': 'Trash2'
};

// Function to process a single file
function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Apply revert mappings
  Object.entries(revertMappings).forEach(([phosphor, lucide]) => {
    const regex = new RegExp(phosphor.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');

    if (content.match(regex)) {
      content = content.replace(regex, lucide);
      hasChanges = true;
      console.log(`Reverted ${phosphor} -> ${lucide} in ${filePath}`);
    }
  });

  if (hasChanges) {
    fs.writeFileSync(filePath, content);
    console.log(`✅ Reverted: ${filePath}`);
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
  console.log('🔄 Reverting to lucide-react icons temporarily...');
  processDirectory(srcDir);
  console.log('✅ Revert complete!');
} else {
  console.log('❌ src directory not found');
}