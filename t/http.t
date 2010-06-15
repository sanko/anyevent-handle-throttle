use strict;
use warnings;
use Test::More;
use AnyEvent::Impl::Perl;
use AnyEvent;
use lib '../lib';
use AnyEvent::Handle::Throttle;
$|++;
my $condvar = AnyEvent->condvar;
my ($handle, $rbuf, $prev, $chunks);
my $req = "GET / HTTP/1.0\015\012\015\012";
$handle = new_ok(
    'AnyEvent::Handle::Throttle',
    [upload_rate   => 2,
     download_rate => 1024,
     connect       => ['cpan.org', 'http'],
     on_prepare    => sub {15},
     on_connect    => sub { $prev = AE::now; },
     on_error      => sub {
         diag 'error ' . $_[2];
         $_[0]->destroy;
         $condvar->send;
     },
     on_eof => sub {
         $handle->destroy;
         note 'done';
         $condvar->send;
     },
     on_drain => sub {
         my $now = AE::now;
         my $expected = (
               int(length($req) / $handle->upload_rate) * $handle->{_period});
         ok( (($now - $prev) <= $expected)
                 && (($now - $prev + $handle->{_period}) >= $expected),
             sprintf 'Write queue is empty after %f seconds',
             $now - $prev
         );
         $prev = $now;
     },
     on_read => sub {
         my $now = AE::now;
         ok length $handle->rbuf <= $handle->download_rate,
             sprintf 'Chunk %d was %d bytes long...', ++$chunks,
             length $handle->rbuf;
         ok $now <= $prev + ($handle->{_period} * 2),
             sprintf ' ...and came %f seconds later', $now - $prev
             if $chunks > 1;
         $handle->rbuf() = '';
         $prev = $now;
         }
    ],
    '::Throttle->new( upload_rate => 20, download_rate => 50, ... )'
);
$handle->push_write($req);
$condvar->recv;
done_testing();

=pod

=head1 Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

=head1 License and Legal

Copyright (C) 2010 by Sanko Robinson <sanko@cpan.org>

This program is free software; you can redistribute it and/or modify it under
the terms of
L<The Artistic License 2.0|http://www.perlfoundation.org/artistic_license_2_0>.
See the F<LICENSE> file included with this distribution or
L<notes on the Artistic License 2.0|http://www.perlfoundation.org/artistic_2_0_notes>
for clarification.

When separated from the distribution, all original POD documentation is
covered by the
L<Creative Commons Attribution-Share Alike 3.0 License|http://creativecommons.org/licenses/by-sa/3.0/us/legalcode>.
See the
L<clarification of the CCA-SA3.0|http://creativecommons.org/licenses/by-sa/3.0/us/>.

=for rcs $Id$

=cut
