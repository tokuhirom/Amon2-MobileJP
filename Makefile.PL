use inc::Module::Install;
use Module::Install::AuthorTests;

name 'Amon2-Plugin-Web-MobileAgent';
all_from 'lib/Amon2/Plugin/Web/MobileAgent.pm';

requires 'Amon2' => 3.00;
requires 'HTTP::MobileAgent';
requires 'HTTP::MobileAgent::Plugin::Charset';
requires 'Encode::JP::Mobile';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More' => 0.98; # done_testing, subtest
author_tests('xt');
WriteAll;
