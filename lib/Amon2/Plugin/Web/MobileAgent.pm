package Amon2::Plugin::Web::MobileAgent;
use strict;
use warnings;
use 5.008001;
our $VERSION = '0.03';

use HTTP::MobileAgent;

sub init {
    my ($class, $c, $conf) = @_;
    Amon2::Util::add_method(
        $c,
        'mobile_agent',
        sub {
            $_[0]->{mobile_agent} ||= HTTP::MobileAgent->new($_[0]->req->headers);
        }
    );
}

1;
__END__

=encoding utf8

=head1 NAME

Amon2::Plugin::Web::MobileAgent - HTTP::MobileAgent plugin for Amon2

=head1 SYNOPSIS

    package MyApp::Web;
    use parent qw/MyApp Amon2::Web/;
    __PACKAGE__->load_plugins('Web::MobileAgent');
    1;

    # in your controller
    $c->mobile_agent();

=head1 DESCRIPTION

This plugin integrates L<HTTP::MobileAgent> and L<Amon2>.

This module adds C<< $c->mobile_agent() >> method to the context object.
The agent class is generated by C<< $c->req >>.


=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF GMAIL COME<gt>

=head1 SEE ALSO

L<HTTP::MobileAgent>, L<Amon2>

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
