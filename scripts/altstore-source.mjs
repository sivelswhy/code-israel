// Adds a version to the AltStore source (altstore.json, at the root of the repository) so that AltStore offers the update.
// Usage: node scripts/altstore-source.mjs <version> <build> <ipaPath> <downloadURL> [notes]
import { readFileSync, statSync, writeFileSync } from 'node:fs'

const [, , version, build, ipa, downloadURL, notes = 'Mise à jour.'] = process.argv
if (!version || !build || !ipa || !downloadURL) {
  console.error('Usage: node scripts/altstore-source.mjs <version> <build> <ipaPath> <downloadURL> [notes]')
  process.exit(1)
}

const file = new URL('../altstore.json', import.meta.url)
const source = JSON.parse(readFileSync(file, 'utf8'))
const app = source.apps[0]
const entry = {
  version,
  buildVersion: String(build),
  date: new Date().toISOString().slice(0, 10),
  localizedDescription: notes,
  downloadURL,
  size: statSync(ipa).size,
  minOSVersion: '17.0',
}
// The newest version comes first; running it again for the same version replaces the entry.
app.versions = [entry, ...app.versions.filter((v) => v.version !== version)]
writeFileSync(file, JSON.stringify(source, null, 2) + '\n')
console.log(`AltStore source: version ${version} (build ${build}), ${entry.size} bytes`)
