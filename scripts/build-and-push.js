import { execSync } from 'node:child_process';

function run(cmd, env = process.env) {
  execSync(cmd, { stdio: 'inherit', env });
}

// 1. Build production bundle
run('npx vite build', { ...process.env, NODE_ENV: 'production' });

// 2. Stage & commit if there are any changes
const status = execSync('git status --porcelain', { encoding: 'utf8' }).trim();
if (status) {
  run('git add -A');
  run('git commit -m "chore: build and push"');
}

// 3. Push to GitHub
run('git push origin main');
