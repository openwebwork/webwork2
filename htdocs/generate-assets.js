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
const rtlcss = require('rtlcss');
const cssMinify = require('cssnano');

const argv = yargs
	.usage('$0 Options').version(false).alias('help', 'h').wrap(100)
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
				console.log(`\x1b[34mRemoving ${fullPath} from previous build.\x1b[0m`);
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
			if (!ready) console.log(`\x1b[32mProcessing ${file}\x1b[0m`);

			const filePath = path.resolve(__dirname, file);

			const contents = fs.readFileSync(filePath, 'utf8');

			let result;
			try {
				result = await minify({ [baseName]: contents }, { sourceMap: argv.enableSourcemaps });
			} catch (error) {
				const { name, message, line, col, pos } = error;
				console.log(`\x1b[31m${name} in ${file}:`);
				console.log(`${message} at line ${line} column ${col} position ${pos}.\x1b[0m`);
				return;
			}

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
				console.log(`\x1b[32mUpdated ${file}.\x1b[0m`);
				const oldFileFullPath = path.resolve(__dirname, assets[file]);
				if (fs.existsSync(oldFileFullPath)) fs.unlinkSync(oldFileFullPath);
			} else if (ready) {
				console.log(`\x1b[32mProcessed ${file}.\x1b[0m`);
			}

			assets[file] = newVersion;
		} else if (/^(?!_).*(?<!\.min)\.s?css$/.test(baseName)) {
			// Process scss or css.
			if (!ready) console.log(`\x1b[32mProcessing ${file}\x1b[0m`);

			const filePath = path.resolve(__dirname, file);

			// This works for both sass/scss files and css files.
			let result;
			try {
				result = sass.compile(filePath, { sourceMap: argv.enableSourcemaps });
			} catch (e) {
				console.log(`\x1b[31mIn ${file}:`);
				console.log(`${e.message}\x1b[0m`);
				return;
			}

			if (result.sourceMap) result.sourceMap.sources = [ baseName ];

			// Pass the compiled css through the autoprefixer.
			// This is really only needed for the bootstrap.css files, but doesn't hurt for the rest.
			let prefixedResult = await postcss([autoprefixer, cssMinify]).process(result.css, { from: baseName });

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
				console.log(`\x1b[32mUpdated ${file}.\x1b[0m`);
				const oldFileFullPath = path.resolve(__dirname, assets[assetName]);
				if (fs.existsSync(oldFileFullPath)) fs.unlinkSync(oldFileFullPath);
			} else if (ready) {
				console.log(`\x1b[32mProcessed ${file}.\x1b[0m`);
			}

			assets[assetName] = newVersion;

			// Pass the compiled css through rtlcss and autoprefixer to generate css for right-to-left languages.
			let rtlResult = await postcss([rtlcss, autoprefixer, cssMinify]).process(result.css, { from: baseName });

			const rtlCSS = rtlResult.css + (
				argv.enableSourcemaps && result.sourceMap
				? `/*# sourceMappingURL=data:application/json;charset=utf-8;base64,${
							Buffer.from(JSON.stringify(result.sourceMap)).toString('base64')}*/`
				: ''
			);

			const rtlContentHash = crypto.createHash('sha256');
			rtlContentHash.update(rtlCSS);

			const newRTLVersion = file.replace(/\.s?css$/,
				`.rtl.${rtlContentHash.digest('hex').substring(0, 8)}.min.css`);
			fs.writeFileSync(path.resolve(__dirname, newRTLVersion), rtlCSS);

			const rtlAssetName = file.replace(/\.s?css$/, '.rtl.css');

			// Remove a previous version if the content hash is different.
			if (assets[rtlAssetName] && assets[rtlAssetName] !== newRTLVersion) {
				console.log(`\x1b[32mUpdated RTL css for ${file}.\x1b[0m`);
				const oldFileFullPath = path.resolve(__dirname, assets[rtlAssetName]);
				if (fs.existsSync(oldFileFullPath)) fs.unlinkSync(oldFileFullPath);
			} else if (ready) {
				console.log(`\x1b[32mProcessed RTL css for ${file}.\x1b[0m`);
			}

			assets[rtlAssetName] = newRTLVersion;
		} else {
			return;
		}
	} else {
		if (argv.watchFiles)
			console.log('\x1b[33mWatches established, and initial build complete.\n'
				+ 'Press Control-C to stop.\x1b[0m');
		ready = true;
	}

	if (ready) fs.writeFileSync(assetFile, JSON.stringify(assets));
};

const themesDir = path.resolve(__dirname, 'themes');
const jsDir = path.resolve(__dirname, 'js');

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

// Set up the watcher.
if (argv.watchFiles) console.log('\x1b[32mEstablishing watches and performing initial build.\x1b[0m');
chokidar.watch(['js', 'themes'], {
	ignored: /layouts|\.min\.(js|css)$/,
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
			console.log(`\x1b[34mDeleting minified file for ${file}.\x1b[0m`);
			fs.unlinkSync(path.resolve(__dirname, assets[file]));
			delete assets[file];
		}
	})
	.on('error', (error) => console.log(`\x1b[32m${error}\x1b[0m`));
