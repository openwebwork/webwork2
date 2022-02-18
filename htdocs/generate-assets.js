#!/usr/bin/env node

/* eslint-env node */

const yargs = require('yargs');
const chokidar = require('chokidar');
const path = require('path');
const { minify } = require('terser');
const fs = require('fs');
const crypto = require('crypto');
const sass = require('sass');
const autoprefixer = require('autoprefixer');
const postcss = require('postcss');
const thirdPartyAssets = require('./third-party-assets.json');

const argv = yargs
	.usage('$0 Options').version(false).alias('help', 'h').wrap(100)
	.option('useCDN', {
		alias: 'c',
		description: 'Use third party assets from a CDN rather than serving them locally.',
		type: 'boolean'
	})
	.option('enable-sourcemaps', {
		alias: 's',
		description: 'Generate source maps. (Not for use in production!)',
		type: 'boolean'
	})
	.option('watch-files', {
		alias: 'w',
		description: 'Continue to watch files for changes. (Developer tool)',
		type: 'boolean'
	})
	.option('clean', {
		alias: 'd',
		description: 'Delete all generated files.',
		type: 'boolean'
	})
	.argv;

const assetFile = path.resolve(__dirname, 'static-assets.json');
const assets = {};

const cleanDir = (dir) => {
	for (const file of fs.readdirSync(dir, { withFileTypes: true })) {
		if (file.isDirectory()) {
			cleanDir(path.resolve(dir, file.name));
		} else {
			if (/.[a-z0-9]{8}.min.(css|js)$/.test(file.name)) {
				const fullPath = path.resolve(dir, file.name);
				console.log(`Removing ${fullPath} from previous build.`);
				fs.unlinkSync(fullPath);
			}
		}
	}
}

// The is set to true after all files are processed for the first time.
let ready = false;

const processFile = async (file, _details) => {
	if (file) {
		const baseName = path.basename(file);

		if (/(?<!\.min)\.js$/.test(baseName)) {
			// Process javascript
			if (!ready) console.log(`Proccessing ${file}`);

			const filePath = path.resolve(__dirname, file);

			const contents = fs.readFileSync(filePath, 'utf8');
			const result = await minify({ [baseName]: contents }, { sourceMap: argv.enableSourcemaps });

			const minJS = result.code + (
				argv.enableSourcemaps && result.map
				? `//# sourceMappingURL=data:application/json;charset=utf-8;base64,${
							Buffer.from(result.map).toString('base64')}`
				: ''
			);

			const contentHash = crypto.createHash('sha256');
			contentHash.update(minJS);

			const newVersion = file.replace(/\.js$/, `.${contentHash.digest('hex').substring(0, 8)}.min.js`);
			fs.writeFileSync(path.resolve(__dirname, newVersion), minJS);

			// Remove a previous version if the content hash is different.
			if (assets[file] && assets[file] !== newVersion) {
				console.log(`Updated ${file}.`);
				const oldFileFullPath = path.resolve(__dirname, assets[file]);
				if (fs.existsSync(oldFileFullPath)) fs.unlinkSync(oldFileFullPath);
			} else if (ready && !assets[file]) {
				console.log(`Processed ${file}.`);
			}

			assets[file] = newVersion;
		} else if (/^(?!_).*(?<!\.min)\.s?css$/.test(baseName)) {
			// Process scss or css.
			if (!ready) console.log(`Proccessing ${file}`);

			const filePath = path.resolve(__dirname, file);

			// This works for both sass/scss files and css files.  For css files it just compresses.
			const result = sass.compile(filePath, { style: 'compressed', sourceMap: argv.enableSourcemaps });
			if (result.sourceMap) result.sourceMap.sources = [ baseName ];

			// Pass the compiled css through the autoprefixer.
			// This is really only needed for the bootstrap.css files, but doesn't hurt for the rest.
			const prefixedResult = await postcss([autoprefixer]).process(result.css, { from: baseName });

			const minCSS = prefixedResult.css + (
				argv.enableSourcemaps && result.sourceMap
				? `/*# sourceMappingURL=data:application/json;charset=utf-8;base64,${
							Buffer.from(JSON.stringify(result.sourceMap)).toString('base64')}*/`
				: ''
			);

			const contentHash = crypto.createHash('sha256');
			contentHash.update(minCSS);

			const newVersion = file.replace(/\.s?css$/, `.${contentHash.digest('hex').substring(0, 8)}.min.css`);
			fs.writeFileSync(path.resolve(__dirname, newVersion), minCSS);

			const assetName = file.replace(/\.scss$/, '.css');

			// Remove a previous version if the content hash is different.
			if (assets[assetName] && assets[assetName] !== newVersion) {
				console.log(`Updated ${file}.`);
				const oldFileFullPath = path.resolve(__dirname, assets[assetName]);
				if (fs.existsSync(oldFileFullPath)) fs.unlinkSync(oldFileFullPath);
			} else if (ready && !assets[file]) {
				console.log(`Processed ${file}.`);
			}

			assets[assetName] = newVersion;
		} else {
			return;
		}
	} else {
		if (argv.watchFiles)
			console.log('Watches established, and initial build complete.\n'
				+ 'Press Control-C to stop.');
		ready = true;
	}

	if (ready) fs.writeFileSync(assetFile, JSON.stringify(assets));
};

const themesDir = path.resolve(__dirname, 'themes');
const jsDir = path.resolve(__dirname, 'js/apps');

// Remove generated files from previous builds.
cleanDir(themesDir);
cleanDir(jsDir);

if (argv.clean) process.exit();

// Add a math4-overrides.css and math4-overrides.js file in each theme directory if they do not exist already.
for (const file of fs.readdirSync(themesDir, { withFileTypes: true })) {
	if (!file.isDirectory()) continue;
	if (!fs.existsSync(path.resolve(themesDir, file.name, 'math4-overrides.js')))
		fs.closeSync(fs.openSync(path.resolve(themesDir, file.name, 'math4-overrides.js'), 'w'));
	if (!fs.existsSync(path.resolve(themesDir, file.name, 'math4-overrides.css'))
		&& !fs.existsSync(path.resolve(themesDir, file.name, 'math4-overrides.scss')))
		fs.closeSync(fs.openSync(path.resolve(themesDir, file.name, 'math4-overrides.css'), 'w'));
}

// Add third party assets to the assets list.
if (argv.useCDN) {
	// If using a cdn, the values are the cdn location for the file.
	console.log('Adding third party assets from CDN.');
	Object.assign(assets, thirdPartyAssets);
} else {
	// If not using a cdn, the values are the same as the request file.
	console.log('Adding third party assets served locally from htdocs/node_modules.');
	Object.assign(assets,
		Object.entries(thirdPartyAssets).reduce(
			(accumulator, [file]) => { accumulator[file] = file; return accumulator; }, {}));
}

// Set up the watcher.
if (argv.watchFiles) console.log('Establishing watches and performing initial build.');
chokidar.watch(['js/apps', 'themes'], {
	ignored: /\.min\.(js|css)$/,
	cwd: __dirname, // Make sure all paths are given relative to the htdocs directory.
	usePolling: true, // Needed to get changes to symlinks.
	interval: 500,
	awaitWriteFinish: { stabilityThreshold: 500 },
	persistent: argv.watchFiles ? true : false
})
	.on('add', processFile).on('change', processFile).on('ready', processFile)
	.on('unlink', (file) => {
		// If a file is deleted, then also delete the corresponding generated file.
		if (assets[file]) {
			console.log(`Deleting minified file for ${file}.`);
			fs.unlinkSync(path.resolve(__dirname, assets[file]));
			delete assets[file];
		}
	})
	.on('error', (error) => console.log(error));
