import { createHash } from 'node:crypto';
import { chmodSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const artifacts = JSON.parse(readFileSync(join(root, 'catalog', 'tool-artifacts.json')));
const tools = join(root, '.tools');
mkdirSync(tools, { recursive: true });
const windows = process.platform === 'win32';

async function download(spec, destination) {
  const response = await fetch(spec.url, { signal: AbortSignal.timeout(180_000) });
  if (!response.ok) throw new Error(`Tool download failed: HTTP ${response.status} (${spec.url})`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (createHash('sha256').update(bytes).digest('hex') !== spec.sha256) {
    throw new Error(`Checksum mismatch: ${spec.url}`);
  }
  writeFileSync(destination, bytes);
}

try {
  const bicepSpec = artifacts.bicep[`${process.platform}-${process.arch}`];
  const terraformSpec = artifacts.terraform[`${process.platform}-${windows ? 'x64' : process.arch}`];
  if (!bicepSpec || !terraformSpec) throw new Error('This tool installer supports Linux x64 and Windows x64/ARM64 only.');
  const bicep = join(tools, windows ? 'bicep.exe' : 'bicep');
  if (!existsSync(bicep) || createHash('sha256').update(readFileSync(bicep)).digest('hex') !== bicepSpec.sha256) {
    await download(bicepSpec, bicep);
  }
  if (!windows) chmodSync(bicep, 0o755);
  const terraform = join(tools, windows ? 'terraform.exe' : 'terraform');
  const stamp = join(tools, 'terraform.archive.sha256');
  if (!existsSync(terraform) || !existsSync(stamp) || readFileSync(stamp, 'utf8') !== terraformSpec.sha256) {
    const archive = join(tools, 'terraform.zip');
    await download(terraformSpec, archive);
    if (windows) {
      const quote = (value) => `'${value.replaceAll("'", "''")}'`;
      execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command',
        `Expand-Archive -LiteralPath ${quote(archive)} -DestinationPath ${quote(tools)} -Force`], { stdio: 'inherit' });
    } else {
      execFileSync('unzip', ['-o', '-q', archive, '-d', tools], { stdio: 'inherit' });
    }
    writeFileSync(stamp, terraformSpec.sha256);
    rmSync(archive);
  }
  console.log(execFileSync(bicep, ['--version'], { encoding: 'utf8' }).trim());
  const version = JSON.parse(execFileSync(terraform, ['version', '-json'], { encoding: 'utf8' })).terraform_version;
  if (version !== '1.13.5') throw new Error(`Expected Terraform 1.13.5, found ${version}`);
  console.log(`Terraform ${version}; tools installed in ${tools}`);
} catch (error) {
  console.error(`Toolchain setup failed: ${error.message}`);
  process.exitCode = 1;
}
