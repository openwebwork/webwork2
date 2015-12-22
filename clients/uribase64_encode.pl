#!/usr/bin/perl -w

use MIME::Base64 qw( encode_base64 decode_base64);
use URI::Escape qw(uri_escape uri_unescape);
local($/);
print uri_escape encode_base64 <STDIN>;
print "\n\n";
