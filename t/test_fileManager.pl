#!/Volumes/WW_test/opt/local/bin/perl -w
use 5.010;
use warnings;

BEGIN {
        require "./grab_course_environment.pl";
        eval "use lib '$WebworkBase::RootPGDir/lib'"; die $@ if $@;
        eval "use lib '$WebworkBase::RootWebwork2Dir/lib'"; die $@ if $@;
}

use Test::More tests => 14;
use WeBWorK::ContentGenerator::Instructor::FileManager qw/isText/;

ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("abcdghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"), 'ordinary string is text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("abc\ndef"), 'string with newline is text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("abc\r\ndef"), 'string with CRLF (windows style) is text';
ok !WeBWorK::ContentGenerator::Instructor::FileManager::isText("abcdef\x01\x02abcdef"), 'string with 2 consecutive control characters it not text';
ok !WeBWorK::ContentGenerator::Instructor::FileManager::isText("\x01\x1F\x7FHD08U23NV\x00\x08"), 'string with multiple blocks of 2+ control characters is not text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("abcdef\x0Aasdfd"), 'text with 1 control character is still considered text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("\x00abcdef\x1Fghijklm"), 'text with multiple instances of single isolated control characters is still considered text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("abc\n\ndef\n\n\n\nghijklm"), 'text with multiple consecutive newlines is text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("abc\r\n\r\ndef\r\n\r\n\r\n\r\nghijklm"), 'text with multiple consecutive CRLF\'s (windows style) is text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("                 "), 'string of all spaces is text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("      \r\n\t\r\n\t        "), 'string of all spaces, tabs, CRs and newlines is text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("abcdef\t\t\t\tasdfjka"), 'string with multiple consecutive tabs is text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("abc\x00\ndef"), 'control character before newline surrounded by ASCII chars is text';
ok WeBWorK::ContentGenerator::Instructor::FileManager::isText("abc\n\x00def"), 'newline before control character surrounded by ASCII chars is text';
