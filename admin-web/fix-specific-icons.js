const fs = require('fs');
const path = require('path');

// Fix variable names that were incorrectly changed
const variableFixes = {
  'recentActivityLogoLogo': 'recentActivity',
  'recentActivityLogo': 'recentActivity',
  'userActivityLogo': 'userActivity',
  'displayActivityLogo': 'displayActivity'
};

// Fix only actual Phosphor icon imports that don't exist
const iconFixes = {
  'Activity': 'ActivityLogo',
  'AlertTriangle': 'Warning',
  'Edit': 'PencilSimple',
  'LayoutDashboard': 'SquaresFour',
  'Mail': 'Envelope',
  'MoreHorizontal': 'DotsThree',
  'Save': 'FloppyDisk',
  'Settings': 'Gear',
  'Trash2': 'Trash',
  'ExclamationTriangleIcon': 'Warning'
};

// Function to process a single file
function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Fix variable names first
  Object.entries(variableFixes).forEach(([incorrect, correct]) => {
    const regex = new RegExp(`\\b${incorrect}\\b`, 'g');
    if (content.match(regex)) {
      content = content.replace(regex, correct);
      hasChanges = true;
      console.log(`Fixed variable ${incorrect} -> ${correct} in ${filePath}`);
    }
  });

  // Fix icon imports
  Object.entries(iconFixes).forEach(([incorrect, correct]) => {
    const regex = new RegExp(`\\b${incorrect}\\b(?![A-Za-z0-9])`, 'g');
    if (content.match(regex)) {
      content = content.replace(regex, correct);
      hasChanges = true;
      console.log(`Fixed icon ${incorrect} -> ${correct} in ${filePath}`);
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
  console.log('🔧 Fixing specific icon issues...');
  processDirectory(srcDir);
  console.log('✅ Specific icon fix complete!');
} else {
  console.log('❌ src directory not found');
}