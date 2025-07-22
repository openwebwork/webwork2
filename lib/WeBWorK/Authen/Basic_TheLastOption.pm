package WeBWorK::Authen::Basic_TheLastOption;
use base qw/WeBWorK::Authen/;

=head1 NAME

WeBWorK::Authen::Basic_TheLastOption - Use only the functionality in WeBWorK::Authen.

This module provides only the functionality that is in the base
module WeBWor::Authen.  That module supports password
authentication and permits guest logins.  If one wants
to provide those options, then this module should
be the last one in the array of the Authen module hashes.

=cut

1;
