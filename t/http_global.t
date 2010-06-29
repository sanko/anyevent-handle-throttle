use strict;
use warnings;
use Test::More;
use AnyEvent::Impl::Perl;
use AnyEvent;
use lib '../lib';
use AnyEvent::Handle::Throttle;
$|++;
my $condvar = AnyEvent->condvar;
my ($prev, $chunks, $handle, $rbuf) = (AE::now, 0, undef, undef);
my $req = "GET / HTTP/1.0\015\012\015\012";
AnyEvent::Handle::Throttle->global_upload_limit(5);
AnyEvent::Handle::Throttle->global_download_limit(200);
TODO: {

    #local $TODO = 'May fail blah blah blah';
    $handle = new_ok(
        'AnyEvent::Handle::Throttle',
        [connect    => ['cpan.org', 80],
         on_prepare => sub          {15},
         on_connect => sub { $prev = AE::now; },
         on_error => sub {
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
                     int(length($req)
                             / AnyEvent::Handle::Throttle->global_upload_limit
                     )
             );
             diag sprintf 'Write queue is empty after %f seconds',
                 $now - $prev;
             $prev = $now;
         },
         on_read => sub {
             my $now = AE::now;
             ok length $handle->rbuf
                 <= AnyEvent::Handle::Throttle->global_download_limit,
                 sprintf 'Chunk %d was %d bytes long...', ++$chunks,
                 length $handle->rbuf;
             diag sprintf ' ...and came %f seconds later', $now - $prev
                 if $chunks > 1;
             $handle->rbuf() = '';
             $prev = $now;
             }
        ],
        '::Throttle->new( ... ); G_up: 5, G_down: 20'
    );
    $handle->push_write($req);
    $condvar->recv;
}
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
