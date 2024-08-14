<?php

if (!isset($_ENV['SP_METADATA_URL'])) {
    exit("Set env var SP_METADATA_URL to the Webwork SP's metadata url");
}

$config = [
    'sets' => [
        'webwork' => [
            'cron' => ['docker'],
            'sources' => [
                ['src' => $_ENV['SP_METADATA_URL']]
            ],
            'expiresAfter' => 60*60*24*365*10, // 10 years, basically never
            'outputDir' => 'metadata/metarefresh-webwork/',
            'outputFormat' => 'flatfile',
        ]
    ]
];
