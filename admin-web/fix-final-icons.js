const fs = require('fs');
const path = require('path');

// Fix for specific problematic icons that don't exist in Phosphor
const finalProblematicIcons = {
  'Activity': 'Activity',
  'EyeOff': 'EyeClosed',
  'Folder': 'Folder',
  'Info': 'Info',
  'Loader2': 'Spinner',
  'Activity': 'Activity'
};

// Function to process a single file
function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Only process files that import from @phosphor-icons/react
  if (!content.includes('@phosphor-icons/react')) return;

  // Apply mappings for problematic icons
  Object.entries(finalProblematicIcons).forEach(([wrongIcon, correctIcon]) => {
    // Replace imports and usage
    const regex = new RegExp(`\\b${wrongIcon}\\b`, 'g');
    if (content.match(regex)) {
      content = content.replace(regex, correctIcon);
      hasChanges = true;
      console.log(`Fixed ${wrongIcon} -> ${correctIcon} in ${filePath}`);
    }
  });

  // Fix the BarChart conflict in performance-metrics.tsx
  if (filePath.includes('performance-metrics.tsx')) {
    // Fix the duplicate BarChart import - one should be from recharts, one from phosphor
    if (content.includes('BarChart,') && content.includes('BarChart,')) {
      // Replace the recharts BarChart import with a different name
      content = content.replace(
        /BarChart,/,
        'BarChart as RechartsBarChart,'
      );
      hasChanges = true;
      console.log(`Fixed BarChart naming conflict in ${filePath}`);
    }
  }

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
  console.log('🔧 Final problematic icon fix...');
  processDirectory(srcDir);
  console.log('✅ Final problematic icon fix complete!');
} else {
  console.log('❌ src directory not found');
}