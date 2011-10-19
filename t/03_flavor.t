use strict;
use warnings;
use utf8;
use Test::More;
use t::TestFlavor;
use Test::Requires 'DBI', 'Amon2::Plugin::DBI', 'LWP::Protocol::PSGI', 'HTML::FillInForm::Lite', 'HTTP::Session::State::Cookie', 'Plack::Middleware::ReverseProxy', 'Test::WWW::Mechanize::PSGI';

test_flavor(sub {
}, 'MobileJP');

done_testing;

