################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/CGI.pm,v 1.16 2006/07/13 16:17:52 gage Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

=for comment

The goal here is to circumvent CGI's built-in param parsing and defer to WeBWorK::Request instead.

Default object is created by self_or_default.
self_or_default calls $CGI::DefaultClass->new

CGI->new says:
	$self->r(Apache2::RequestUtil->request) unless $self->r;
and it also calls:
	$self->init(@initializer);  -- @initializer will be empty in this case.

init() grabs params from $self->r->args (or POSTDATA)
several methods to get the query string
calls parse_params on it

	parse_params calls $self->add_parameter and then sets the value with:
		push (@{$self->{$param}},$value);
	
	add_parameter adds the name of the parameter to $self->{'.parameters'} (an arrayref)

.fieldnames is an Associative array containing our defined fieldnames
(which come from param .cgifields, which is included in CGI::query_string() output)
(as far as i can tell, we never use query_string, or anything that calls it)
(do we see .cgifields in our requests? i think snot...)
so we don't have to worry about .fieldnames!
WAIT! -- endform calls get_fields, which prints a hidden .cgifields field with value .parametersToAdd
      -- .parametersToAdd is cleared out by startform and added to by register_parameter
      -- checkbox, _box_group, and scrolling_list call register_parameter
      -- (radio_group and checkbox_group call _box_group)
SO: .cgifields lists the names of all the checkboxes, radio buttons, and select boxes
    (what's the use in that? what the fuck!)
and that goes into .fieldnames, which is also touched in:
	- delete - delete entry when a field is deleted
	- save (to a filehandle) - turn back into .cgifields when writing
	- checkbox - test to see if a param was in the incoming request
	- query_string - turn back into .cgifields
	- previous_or_default - test to see if a param was in the incoming request

PLACES WHERE $self->{'.parameters'} GETS USED:

add_parameter
all_parameters
delete
FIRSTKEY
NEXTKEY

ANYWAY,

we don't have to worry about .parametersToAdd, since that's all dealt with within the form generation
	(startform -> checkbox/_box_group/scrolling_list -> endform)
.cgifields shouldn't be a problem, as long as CGI gets SOME query_string/postdata to work with
.parameters is pretty localized, so we might have to override those functions

the real issue is direct access to parameters through the self hash, rather than through param():

- param - get/set parameter values
- init - what looks like a hack for uploading XML docs.
       - adds a param called POSTDATA containing the value of $query_string
- save_request - store each param to global %QUERY_PARAM hash
- parse_params - add them in the first place
- add_parameter - check for already existing parameter (so as not to add name to .parameters twice
- delete - to get rid of param value
- append - to add a new value to the param
- param_fetch - return value of param, creating it if it didn't exist
- read_multipart - add one param per part, name is defined by Content-Disposition header
                 - value is either a filehandle or the value (depends on filename= versus name= in header)

this doesn't look TOO bad...

param: override in terms of WeBWorK::Request->param
add_parameter: override in terms of WeBWorK::Request->param
delete: override in terms of WeBWorK::Request->param
append: override in terms of WeBWorK::Request->param
param_fetch: override in terms of WeBWorK::Request->param

these can be overridden by defining in the subclass because:
(1) we never call them directly as functions
(2) CGI itself always calls them as methods

also, don't forget all_parameters, which access .parameters but doesn't touch the param values
and what about FIRSTKEY and NEXTKEY? we don't use them, but...

init: 
save_request: 
parse_params: 
read_multipart: 

all four of these methods are involved in populating .parameters and $self->{$param}
the results will never be used if the others are being overridden
so what if we lie to init and tell it there are no parameters, postdata, multipart data, etc?

the other trick is storing OUR WeBWorK::Request in $self->{'.r'}
stick it in there in our constructor, and then call SUPER::new
new will refrain from overwriting it with Apache2::RequestUtil->apache

no wait, i'm wrong. the REAL trick is getting our lexical instance of WeBWorK::Request ($r)
into the GLOBAL $CGI::Q variable! maybe we can do this trickily in 

=cut

package WeBWorK::CGIParamShim;

use strict;
use warnings;

use Carp;
use CGI::Util qw(rearrange);

# from http://search.cpan.org/src/LDS/CGI.pm-3.20/cgi_docs.html#subclassing
use vars qw/@ISA $VERSION/;
require CGI;
@ISA = 'CGI';
$VERSION = "0.1";

$CGI::DefaultClass = __PACKAGE__;
$WeBWorK::CGIParamShim::AutoloadClass = 'CGI';

sub new {
	my $invocant = shift;
	@_ = $WeBWorK::CGIParamShim::WEBWORK_REQUEST unless @_;
	return $invocant->SUPER::new(@_);
}

sub param {
	#CGI#my($self,@p) = self_or_default(@_);
	my($self,@p) = CGI::self_or_default(@_);
	return $self->all_parameters unless @p;
	my($name,$value,@other);

	# For compatibility between old calling style and use_named_parameters() style, 
	# we have to special case for a single parameter present.
	if (@p > 1) {
		#CGI#($name,$value,@other) = rearrange([NAME,[DEFAULT,VALUE,VALUES]],@p);
		($name,$value,@other) = rearrange(['NAME',['DEFAULT','VALUE','VALUES']],@p);
		my(@values);

		if (substr($p[0],0,1) eq '-') {
			@values = defined($value) ? (ref($value) && ref($value) eq 'ARRAY' ? @{$value} : $value) : ();
		} else {
			foreach ($value,@other) {
				push(@values,$_) if defined($_);
			}
		}
		# If values is provided, then we set it.
		if (defined $value) {
			$self->add_parameter($name);
			#CGI#$self->{$name}=[@values];
			$self->r->param($name => [@values]);
		}
	} else {
		$name = $p[0];
	}

	#CGI#return unless defined($name) && $self->{$name};
	# testing for truth was sufficient, because if the param exists it will always be an arrayref
	# but here, we need to test for definedness
	return unless defined($name) && defined($self->r->param($name));
	#CGI#return wantarray ? @{$self->{$name}} : $self->{$name}->[0];
	# we don't need wantarray here because WeBWorK::Request::param takes care of it
	return $self->r->param($name);
}

sub add_parameter {
	my($self,$param)=@_;
	return unless defined $param;
	#CGI#push (@{$self->{'.parameters'}},$param) 
	#CGI#	unless defined($self->{$param});
	$self->r->param($param => [])
		unless defined $self->r->param($param);
}

sub all_parameters {
    my $self = shift;
	#CGI#return () unless defined($self) && $self->{'.parameters'};
	#CGI#return () unless @{$self->{'.parameters'}};
	# we don't need to check for .parameters being defined
	return () unless defined($self);
	#CGI#return @{$self->{'.parameters'}};
	return $self->r->param;
}

sub delete {
	#CGI#my($self,@p) = self_or_default(@_);
	my($self,@p) = CGI::self_or_default(@_);
	#CGI#my(@names) = rearrange([NAME],@p);
	my(@names) = rearrange(['NAME'],@p);
	#CGI#my @to_delete = ref($names[0]) eq 'ARRAY' ? @$names[0] : @names;
	my @to_delete = ref($names[0]) eq 'ARRAY' ? @{$names[0]} : @names;
	my %to_delete;
	foreach my $name (@to_delete)
	{
		#CGI#CORE::delete $self->{$name};
		#CGI#CORE::delete $self->{'.fieldnames'}->{$name};
		#CGI#$to_delete{$name}++;
		# we can't currently delete a parameter, but we can empty it out
		$self->r->param($name => []);
	}
	#CGI#@{$self->{'.parameters'}}=grep { !exists($to_delete{$_}) } $self->param();
	return;
}

sub append {
	#CGI#my($self,@p) = self_or_default(@_);
	my($self,@p) = CGI::self_or_default(@_);
	#CGI#my($name,$value) = rearrange([NAME,[VALUE,VALUES]],@p);
	my($name,$value) = rearrange(['NAME',['VALUE','VALUES']],@p);
	my(@values) = defined($value) ? (ref($value) ? @{$value} : $value) : ();
	if (@values) {
		$self->add_parameter($name);
		#CGI#push(@{$self->{$name}},@values);
		$self->r->param($name => [$self->r->param($name), @values]);
	}
	return $self->param($name);	
}

sub param_fetch {
	croak "param_fetch not supported in " . __PACKAGE__;
}

1;
