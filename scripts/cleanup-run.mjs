import { rmSync } from 'node:fs';
import { join } from 'node:path';
import { root } from './platform.mjs';

const run = `${process.env.GITHUB_RUN_ID}_${process.env.GITHUB_RUN_ATTEMPT}`;
if (!/^\d+_\d+$/.test(run)) throw new Error('Refusing cleanup without a valid GitHub run identity.');
rmSync(join(root, '.local', run), { recursive: true, force: true });
console.log('Removed the local files for this run. Follow the runner cleanup procedure before reusing the host.');
