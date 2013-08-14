use strict;
use warnings;
use utf8;

package Amon2::Setup::Flavor::MobileJP;
use parent qw(Amon2::Setup::Flavor::Large);
use Amon2::Setup::Flavor::Minimum;

sub run {
	my ($self) = @_;
	$self->SUPER::run();

    $self->Amon2::Setup::Flavor::Minimum::create_view(
        tmpl_path => 'tmpl/mobile',
        package => $self->{module} . '::Mobile::View',
        path => "lib/<<PATH>>/Mobile/View.pm",
        view_functions_package => $self->{module} . '::Mobile::ViewFunctions',
    );
    $self->Amon2::Setup::Flavor::Minimum::create_view_functions(
        package => $self->{module} . '::Mobile::ViewFunctions',
        path => "lib/<<PATH>>/Mobile/ViewFunctions.pm",
    );
	$self->write_file("lib/<<PATH>>/Mobile.pm", <<'...');
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

use <% $module %>::Mobile::View;
{
    my $view = <% $module %>::Mobile::View->make_instance(__PACKAGE__);
    sub create_view { $view }
}

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

__PACKAGE__->add_trigger(
	BEFORE_DISPATCH => sub {
		my ($c) = @_;
		if ($c->is_supported || $c->req->path eq'/non_supported') {
			return; # nop
		} else {
			return $c->redirect('/non_supported');
		}
	},
);

sub is_supported {
	my ($c) = @_;
	my $ma = $c->mobile_agent;
	if ($ma->is_docomo) {
		if ($ma->browser_version < 2.0 && !$ALLOW_INSECURE_SESSION) {
			return 0;
		} elsif ($ma->is_foma) {
			return 1;
		} else {
			return 0; # Mova is not supported
		}
	} elsif ($ma->is_non_mobile) {
		return 0;
	} elsif ($ma->is_softbank) {
		if ($ma->is_3gc) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($ma->is_ezweb) {
		# HDML 端末はもう消失したので、すべてサポートでいいでしょう
		return 1;
	} else {
		return 1;
	}
}

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
	# connect '/' => {controller => 'Root', action => 'index' };
};

my @controllers = Module::Find::useall('<% $module %>::Mobile::C');
{
    no strict 'refs';
    for my $controller (@controllers) {
        my $p0 = $controller;
        $p0 =~ s/^<% $module %>::Mobile::C:://;
        my $p1 = $p0 eq 'Root' ? '' : decamelize($p0) . '/';

        for my $method (sort keys %{"${controller}::"}) {
            next if $method =~ /(?:^_|^BEGIN$|^import$)/;
            my $code = *{"${controller}::${method}"}{CODE};
            next unless $code;
            next if get_code_package($code) ne $controller;
			my $p2 = $method eq 'index' ? '' : $method;
			my $path = "/$p1$p2";
            $router->connect($path => {
                controller => $p0,
                action     => $method,
            });
            print STDERR "map: $path => ${p0}::${method}\n" unless $ENV{HARNESS_ACTIVE};
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

sub non_supported {
    my ($class, $c) = @_;
    $c->render('non_supported.tt', {
		insecure_session => $<% $module %>::Mobile::ALLOW_INSECURE_SESSION,
	});
}

1;
...

    $self->write_file('app.psgi', <<'...', {header => $self->psgi_header});
<% $header %>
use <% $module %>::PC;
use Plack::Util;
use Plack::Builder;
use HTTP::MobileAgent;
use Plack::Request;

my $mobile = Plack::Util::load_psgi('mobile.psgi');
my $pc = Plack::Util::load_psgi('pc.psgi');
builder {
    mount '/admin/' => Plack::Util::load_psgi('admin.psgi');
    mount '/m/' => sub {
		my $env = shift;
		if (!HTTP::MobileAgent->new($env->{HTTP_USER_AGENT})->is_non_mobile) {
			return $mobile->($env);
		} else {
			my $req = Plack::Request->new($env);
			my $uri = $req->uri;
			my $path = $uri->path;
			$uri->path('/');
			return [302, ['Location' => $uri->as_string], []];
		}
	};
    mount '/' => sub {
		my $env = shift;
		if (HTTP::MobileAgent->new($env->{HTTP_USER_AGENT})->is_non_mobile) {
			return $pc->($env);
		} else {
			my $req = Plack::Request->new($env);
			my $uri = $req->uri;
			$uri->path('/m/');
			return [302, ['Location' => $uri->as_string], []];
		}
	};
};
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

	$self->write_file('tmpl/mobile/non_supported.tt', <<'...');
<!doctype html>
<html>
<head>
	<title><% dist %></title>
</head>
<body>
	<div>非対応端末です。</div>
	<hr />
	対応端末は以下のとおりです。
	<ul>
	<li>ソフトバンク: 3GC</li>
	<li>ドコモ: [% insecure_session ? 'FOMA' : 'ドコモブラウザー2.0以後' %]</li>
	<li>au: WIN</li>
	</ul>
</body>
</html>
...

	$self->write_file('t/01_mobile.t', <<'...');
use strict;
use warnings;
use utf8;
use Test::More;
use Plack::Test;
use Plack::Util;
use t::Util;

my $app = Plack::Util::load_psgi('mobile.psgi');
test_psgi(
	app => $app,
	client => sub {
		my $cb = shift;
		{
			my $req = HTTP::Request->new('GET', '/');
			$req->header('User-Agent' => 'KDDI-CA21 UP.Browser/6.0.6 (GUI) MMP/1.1');
			my $res = $cb->($req);
			is($res->code(), 200) or diag $res->content;
			like($res->decoded_content, qr{EZweb});
			like($res->decoded_content, qr{ﾓﾊﾞｲﾙ}, '半角カタカナフィルタ');
		}
		for my $ua (
			'DoCoMo/1.0/633S/c20',
			'libwww-perl/6.02',
		) {
			subtest $ua =>sub {
				my $req = HTTP::Request->new('GET', '/');
				my $res = $cb->($req);
				is($res->code(), 302) or diag $res->content;
				like($res->header('Location'), qr{/non_supported$});
				my $req2 = HTTP::Request->new('GET' => $res->header('Location'));
				my $res2 = $cb->($req2);
				is($res2->code, 200) or diag $res->as_string;
				like($res2->decoded_content, qr{非対応});
			};
		}
	},
);
done_testing;

...

	$self->write_file('t/05_routing_mobile.t', <<'...');
use strict;
use warnings;
use utf8;
use Test::More;
use Plack::Test;
use Plack::Util;
use t::Util;
use LWP::Protocol::PSGI;
use LWP::UserAgent;

my $app = Plack::Util::load_psgi('app.psgi');
LWP::Protocol::PSGI->register($app);

subtest 'pc browser' => sub {
	my $ua = LWP::UserAgent->new(max_redirect => 0);

	subtest 'cannnot see mobile page' => sub {
		my $res = $ua->get('http://localhost/m/');
		is($res->code, 302) or diag $res->as_string;
		is($res->header('Location'), 'http://localhost/');
	};
	subtest 'can see pc page' => sub {
		my $res = $ua->get('http://localhost/');
		is($res->code, 200) or diag substr($res->as_string, 0, 512);
	};
};

subtest 'mobile browser' => sub {
    my $ua = LWP::UserAgent->new(
        max_redirect => 0,
        agent        => 'KDDI-CA21 UP.Browser/6.0.6 (GUI) MMP/1.1'
    );
	subtest 'cannnot see pc page' => sub {
		my $res = $ua->get('http://localhost/');
		is($res->code, 302) or diag substr($res->as_string, 0, 512);
		is($res->header('Location'), 'http://localhost/m/');
	};
	subtest 'can see mobile page' => sub {
		my $res = $ua->get('http://localhost/m/');
		is($res->code, 200) or diag substr($res->as_string, 0, 512);
	};
};

done_testing;
...

	$self->write_file('t/00_compile_mobile.t', <<'...');
use strict;
use warnings;
use Test::More;

use_ok($_) for qw(
	<% $module %>::Mobile
	<% $module %>::Mobile::Dispatcher
	<% $module %>::Mobile::C::Root
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
			'Encode::JP::Mobile' => '0.29',
			'HTTP::Session::Store::DBI' => '0.02',
			'HTTP::Session' => 0,
			'Amon2::Plugin::Web::HTTPSession' => 0,
			'LWP::Protocol::PSGI' => 0,
			'LWP::UserAgent' => 6,
        },
    );
}

1;
__END__

=for stopwords MobileJP

=encoding utf8

=head1 NAME

Amon2::Setup::Flavor::MobileJP - MobileJP flavor for Amon2

=head1 DESCRIPTION

ガラケーサイト向けのフレーバーです。普通のガラケーサイトで欲しいなあ、とおもうような機能はあらかじめ実装したコードが生成されるようになっています。

このフレーバーは、Large フレーバーをベースにしています。

