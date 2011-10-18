use inc::Module::Install;
use Module::Install::AuthorTests;

name 'Amon2-MobileJP';
all_from 'lib/Amon2/Plugin/Web/MobileAgent.pm';
abstract 'MobileJP things for Amon2';

requires 'Amon2' => '3.03';
requires 'HTTP::MobileAgent';
requires 'HTTP::MobileAgent::Plugin::Charset';
requires 'Encode::JP::Mobile';
requires 'Lingua::JA::Regular::Unicode';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More' => 0.98; # done_testing, subtest
author_tests('xt');
WriteAll;
