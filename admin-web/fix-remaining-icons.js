const fs = require('fs');
const path = require('path');

// Function to process a single file
function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Replace any remaining lucide-react imports with phosphor-icons/react
  if (content.includes('lucide-react')) {
    content = content.replace(/from ['"]lucide-react['"]/g, "from '@phosphor-icons/react'");
    hasChanges = true;
    console.log(`Fixed lucide-react import in ${filePath}`);
  }

  // Fix specific icon mappings that might have been missed
  const iconMappings = {
    'ArrowLeft': 'ArrowLeft',
    'Save': 'FloppyDisk',
    'Upload': 'UploadSimple',
    'AlertCircle': 'WarningCircle',
    'FileUp': 'UploadSimple',
    'Folder': 'Folder',
    'Plus': 'Plus',
    'Edit': 'Pencil',
    'Trash': 'Trash',
    'X': 'X',
    'Search': 'MagnifyingGlass',
    'Filter': 'Funnel',
    'Calendar': 'Calendar',
    'User': 'User',
    'Users': 'Users',
    'BookOpen': 'BookOpen',
    'Video': 'Video',
    'Image': 'Image',
    'FileText': 'FileText'
  };

  // Apply mappings
  Object.entries(iconMappings).forEach(([lucideIcon, phosphorIcon]) => {
    const regex = new RegExp(`\\b${lucideIcon}\\b(?!Icon)`, 'g');
    if (content.includes('@phosphor-icons/react') && regex.test(content)) {
      content = content.replace(regex, `${phosphorIcon}Icon`);
      hasChanges = true;
      console.log(`Updated ${lucideIcon} to ${phosphorIcon}Icon in ${filePath}`);
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
  console.log('🔧 Fixing remaining icon issues...');
  processDirectory(srcDir);
  console.log('✅ Remaining icon fixes complete!');
} else {
  console.log('❌ src directory not found');
}