const fs = require('fs');
const path = require('path');

// Correct icon mappings based on actual Phosphor icons available
const iconMappings = {
  // Remove remaining lucide-react imports
  "from 'lucide-react'": "from '@phosphor-icons/react'",
  'import {': 'import {',

  // Icon mappings to correct Phosphor icon names
  'Activity,': 'ActivityLogo,',
  'Activity': 'ActivityLogo',
  'AlertTriangle,': 'Warning,',
  'AlertTriangle': 'Warning',
  'Edit,': 'Pencil,',
  'Edit': 'Pencil',
  'ExclamationTriangleIcon,': 'Warning,',
  'ExclamationTriangleIcon': 'Warning',
  'LayoutDashboard,': 'ChartLine,',
  'LayoutDashboard': 'ChartLine',
  'Mail,': 'Envelope,',
  'Mail': 'Envelope',
  'MoreHorizontal,': 'DotsThree,',
  'MoreHorizontal': 'DotsThree',
  'Save,': 'FloppyDisk,',
  'Save': 'FloppyDisk',
  'Settings,': 'Gear,',
  'Settings': 'Gear',
  'Trash2,': 'Trash,',
  'Trash2': 'Trash',
  'TrendingUp,': 'TrendingUp,',
  'TrendingUp': 'TrendingUp',
  'TrendingDown,': 'TrendingDown,',
  'TrendingDown': 'TrendingDown'
};

// Function to process a single file
function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Apply icon mappings
  Object.entries(iconMappings).forEach(([incorrect, correct]) => {
    const regex = new RegExp(incorrect.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');

    if (content.match(regex)) {
      content = content.replace(regex, correct);
      hasChanges = true;
      console.log(`Updated ${incorrect} -> ${correct} in ${filePath}`);
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
  console.log('🔧 Fixing icon imports...');
  processDirectory(srcDir);
  console.log('✅ Icon fix complete!');
} else {
  console.log('❌ src directory not found');
}