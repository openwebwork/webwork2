<?php

$metadataURL = getenv('SP_METADATA_URL');

if ($metadataURL === False) {
	exit("Set the environment varable SP_METADATA_URL to the webwork2 service provider's metadata url.");
}

$config = [
	'sets' => [
		'webwork2' => [
			'cron' => ['metarefresh'],
			'sources' => [
				['src' => $metadataURL]
			],
			'expiresAfter' => 60 * 60 * 24 * 365 * 10, // 10 years, basically never
			'outputDir' => 'metadata/metarefresh-webwork/',
			'outputFormat' => 'flatfile',
		]
	]
];
