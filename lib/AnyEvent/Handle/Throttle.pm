package AnyEvent::Handle::Throttle;
{
    use strict;
    use warnings;
    use AnyEvent;
    use Errno qw[EAGAIN EINTR];
    use AnyEvent::Util qw[WSAEWOULDBLOCK];
    use parent 'AnyEvent::Handle';
    our $MAJOR = 0.00; our $MINOR = 1; our $DEV = 0; our $VERSION = sprintf('%1.3f%03d' . ($DEV ? (($DEV < 0 ? '' : '_') . '%03d') : ('')), $MAJOR, $MINOR, abs $DEV);

    sub upload_rate {
        $_[1] ? $_[0]->{upload_rate} = $_[1] : $_[0]->{upload_rate};
    }

    sub download_rate {
        $_[1] ? $_[0]->{download_rate} = $_[1] : $_[0]->{download_rate};
    }
    sub upload_period   { $_[0]->{upload_period} }
    sub download_period { $_[0]->{download_period} }

    sub _start {
        my $self = shift;
        $self->SUPER::_start(@_);
        my $reset = sub {
            $self->{read_size}       = $self->{download_rate};
            $self->{write_size}      = $self->{upload_rate} || 8 * 1024;
            $self->{upload_period}   = $self->{_upload_period};
            $self->{download_period} = $self->{_download_period};
            $self->{_upload_period}  = $self->{_download_period} = 0;
        };
        $self->{_period} ||= 1;
        $self->{_reset} = AE::timer(0, $self->{_period}, $reset);
        $reset->();
    }

    sub start_read {
        my ($self) = @_;
        unless ($self->{_rw} || $self->{_eof} || !$self->{fh}) {
            Scalar::Util::weaken $self;
            $self->{_rw} = AE::io $self->{fh}, 0, sub {
                my $_read
                    = defined $self->{download_rate}
                    && defined $self->{read_size}
                    ? $self->{read_size}
                    : $self->{rbuf_max};
                if (!$_read) {
                    $self->stop_read;
                    return $self->{_pause_read} = AE::timer(
                        0.5, 0,
                        sub {
                            delete $self->{_pause_read};
                            $self->start_read;
                        }
                    );
                }
                my $rbuf = \($self->{tls} ? my $buf : $self->{rbuf});
                $$rbuf ||= '';
                my $len = sysread $self->{fh}, $$rbuf, $_read, length $$rbuf;
                if ($len > 0) {
                    $self->{read_size} -= $len;
                    $self->{_download_period} += $len;
                    $self->{_activity} = $self->{_ractivity} = AE::now;
                    if ($self->{tls}) {
                        Net::SSLeay::BIO_write($self->{_rbio}, $$rbuf);
                        &_dotls($self);
                    }
                    else {
                        $self->_drain_rbuf;
                    }
                }
                elsif (defined $len) {
                    delete $self->{_rw};
                    $self->{_eof} = 1;
                    $self->_drain_rbuf;
                }
                elsif ($! != EAGAIN && $! != EINTR && $! != WSAEWOULDBLOCK) {
                    return $self->_error($!, 1);
                }
            };
        }
    }

    sub _drain_wbuf {
        my ($self) = @_;
        if (!$self->{_ww} && length $self->{wbuf}) {
            Scalar::Util::weaken $self;
            my $cb;
            my $poll = sub {
                $self->{_ww} = AE::io $self->{fh}, 1, $cb
                    if length $self->{wbuf};
            };
            $cb = sub {
                if (!$self->{write_size}) {
                    if (length $self->{wbuf}) {
                        delete $self->{_ww};
                        return $self->{_pause_ww} = AE::timer(
                            0.5, 0,
                            sub {
                                delete $self->{_pause_write};
                                $poll->();
                            }
                        );
                    }
                    return 1;
                }
                my $len = syswrite $self->{fh}, $self->{wbuf},
                    $self->{write_size};
                if (defined $len) {
                    $self->{write_size} -= $len;
                    $self->{_upload_period} += $len;
                    substr $self->{wbuf}, 0, $len, "";
                    $self->{_activity} = $self->{_wactivity} = AE::now;
                    $self->{on_drain}($self)
                        if $self->{low_water_mark}
                            || 0 >= length($self->{wbuf} || '')
                            + length($self->{_tls_wbuf}  || '')
                            && $self->{on_drain};
                    delete $self->{_ww} unless length $self->{wbuf};
                }
                elsif ($! != EAGAIN && $! != EINTR && $! != WSAEWOULDBLOCK) {
                    $self->_error($!, 1);
                }
            };

            # try to write data immediately
            $cb->() unless $self->{autocork};
            $poll->();
        }
    }
}
1;

=pod

=head1 NAME

AnyEvent::Handle::Throttle - AnyEvent::Handle subclass with user-defined up/down bandwidth cap

=head1 Synopsis

    use AnyEvent;
    use AnyEvent::Handle::Throttle;
    my $condvar = AnyEvent->condvar;
    my $handle;
    $handle = AnyEvent::Handle::Throttle->new(
        upload_rate   => 2,  # Very...
        download_rate => 50, # ...slow
        connect  => ['google.com', 'http'],
        on_error => sub {
            warn "error $_[2]\n";
            $_[0]->destroy;
            $condvar->send;
        },
        on_eof => sub {
            $handle->destroy;
            warn "done.\n";
            $condvar->send;
        }
    );
    $handle->push_write("GET / HTTP/1.0\015\012\015\012");
    $handle->push_read(
        line => "\015\012\015\012",
        sub {
            my ($handle, $line) = @_;
            print "HEADER\n$line\n\nBODY\n";
            $handle->on_read(sub { print $_[0]->rbuf; $_[0]->rbuf = ''; });
        }
    );
    $condvar->recv;

=head1 Description

This class adds a (nearly too) simple throughput limiter to
L<AnyEvent::Handle|AnyEvent::Handle>.

=head1 Methods

In addition to L<AnyEvent::Handle|AnyEvent::Handle>'s base methods, this
subclass supports the following...

=over

=item $handle = AnyEvent::Handle::Throttle->B<new>( key => value, ... )

In addition to the arguments handled by
L<< C<<< AnyEvent::Handle->new( ... ) >>>|AnyEvent::Handle >>, this
constructor supports these arguments (all as C<< key => value >> pairs).

=over

=item upload_rate => <bytes>

This is the maximum amount of data (in bytes) writen to the filehandle per
period. If C<upload_rate> is not specified, the upload rate is not limited.

Note that this value can/will override C<read_size>.

=item download_rate => <bytes>

This is the maximum amount of data (in bytes) read from the filehandle per
period. If C<download_rate> is not specified, the upload rate is not limited.

=back

=item $handle->B<upload_rate>( $bytes )

Sets/returns the current upload rate in bytes per period.

=item $handle->B<download_rate>( $bytes )

Sets/returns the current download rate in bytes per period.

=item $bytes = $handle->B<upload_period>( )

Returns the amount of data written during the previous period.

=item $bytes = $handle->B<download_period>( )

Returns the amount of data read during the previous period.

=back

=head1 Notes

=over

=item *

The current default period is C<1> second.

=item *

On destuction, all remaining data is sent ASAP, ignoring the user defined
upload limit. This may change in the future.

=back

=head1 Bugs

I'm sure this module is just burting with 'em. When you stumble upon on,
please report it via the
L<Issue Tracker|http://github.com/sanko/anyevent-handle-bandwidth/issues>.

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
