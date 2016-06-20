package WeBWorK3;
# handler: app.pl:

use Dancer2;



use Routes::Templates;
use Routes::Login;

use Data::Dump qw/dump/;

#print dump config;


#builder {
#    mount '/'    => Routes::Templates->to_app;
#    mount '/api' => Routes::Login->to_app;
#};




our $VERSION = '2.999';

true;
