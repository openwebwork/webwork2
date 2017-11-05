use 5.010;
use warnings;

BEGIN {
	require "./grab_course_environment.pl";
	eval "use lib '$WebworkBase::RootPGDir/lib'"; die $@ if $@;
	eval "use lib '$WebworkBase::RootWebwork2Dir/lib'"; die $@ if $@;
}

use WeBWorK::ContentGenerator::Instructor::FileManager;

use Test::More tests => 12;

ok isText("abcdghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"), 'ordinary string is text';
ok isText("abc\ndef"), 'string with newline is text';
ok isText("abc\r\ndef"), 'string with CRLF (windows style) is text';
ok !isText("abcdef\x01\x02abcdef"), 'string with 2 consecutive control characters is not text';
ok !isText("\x01\x1F\x7FHD08U23NV\x00\x08"), 'string with multiple blocks of 2+ control characters is not text';
ok isText("abcdef\x0Aasdfd"), 'text with 1 control character is still considered text';
ok isText("\x00abcdef\x1Fghijklm"), 'text with multiple instances of single isolated control characters is still considered text';
ok isText("abc\n\ndef\n\n\n\nghijklm"), 'text with multiple consecutive newlines is text';
ok isText("abc\r\n\r\ndef\r\n\r\n\r\n\r\nghijklm"), 'text with multiple consecutive CRLF\'s (windows style) is text';
ok isText("                 "), 'string of all spaces is text';
ok isText("      \r\n\t\r\n\t        "), 'string of all spaces, tabs, CRs and newlines is text';
ok isText("abcdef\t\t\t\tasdfjka"), 'string with multiple consecutive tabs is text';