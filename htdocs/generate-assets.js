#!/usr/bin/env node

/* eslint-env node */

const yargs = require('yargs');
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
	.option('develop-mode', {
		alias: 'd',
		description: 'Enable development mode.  This generates source maps in the output files.',
		type: 'boolean'
	})
	.argv;

// Object to store the new assets.
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

const processDir = async (dir) => {
	for (const file of fs.readdirSync(dir, { withFileTypes: true })) {
		if (file.isDirectory()) {
			await processDir(path.resolve(dir, file.name));
		} else {
			if (/(?<!\.min)\.js$/.test(file.name)) {
				// Process javascript
				const filePath = path.resolve(dir, file.name);
				const relPath = filePath.replace(`${__dirname}/`, '');
				console.log(`Proccessing ${relPath}`);

				const baseName = path.basename(relPath);
				const contents = fs.readFileSync(filePath, 'utf8');
				const result = await minify({ [baseName]: contents }, { sourceMap: argv.developMode });

				const minJS = result.code + (
					argv.developMode && result.map
					? `//# sourceMappingURL=data:application/json;charset=utf-8;base64,${
							Buffer.from(result.map).toString('base64')}`
					: ''
				);

				const contentHash = crypto.createHash('sha256');
				contentHash.update(minJS);

				const outputFile = filePath.replace(/\.js$/, `.${contentHash.digest('hex').substring(0, 8)}.min.js`);
				fs.writeFileSync(outputFile, minJS);

				assets[relPath] = outputFile.replace(`${__dirname}/`, '');
			} else if (/^(?!_).*(?<!\.min)\.s?css$/.test(file.name)) {
				// Process scss or css.
				const filePath = path.resolve(dir, file.name);
				const relPath = filePath.replace(`${__dirname}/`, '');
				console.log(`Proccessing ${relPath}`);

				const baseName = path.basename(relPath);

				// This works for both sass/scss files and css files.  For css files it just compresses.
				const result = sass.compile(filePath, { style: 'compressed', sourceMap: argv.developMode });
				if (result.sourceMap) result.sourceMap.sources = [ baseName ];

				// Pass the compiled css through the autoprefixer.
				// This is really only needed for the bootstrap.css files, but doesn't hurt for the rest.
				const prefixedResult = await postcss([autoprefixer]).process(result.css, { from: baseName });

				const minCSS = prefixedResult.css + (
					argv.developMode && result.sourceMap
					? `/*# sourceMappingURL=data:application/json;charset=utf-8;base64,${
							Buffer.from(JSON.stringify(result.sourceMap)).toString('base64')}*/`
					: ''
				);

				const contentHash = crypto.createHash('sha256');
				contentHash.update(minCSS);

				const outputFile =
					filePath.replace(/\.s?css$/, `.${contentHash.digest('hex').substring(0, 8)}.min.css`);
				fs.writeFileSync(outputFile, minCSS);

				const assetRelPath = relPath.replace(/\.scss$/, '.css');
				assets[assetRelPath] = outputFile.replace(`${__dirname}/`, '');
			}
		}
	}
};

const build = async () => {
	const themesDir = path.resolve(__dirname, 'themes');
	const jsDir = path.resolve(__dirname, 'js/apps');

	// Add a math4-overrides.css and math4-overrides.js file in each theme directory if they do not exist already.
	for (const file of fs.readdirSync(themesDir, { withFileTypes: true })) {
		if (!file.isDirectory()) continue;
		if (!fs.existsSync(path.resolve(themesDir, file.name, 'math4-overrides.js')))
			fs.closeSync(fs.openSync(path.resolve(themesDir, file.name, 'math4-overrides.js'), 'w'));
		if (!fs.existsSync(path.resolve(themesDir, file.name, 'math4-overrides.css'))
			&& !fs.existsSync(path.resolve(themesDir, file.name, 'math4-overrides.scss')))
			fs.closeSync(fs.openSync(path.resolve(themesDir, file.name, 'math4-overrides.css'), 'w'));
	}

	// Remove generated files from previous builds.
	cleanDir(themesDir);
	cleanDir(jsDir);

	try {
		await Promise.all([
			processDir(themesDir),
			processDir(jsDir)
		]);
	} catch (err) {
		console.log(err);
	}

	// Add third party assets to the output.
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

	// Write the compiled object to the list file.
	fs.writeFileSync(path.resolve(__dirname, 'static-assets.json'), JSON.stringify(assets));
};

build();
