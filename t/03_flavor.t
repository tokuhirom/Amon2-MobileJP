use strict;
use warnings;
use utf8;
use Test::More;
use t::TestFlavor;
use Test::Requires 'DBI';

test_flavor(sub {
}, 'MobileJP');

done_testing;

