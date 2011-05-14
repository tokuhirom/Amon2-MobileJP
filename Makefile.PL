use inc::Module::Install;
use Module::Install::AuthorTests;

name 'Amon2-Plugin-Web-MobileAgent';
all_from 'lib/Amon2/Plugin/Web/MobileAgent.pm';

requires 'Amon2' => 2.33;
requires 'HTTP::MobileAgent';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More' => 0.96; # done_testing, subtest
author_tests('xt');
WriteAll;
