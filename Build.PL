use strict;
use warnings FATAL => 'all';
use Module::Build;

my $build = Module::Build->new(
    license              => 'perl',
    recursive_test_files => 1,
    dynamic_config       => 0,
    build_requires       => { 'Test::More' => '0.98' },
    configure_requires   => { 'Module::Build' => '0.38' },
    requires             => {
        'perl'                               => '5.8.1',
        'Lingua::JA::Regular::Unicode'       => '0',
        'HTTP::MobileAgent'                  => '0',
        'Encode::JP::Mobile'                 => '0.29',
        'Amon2'                              => '3.03',
        'HTTP::MobileAgent::Plugin::Charset' => '0'
    },
    no_index    => { 'directory' => [ 'inc', 't', 'xt' ] },
    name        => 'Amon2-MobileJP',
    module_name => 'Amon2::Plugin::Web::MobileAgent',

    test_files => ( -d '.git' || $ENV{RELEASE_TESTING} ) ? 't/ xt/' : 't/',

    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();
