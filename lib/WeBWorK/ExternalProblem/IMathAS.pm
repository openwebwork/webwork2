package WeBWorK::ExternalProblem::IMathAS;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::ExternalProblem::IMathAS - Use questions from an IMathAS server as problems.

=head1 DESCRIPTION

A problem whose source file is of one of the forms

    imathas:1234
    imathas:servername:1234
    myopenmath:1234

is not read from a file.  It is the question with the numeric id 1234 on an
IMathAS server.  The first form uses the default server, the second the server
with the given name, and the third is short for C<imathas:myopenmath:1234>.  The
IMathAS server renders and scores the question, and that can be an IMathAS
installation that is run alongside WeBWorK, or a remote one such as MyOpenMath.

The servers that can be used are configured in the C<%imathas> hash of the
course environment (see C<defaults.config>).

    $imathas{timeout}       = 10;
    $imathas{defaultServer} = 'local';
    $imathas{servers}       = {
        local      => { url => 'http://localhost:8088',     publicURL => '/imathas' },
        myopenmath => { url => 'https://www.myopenmath.com', publicURL => 'https://www.myopenmath.com' },
    };

C<url> is the address that the WeBWorK server uses to reach IMathAS.
C<publicURL> is the address that a browser uses to load the IMathAS JavaScript
and images.  Only use a server that you do not run with the permission of those
that do.

Two stock endpoints of IMathAS are used.  C<embedq2.php> shows and scores a
question, and C<util/ptx.php> gives a question as PreTeXt with its correct
answers and its solution.  No changes to IMathAS are needed.  Requests to
IMathAS are not signed, so no account on the IMathAS server is needed.  Note
that for a request that is not signed, IMathAS adds 10000 to the seed that it is
given.

The question is still rendered by PG.  WeBWorK gets what is needed from the
IMathAS server before PG is called (see L</pgOptions> and
L<WeBWorK::ExternalProblem>), and then has PG render a short problem that uses
the C<IMathAS.pl> macro in the C<IMathAS> directory next to this module.  That
macro is internal to this module.  It puts the question into the problem, and
gives PG the
answers and the score that IMathAS gave.  So answer feedback, hardcopy, the
problem graders, and so on work as they do for other problems.

=cut

use Mojo::UserAgent;
use Mojo::Promise;
use Mojo::URL;
use Mojo::JSON   qw(decode_json encode_json);
use MIME::Base64 qw(decode_base64url);
use Encode       qw(decode);

use Mojo::File qw(curfile);

use WeBWorK::ExternalProblem::IMathAS::PTXToTeX qw(ptx_to_tex);

our @EXPORT_OK = qw(parseSource);

# The question number that embedq2.php uses for the one question it shows.
use constant QN => 5;

# This is put first in the macros path so that a macro of the same name elsewhere is not used instead.
use constant MACROS_DIR => curfile->sibling('IMathAS')->to_string;

# The source of the problem that PG renders for an IMathAS question.  Note that the question is not given here.  It is
# in the imathas key of the PG environment.
use constant PG_SOURCE => <<~'END_PG';
	DOCUMENT();
	loadMacros('PGstandard.pl', 'IMathAS.pl');
	TEXT(IMathASQuestion());
	ENDDOCUMENT();
	END_PG

=head1 FUNCTIONS

=head2 parseSource

    my $source = parseSource($sourceFile);

If C<$sourceFile> is the source file of a problem that is an IMathAS question,
then this returns a reference to a hash with the keys C<id> (the numeric id of
the question) and C<server> (the name of the server, or undef for the default
server).  Otherwise this returns undef.

=cut

sub parseSource ($sourceFile) {
	return unless defined $sourceFile;
	return { server => $1, id => $2 } if $sourceFile =~ /^imathas:(?:([\w.-]+):)?(\d+)$/i;
	return { server => 'myopenmath', id => $1 } if $sourceFile =~ /^myopenmath:(\d+)$/i;
	return;
}

=head2 pgOptions

    WeBWorK::ExternalProblem::IMathAS::pgOptions($ce, \%options, $prefix);

This is called by L<WeBWorK::ExternalProblem/pgOptions> for a problem whose
source file (in the C<sourceFilePath> option) has the prefix C<imathas> or
C<myopenmath>.  It takes the course environment and the options for the
C<WeBWorK::PG> constructor, and changes the options so that PG renders the
IMathAS question.  The question is obtained from the IMathAS server for that,
and responses in the C<inputs_ref> option are scored.

The data for the C<IMathAS.pl> macro is put into the C<imathas> option.  That is
a reference to a hash with the keys C<id>, C<server>, and C<source> (the source
file).  If the question could not be loaded (or the source file is not valid),
then it has the key C<error>.  Otherwise it has the key C<question> with the
result of L</question> unless the display mode is for hardcopy or PreTeXt, and
the key C<static> with the result of L</static_question>.

Returns true.

=cut

sub pgOptions ($ce, $options, $prefix = undef) {
	my $source = parseSource($options->{sourceFilePath});
	my $data   = { source => $options->{sourceFilePath} };

	my $displayMode = $options->{displayMode} // 'MathJax';
	if (!$source) {
		$data->{error} =
			"The source must be of the form imathas:1234, imathas:servername:1234, or myopenmath:1234, "
			. "where 1234 is the numeric id of the question.\n";
	} elsif ($options->{answerPrefix}) {
		# The IMathAS JavaScript and IMathAS itself determine the names of the form fields of a question, and those can
		# not be prefixed as is needed for the problems of a test.
		$data->{error} = "IMathAS questions can not be used in tests.\n";
	} else {
		$data->{id}     = $source->{id};
		$data->{server} = $source->{server};

		my $static = $displayMode eq 'tex' || $displayMode eq 'PTX';

		# The question as IMathAS gives it for output that is not interactive is always obtained, since that gives the
		# correct answers (typeset) and tells if there is a solution.  For HTML output, that is obtained at the same
		# time as the interactive question.
		my $loaded = load(
			{
				id     => $source->{id},
				server => $source->{server},
				seed   => $options->{problemSeed} || 1234,
				inputs => $options->{inputs_ref},
				config => $ce->{imathas}
			},
			question => !$static,
			static   => 1
		);

		$data->{static} = $loaded->{static};
		if ($static) {
			$data->{error} = $loaded->{static}{error};
		} else {
			$data->{question} = $loaded->{question};
			$data->{error}    = $loaded->{question}{error};
		}
	}
	delete $data->{error} unless $data->{error};

	$options->{imathas}    = $data;
	$options->{r_source}   = \(my $pgSource = PG_SOURCE);
	$options->{macrosPath} = [ MACROS_DIR, @{ $options->{macrosPath} // [] } ];

	return 1;
}

=head2 load

    my $loaded = WeBWorK::ExternalProblem::IMathAS::load(
        {
            id     => $id,
            seed   => $seed,
            inputs => $inputs_ref,
            server => $name,
            config => $ce->{imathas}
        },
        question => 1,
        static   => 1
    );

Gets the IMathAS question with the given numeric id and seed from the named
server (the default server if C<server> is not given).  The requests to the
server are made at the same time, and this waits for them to finish.

The returned hash has the key C<question> if C<question> is true, with the
result described in L</question>, and the key C<static> if C<static> is true,
with the result described in L</static_question>.

=cut

sub load ($params, %what) {
	my @which = grep { $what{$_} } qw(question static);

	my $config = eval { config($params->{config}, $params->{server}) };
	unless ($config) {
		my $error = $@ || "Unknown error.\n";
		return { map { $_ => { error => $error } } @which };
	}

	my $timeout = ($config->{timeout} // '') =~ /^\d+$/ ? $config->{timeout} : 10;

	# Note that this waits for the requests with the event loop of the process.  So this can not be called from code
	# that is run by that event loop.  It is meant to be called in a subprocess (where the event loop is not running).
	my $ua = Mojo::UserAgent->new(
		connect_timeout    => $timeout,
		request_timeout    => $timeout,
		inactivity_timeout => $timeout,
		max_redirects      => 3
	);

	my %result;
	my @promises = map {
		my $which  = $_;
		my $loader = $which eq 'question' ? \&_question : \&_static_question;
		Mojo::Promise->resolve->then(sub { return $loader->($ua, $config, $params) })->catch(sub ($err) {
			return { error => $err =~ /\n$/ ? $err : "$err\n" };
		})->then(sub ($loaded) {
			$result{$which} = $loaded;
			return;
		});
	} @which;
	Mojo::Promise->all(@promises)->wait if @promises;

	return \%result;
}

# The settings for the named server, or for the default server if no name is given.  The name of the server and the
# timeout setting are included with the settings of the server.  This dies if the server is not in the configuration.
sub config ($config, $server) {
	$config = {}                       unless ref $config eq 'HASH';
	$server = $config->{defaultServer} unless defined $server && $server ne '';
	die "No default IMathAS server is set.  Set \$imathas{defaultServer} in localOverrides.conf.\n"
		unless defined $server && $server ne '';
	my $settings = ref $config->{servers} eq 'HASH' ? $config->{servers}{$server} : undef;
	die qq{The IMathAS server "$server" is not configured.  Add it to \$imathas{servers} in localOverrides.conf.}
		. ($server eq ($config->{defaultServer} // '') ? '  That is the default server.' : '') . "\n"
		unless ref $settings eq 'HASH';
	die qq{The IMathAS server "$server" does not have a valid url.\n}
		unless ($settings->{url} // '') =~ m{^https?://[^\s?#]+$};
	return { timeout => $config->{timeout}, %$settings, name => $server };
}

# Send a request to the IMathAS server.  This returns a promise that resolves to the response.  The request is a POST
# request if form fields are given, and a GET request otherwise.
sub request ($ua, $config, $path, $query = undef, $form = undef) {
	my $url = Mojo::URL->new(($config->{url} =~ s{/$}{}r) . "/$path");
	$url->query($query) if $query && %$query;

	return ($form ? $ua->post_p($url => form => $form) : $ua->get_p($url))->then(
		sub ($tx) {
			my $res = $tx->res;
			die 'The request to IMathAS failed: ' . ($res->code // '') . ' ' . ($res->message // '') . "\n"
				unless $res->is_success;
			return $res;
		},
		sub ($err) { die "The request to IMathAS failed: $err\n" }
	);
}

# Send a request to embedq2.php, the endpoint of IMathAS that shows and scores a question.  This returns a promise that
# resolves to the data in the response.
sub post ($ua, $config, $query, $form) {
	return request($ua, $config, 'embedq2.php', $query, $form)->then(sub ($res) {
		my $data = eval { decode_json($res->body) };
		# embedq2.php reports problems (such as "Question not available") as plain text.
		die 'IMathAS said: ' . substr(decode('UTF-8', $res->body) =~ s/<[^>]*>//gr, 0, 300) . "\n"
			unless ref $data eq 'HASH';
		return $data;
	});
}

# IMathAS gives the result of scoring and the state of a question as JWTs.  This returns the payload of one.
sub jwt_decode ($jwt) {
	my (undef, $body) = split /\./, $jwt // '';
	die "Malformed token received from IMathAS.\n" unless defined $body;
	return decode_json(decode_base64url($body));
}

# The part number of an IMathAS input name, or undef if the name is not one for the question.  The answer box of a
# question with one part is named qn5, and those of a question with several parts are named qn6000, qn6001, and so on.
sub part_of_name ($name) {
	return unless $name =~ /^(?:qn|tc|qs)(\d+)/;
	return 0         if $1 == QN;
	return $1 % 1000 if $1 >= (QN + 1) * 1000 && $1 < (QN + 2) * 1000;
	return;
}

=head2 question

    my $result = WeBWorK::ExternalProblem::IMathAS::question({
        id     => $id,
        seed   => $seed,
        inputs => $inputs_ref,
        server => $name,
        config => $ce->{imathas}
    });

Renders the IMathAS question with the given numeric id and seed from the named
server (the default server if C<server> is not given).  If C<inputs> contains
responses to the question (form fields named as IMathAS names them), then those
responses are scored.

Returns a reference to a hash with the keys

=over

=item html, jsparams, jsparams_json, errors

The question HTML, the parameters that the IMathAS JavaScript needs to
initialize it (also as a JSON string), and any errors that IMathAS reported.
Addresses in the HTML that are relative to the root of the IMathAS server are
changed to start with the C<publicURL> of the server.  The answer entry tips are
not in the parameters (they are in C<boxes> instead), and neither are the
settings for the answer preview of IMathAS since that is not used.

=item boxes

A reference to an array with one hash for each answer box, in order, with keys
C<name> (the name of the form field), C<part>, C<type> (the IMathAS question
type), C<tip> and C<longtip> (the short and long answer entry tips, undef if
there are none), and when scored also C<score> (from 0 to 1) and
C<student_ans>.  The correct answers are not here.  Those are obtained with
C<static_question>.

=item scored, score

Whether responses were scored, and the total score of the question from 0 to 1.

=item publicURL

The C<publicURL> of the server without a trailing slash.

=back

On failure (for example if the server is not configured, can not be reached, or
does not have the question) the hash only has the key C<error>.

=cut

sub question ($params) { return load($params, question => 1)->{question} }

# This returns a promise that resolves to the result described above.
sub _question ($ua, $config, $params) {
	my $qn = QN;

	die "A numeric IMathAS question id is required.\n" unless ($params->{id} // '') =~ /^\d+$/;

	my %settings = (
		id   => $params->{id},
		seed => ($params->{seed} // 0) % 10000,
		# Mathematics is left as AsciiMath for MathJax to typeset.
		mathdisp => 7,
		# Essay answers are plain text, without the IMathAS rich text editor.
		useed              => 0,
		jssubmit           => 1,
		showscoredonsubmit => 1,
		# WeBWorK decides when to show correctness.
		hidescoremarkers => 1,
		hidescoreval     => 1,
		allowregen       => 0,
		showans          => 0,
		maxtries         => 0,
		showansafter     => 0,
	);

	my %responses = map { $_ => $params->{inputs}{$_} }
		grep { defined part_of_name($_) && !ref $params->{inputs}{$_} } keys %{ $params->{inputs} // {} };
	my %parts = map { part_of_name($_) => 1 } grep { ($responses{$_} // '') =~ /\S/ && !/-choicemap$/ } keys %responses;

	# The first request renders the question and gives its state.  If there are responses, then a second request
	# scores them.
	return post($ua, $config, \%settings, { ajax => 1 })->then(sub ($initial) {
		die "Unexpected response from IMathAS.\n"
			unless ref $initial->{disp} eq 'HASH' && defined $initial->{state};
		return [ $initial, undef ] unless %parts;
		return post(
			$ua, $config, undef,
			{
				%responses,
				state     => $initial->{state},
				toscoreqn => encode_json({ $qn => [ sort { $a <=> $b } keys %parts ] })
			}
		)->then(sub ($scored) {
				return [ $initial, $scored ];
		});
	})->then(sub ($responses) {
		return _question_result($config, @$responses);
	});
}

# The result described for question above from the responses of IMathAS to the requests to render the question, and to
# score responses (undef if there were none).
sub _question_result ($config, $initial, $scored) {
	my $qn     = QN;
	my $disp   = $initial->{disp};
	my $result = { scored => 0, score => 0, errors => [] };

	my ($raw, $student);
	if ($scored) {
		my $outcome = jwt_decode($scored->{jwt});
		my $state   = jwt_decode($outcome->{state});

		$result->{scored} = 1;
		$result->{score}  = $outcome->{score} // 0;
		$raw              = $outcome->{raw};
		$student          = $state->{stuanswers}{ $qn + 1 } // $state->{stuanswers}[ $qn + 1 ]
			if ref $state->{stuanswers};
		push(@{ $result->{errors} }, @{ $outcome->{errors} }) if ref $outcome->{errors} eq 'ARRAY';
		$disp = $scored->{disp}                               if ref $scored->{disp} eq 'HASH';
	}

	$result->{html} = $disp->{html} // '';

	# Addresses in the question that are relative to the root of the IMathAS server need to be changed to addresses that
	# work on the page that the question is put in.
	$result->{publicURL} = ($config->{publicURL} // '') =~ s{/$}{}r;
	$result->{html} =~ s{\b(src|href)\s*=\s*(["'])/(?!/)}{$1=$2$result->{publicURL}/}gi;

	$result->{jsparams} = $disp->{jsparams} // {};
	push(@{ $result->{errors} }, @{ $disp->{errors} }) if ref $disp->{errors} eq 'ARRAY';

	# PHP arrays arrive as JSON arrays or objects depending on their keys, so accept both.
	my $at = sub ($data, $part) {
		return $data->{$part} if ref $data eq 'HASH';
		return $data->[$part] if ref $data eq 'ARRAY';
		return $part == 0 ? $data : undef;
	};
	my $text = sub ($value) { return ref $value ? encode_json($value) : $value };

	for my $ref (sort { $a <=> $b } grep {/^\d+$/} keys %{ $result->{jsparams} }) {
		my $part = part_of_name("qn$ref");
		next unless defined $part;
		my $box = {
			name => "qn$ref",
			part => $part,
			type => $result->{jsparams}{$ref}{qtype},
			# The answer entry tips are removed from the parameters for the IMathAS JavaScript since the macro shows
			# them in the way that WeBWorK shows help.
			tip     => delete $result->{jsparams}{$ref}{tip},
			longtip => delete $result->{jsparams}{$ref}{longtip}
		};
		# The answer preview of IMathAS is not used.
		delete $result->{jsparams}{$ref}{preview};
		if ($result->{scored}) {
			my $score = $at->($raw, $part);
			# A question that is scored as a whole only has one raw score.
			$score = $result->{score} if !defined $score && ref $raw && (ref $raw eq 'HASH' ? keys %$raw : @$raw) == 1;
			$box->{score}       = !defined $score || $score < 0 ? 0 : $score > 1 ? 1 : $score;
			$box->{student_ans} = $text->($at->($student, $part)) // '';
		}
		push(@{ $result->{boxes} }, $box);
	}

	# Encode this here so that the macro does not need to encode JSON inside the safe compartment.
	$result->{jsparams_json} = encode_json($result->{jsparams});

	return $result;
}

=head2 static_question

    my $result = WeBWorK::ExternalProblem::IMathAS::static_question({
        id     => $id,
        seed   => $seed,
        server => $name,
        config => $ce->{imathas}
    });

Gets a version of the IMathAS question for output that is not interactive
(hardcopy and PreTeXt), and its correct answers and solution.  This uses the
C<util/ptx.php> endpoint of IMathAS, which gives the question as PreTeXt.  The
parameters are as for C<question> (C<inputs> is not used).

Returns a reference to a hash with the keys

=over

=item ptx

The statement of the question as PreTeXt.  This is as IMathAS gives it, except
that each C<fillin> element is given a C<name> attribute with the name of the
answer that it is for.

=item tex

The statement of the question as LaTeX.  This is converted from the PreTeXt by
L<WeBWorK::ExternalProblem::IMathAS::PTXToTeX>.  Images are not included.

=item answers

A reference to an array with a hash for each answer of the question, in order,
with keys C<name>, C<correct_ans> (as text), and C<correct_tex> (as LaTeX,
undef if the answer is not entirely mathematics).

=item solution

A reference to a hash with the solution of the question as PreTeXt, LaTeX, and
HTML in the keys C<ptx>, C<tex>, and C<html>.  This is only present if the
question has a solution that its author set to be shown with the answers.

=back

On failure the hash only has the key C<error>.

=cut

sub static_question ($params) { return load($params, static => 1)->{static} }

# This returns a promise that resolves to the result described above.
sub _static_question ($ua, $config, $params) {
	die "A numeric IMathAS question id is required.\n" unless ($params->{id} // '') =~ /^\d+$/;

	# Use the seed that gives the same version of the question that embedq2.php shows.  It adds 10000 to the seed of a
	# request that is not signed, and ptx.php uses the seed as it is given.
	my $seed = ($params->{seed} // 0) % 10000 + 10000;

	return request($ua, $config, 'util/ptx.php', { id => $params->{id}, seed => $seed })->then(sub ($res) {
		return _static_result(decode('UTF-8', $res->body));
	});
}

# The result described for static_question above from the PreTeXt that IMathAS gives for the question.
sub _static_result ($content) {
	$content =~ s/\x{A0}/ /g;
	my ($statement) = $content =~ m{<statement>\s*(.*?)\s*</statement>}s;
	die 'IMathAS did not give the question' . ($content =~ /\S/ ? ': ' . substr($content, 0, 300) : '.') . "\n"
		unless defined $statement;

	# IMathAS puts each answer in a list item.
	my ($answer) = $content =~ m{<answer>\s*(.*?)\s*</answer>}s;
	my @correct = ($answer // '') =~ m{<li>(.*?)</li>}gs;
	my @correct_tex;
	for (@correct) {
		# An answer that is entirely mathematics is also given as LaTeX.
		my ($tex) = m{^\s*<m>\s*(?:\\displaystyle)?\s*(.*?)\s*</m>\s*$}s;
		s{</p>\s*<p>}{, }g;
		s{<m>\s*(?:\\displaystyle)?\s*(.*?)</m>}{$1}gs;
		s{<[^>]*>}{}g;
		for ($_, $tex // ()) {
			s{\\amp\b}{&}g;
			s{\\lt\b}{<}g;
			s{\\gt\b}{>}g;
			s{&lt;}{<}g;
			s{&gt;}{>}g;
			s{&amp;}{&}g;
			s{^\s+|\s+$}{}g;
		}
		# IMathAS gives infinity as text and not as mathematics for some types of questions.
		$tex = ($1 // '') . '\infty' if !defined $tex && /^(-?)oo$/;
		push(@correct_tex, $tex);
	}

	# Name the answers as embedq2.php names the answer boxes, and name the answer blanks for them.
	my $count = () = $statement =~ /<fillin\b/g;
	$count = @correct if @correct > $count;
	my @names = $count == 1 ? ('qn' . QN) : map { 'qn' . ((QN + 1) * 1000 + $_) } 0 .. $count - 1;
	my $blank = 0;
	$statement =~ s{<fillin\b}{'<fillin name="' . $names[ $blank++ ] . '"'}ge;

	# IMathAS only gives a solution if the author of the question set it to be shown with the answers.
	my ($solution) = $content =~ m{<solution>\s*(.*?)\s*</solution>}s;

	return {
		ptx     => $statement,
		tex     => ptx_to_tex($statement),
		answers => [
			map { { name => $names[$_], correct_ans => $correct[$_], correct_tex => $correct_tex[$_] } }
				0 .. $#names
		],
		defined $solution && $solution =~ /\S/
		? (solution => { ptx => $solution, tex => ptx_to_tex($solution), html => ptx_to_html($solution) })
		: ()
	};
}

# Convert the PreTeXt that IMathAS gives for a solution to HTML.  Mathematics is left as LaTeX in the delimiters that
# MathJax uses.  This only deals with the elements that IMathAS uses.
sub ptx_to_html ($ptx) {
	# Mathematics and characters are kept here and put back at the end.
	my @kept;
	my $keep = sub ($value) { push(@kept, $value); return "\x{0}$#kept\x{0}" };

	my $math = sub ($tex) {
		$tex =~ s/\\amp\b/&amp;/g;
		$tex =~ s/\\lt\b/&lt;/g;
		$tex =~ s/\\gt\b/&gt;/g;
		return $tex;
	};
	$ptx =~ s{<m>(.*?)</m>}{$keep->('\\(' . $math->($1) . '\\)')}gse;
	$ptx =~ s{<me>(.*?)</me>}{$keep->('\\[' . $math->($1) . '\\]')}gse;

	my %characters = (
		percent    => '%',
		ampersand  => '&amp;',
		hash       => '#',
		dollar     => '$',
		underscore => '_',
		lbrace     => '{',
		rbrace     => '}',
		lbracket   => '[',
		rbracket   => ']',
		less       => '&lt;',
		greater    => '&gt;',
		tilde      => '~',
		circumflex => '^',
		backslash  => '\\',
		asterisk   => '*',
		ndash      => '&ndash;',
		mdash      => '&mdash;',
		ellipsis   => '&hellip;',
		nbsp       => '&nbsp;',
		lq         => '&ldquo;',
		rq         => '&rdquo;',
		lsq        => '&lsquo;',
		rsq        => '&rsquo;'
	);
	$ptx =~ s{<(\w+)\s*/>}{defined $characters{$1} ? $keep->($characters{$1}) : "<$1/>"}ge;

	my %same    = map { $_ => 1 } qw(p ul li em i u sup sub b strong);
	my %renamed = (
		tabular => 'table',
		row     => 'tr',
		cell    => 'td',
		alert   => 'strong',
		term    => 'strong',
		c       => 'code',
		var     => 'em'
	);

	my $html = '';
	while ($ptx =~ m{\G(?:<(/?)(\w+)\b([^>]*?)(/?)>|([^<]+))}gs) {
		my ($closing, $element, $attributes, $empty, $text) = ($1, $2, $3, $4, $5);
		if (defined $text) {
			$html .= $text;
		} elsif ($same{$element} || $renamed{$element}) {
			$html .= "<$closing" . ($renamed{$element} // $element) . '>';
		} elsif ($element eq 'ol') {
			my ($marker) = $attributes     =~ /\bmarker="([^"]*)"/;
			my $type     = ($marker // '') =~ /A/ ? ' type="A"' : ($marker // '') =~ /a/ ? ' type="a"' : '';
			$html .= $closing ? '</ol>' : "<ol$type>";
		} elsif ($element eq 'q') {
			$html .= $closing ? '&rdquo;' : '&ldquo;';
		} elsif ($element eq 'br') {
			$html .= '<br>' unless $closing;
		} elsif ($element eq 'fillin') {
			$html .= '____' unless $closing;
		} elsif ($element eq 'image') {
			my ($source) = $attributes =~ /\bsource="([^"]*)"/;
			$html .= qq{<img src="$source" alt="">} if !$closing && defined $source;
		} elsif ($element eq 'url') {
			my ($href) = $attributes =~ /\bhref="([^"]*)"/;
			$html .= $closing ? '</a>' : '<a href="' . ($href // '') . '">';
		}
		# Any other element is left out, but what it contains is kept.
	}

	$html =~ s/\x{0}(\d+)\x{0}/$kept[$1]/g;
	$html =~ s/^\s+|\s+$//g;
	return $html;
}

1;
