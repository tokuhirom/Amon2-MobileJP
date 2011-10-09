use strict;
use warnings;
use utf8;

package Amon2::Setup::Flavor::MobileJP;
use parent qw(Amon2::Setup::Flavor::Large);

sub run {
	my ($self) = @_;
	$self->SUPER::run();

	$self->write_file("lib/<<PATH>>/Mobile.pm", <<'...', { xslate => $self->create_view(tmpl_path => 'tmpl/mobile')});
package <% $module %>::Mobile;
use strict;
use warnings;
use utf8;
use parent qw(<% $module %> Amon2::Web);
use File::Spec;

# dispatcher
use <% $module %>::Mobile::Dispatcher;
sub dispatch {
    return <% $module %>::Mobile::Dispatcher->dispatch($_[0]) or die "response is not generated";
}

<% $xslate %>

our $ALLOW_INSECURE_SESSION = 0;

# load plugins
use File::Path qw(mkpath);
use HTTP::Session::State::Cookie;
use HTTP::Session::Store::File;
use File::Spec;
__PACKAGE__->load_plugins(
    'Web::FillInFormLite',
    'Web::NoCache', # do not cache the dynamic content by default
    'Web::CSRFDefender',
	'Web::MobileAgent',
	'Web::MobileCharset',
	'Web::HTTPSession' => {
		state => sub {
			my $c = shift;
			if ($c->mobile_agent->is_docomo && $c->mobile_agent->browser_version < 2.0) {
				if ($ALLOW_INSECURE_SESSION) {
					# insecure.
					require HTTP::Session::State::GUID;
					HTTP::Session::State::GUID->new(
						name => 'amon2_sid',
					);
				} else {
					die "Bad session";
				}
			} else {
				HTTP::Session::State::Cookie->new(
					name => 'amon2_sid',
				);
			}
		},
		store => do {
			my $path = File::Spec->rel2abs(File::Spec->catdir(File::Spec->tmpdir, '<% dist %>-mobile-session'));
			mkpath($path);
			sub {
				my $c = shift;
				HTTP::Session::Store::File->new(
					dir => $path
				)
			}
		},
	},
);

# 全角カタカナを半角カタカナに変換する
use Lingua::JA::Regular::Unicode qw(katakana_z2h);
__PACKAGE__->add_trigger(
    HTML_FILTER => sub {
        my ( $c, $html ) = @_;
        return katakana_z2h($html);
    }
);


# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;
        $res->header( 'X-Content-Type-Options' => 'nosniff' );
    },
);

1;
...

	$self->write_file("lib/<<PATH>>/Mobile/Dispatcher.pm", <<'...');
package <% $module %>::Mobile::Dispatcher;
use strict;
use warnings;
use Router::Simple::Declare;
use Mouse::Util qw(get_code_package);
use Module::Find ();
use String::CamelCase qw(decamelize);

# define roots here.
my $router = router {
	connect '/' => {controller => 'Root', action => 'index' };
};

my @controllers = Module::Find::useall('<% $module %>::Mobile::C');
{
    no strict 'refs';
    for my $controller (@controllers) {
        my $p0 = $controller;
        $p0 =~ s/^<% $module %>::Mobile::C:://;
        my $p1 = decamelize($p0);
        next if $p0 eq 'Root';

        for my $method (sort keys %{"${controller}::"}) {
            next if $method =~ /(?:^_|^BEGIN$|^import$)/;
            my $code = *{"${controller}::${method}"}{CODE};
            next unless $code;
            next if get_code_package($code) ne $controller;
            $router->connect("/$p1/$method" => {
                controller => $p0,
                action     => $method,
            });
            print STDERR "map: /$p1/$method => ${p0}::${method}\n" unless $ENV{HARNESS_ACTIVE};
        }
    }
}

sub dispatch {
    my ($class, $c) = @_;
    my $req = $c->request;
    if (my $p = $router->match($req->env)) {
        my $action = $p->{action};
        $c->{args} = $p;
        "@{[ ref Amon2->context ]}::C::$p->{controller}"->$action($c, $p);
    } else {
        $c->res_404();
    }
}

1;
...

	$self->write_file("lib/<<PATH>>/Mobile/C/Root.pm", <<'...');
package <% $module %>::Mobile::C::Root;
use strict;
use warnings;
use utf8;

sub index {
    my ($class, $c) = @_;
    $c->render('index.tt');
}

1;
...

    $self->write_file('mobile.psgi', <<'...', {header => $self->psgi_header});
<% $header %>
use <% $module %>::Mobile;
use Plack::App::File;
use Plack::Util;
use DBI;

my $basedir = File::Spec->rel2abs(dirname(__FILE__));
my $db_config = <% $module %>->config->{DBI} || die "Missing configuration for DBI";
{
    my $c = <% $module %>->new();
    $c->setup_schema();
}
builder {
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/robots\.txt|/favicon.ico)$},
        root => File::Spec->catdir(dirname(__FILE__), 'static', 'pc');
    enable 'Plack::Middleware::ReverseProxy';

    mount '/static/' => Plack::App::File->new(root => File::Spec->catdir($basedir, 'static', 'pc'));
    mount '/' => <% $module %>::Mobile->to_app();
};
...

	$self->write_file('tmpl/mobile/index.tt', <<'...');
<!doctype html>
<html>
<head>
	<title><% dist %></title>
</head>
<body>
	モバイルサイトの雛形です。
	[% c().mobile_agent().carrier_longname %] でアクセスしています。
</body>
</html>
...

	$self->write_file('t/01_mobile.t', <<'...');
use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::Util;

my $app = Plack::Util::load_psgi('mobile.psgi');
test_psgi(
	app => $app,
	client => sub {
		my $cb = shift;
		my $req = HTTP::Request->new('GET', '/');
		$req->header('User-Agent' => 'DoCoMo/2.0 N02B(c500;TB;W24H16)');
		my $res = $cb->($req);
		is($res->code(), 200) or diag $res->content;
		like($res->content, qr{DoCoMo});
	},
);
done_testing;

...
	$self->write_file('t/00_compile_mobile.t', <<'...');
use strict;
use warnings;
use Test::More;

use_ok($_) for qw(
	<% $module %>::Mobile
	<% $module %>::Mobile::Dispatcher
);
done_testing;
...
}

sub create_makefile_pl {
    my ($self, $prereq_pm) = @_;

    $self->SUPER::create_makefile_pl(
        +{
            %{ $prereq_pm || {} },
			'HTTP::MobileAgent' => 0.33,
			'HTTP::MobileAgent::Plugin::Charset' => 0,
			'Encode::JP::Mobile' => 0,
			'HTTP::Session::Store::DBI' => '0.02',
			'HTTP::Session' => 0,
			'Amon2::Plugin::Web::HTTPSession' => 0,
        },
    );
}

1;

