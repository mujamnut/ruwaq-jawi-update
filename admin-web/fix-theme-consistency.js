const fs = require('fs');
const path = require('path');

// Theme mapping from dark to light
const themeMappings = {
  // Background colors
  'bg-slate-950': 'bg-white',
  'bg-slate-900': 'bg-white',
  'bg-slate-800': 'bg-gray-100',
  'bg-slate-700': 'bg-gray-200',
  'bg-slate-600': 'bg-gray-300',
  'bg-slate-900/90': 'bg-white/90',
  'bg-slate-900/80': 'bg-white/80',
  'bg-slate-900/70': 'bg-white/70',
  'bg-slate-900/60': 'bg-white/60',
  'bg-slate-900/50': 'bg-white/50',
  'bg-slate-800/90': 'bg-gray-100/90',
  'bg-slate-800/80': 'bg-gray-100/80',
  'bg-slate-800/70': 'bg-gray-100/70',
  'bg-slate-700/50': 'bg-gray-200/50',
  'bg-slate-900/50': 'bg-white/50',

  // Text colors
  'text-slate-100': 'text-gray-900',
  'text-slate-200': 'text-gray-800',
  'text-slate-300': 'text-gray-700',
  'text-slate-400': 'text-gray-600',
  'text-slate-500': 'text-gray-500',
  'text-slate-600': 'text-gray-400',
  'text-slate-700': 'text-gray-300',
  'text-slate-800': 'text-gray-200',
  'text-slate-900': 'text-gray-100',

  // Border colors
  'border-slate-700': 'border-gray-300',
  'border-slate-600': 'border-gray-400',
  'border-slate-500': 'border-gray-500',
  'border-slate-800': 'border-gray-200',
  'border-slate-700/80': 'border-gray-300/80',
  'border-slate-700/50': 'border-gray-300/50',
  'border-slate-700/40': 'border-gray-300/40',
  'border-slate-700/60': 'border-gray-300/60',

  // Placeholder colors
  'placeholder:text-slate-500': 'placeholder:text-gray-500',
  'placeholder:text-slate-400': 'placeholder:text-gray-400',

  // Hover states
  'hover:bg-slate-800': 'hover:bg-gray-100',
  'hover:bg-slate-800/90': 'hover:bg-gray-100/90',
  'hover:bg-slate-700': 'hover:bg-gray-200',

  // Focus states
  'focus:border-blue-500/50': 'focus:border-blue-500/50', // Keep this the same
};

// Function to process a single file
function processFile(filePath) {
  if (!fs.existsSync(filePath)) return;

  let content = fs.readFileSync(filePath, 'utf8');
  let hasChanges = false;

  // Apply theme mappings
  Object.entries(themeMappings).forEach(([darkTheme, lightTheme]) => {
    const regex = new RegExp(darkTheme.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');

    if (content.match(regex)) {
      content = content.replace(regex, lightTheme);
      hasChanges = true;
      console.log(`Updated ${darkTheme} -> ${lightTheme} in ${filePath}`);
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
  console.log('🔧 Fixing theme consistency (dark to light)...');
  processDirectory(srcDir);
  console.log('✅ Theme consistency fix complete!');
} else {
  console.log('❌ src directory not found');
}