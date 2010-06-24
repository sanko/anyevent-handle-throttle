use strict;
use warnings;
use Config qw[%Config];
use File::Find qw[find];
$|++;
my $automated_testing = $ENV{AUTOMATED_TESTING} || $ENV{PERL_MM_USE_DEFAULT};
my $is_developer = ((-d '.git') ? 1 : 0) or ($ENV{RELEASE_TESTING} ? 1 : 0);
my @tests;
find \&find_cb, 't';
@tests = sort @tests;
my $class = ($is_developer ? 'inc::MBX::Developer' : 'Module::Build');

if (!eval "require $class") {
    printf 'Failed to load %s: %s This ain\'t good, so... bye!', $class, $@;
    exit 0;
}
my $mb = $class->new(
    module_name => 'AnyEvent::Handle::Throttle',
    license     => 'artistic_2',
    dist_author => 'Sanko Robinson <sanko@cpan.org>',
    requires    => {
                 'AnyEvent'      => 0,
                 'File::Find'    => 0,
                 'Module::Build' => 0.36,
                 parent          => 0,
                 perl            => 5.008000,
                 'Test::More'    => 0.88
    },
    build_requires => {'AnyEvent'      => 0,
                       'File::Find'    => 0,
                       'Module::Build' => 0.36,
                       parent          => 0,
                       perl            => 5.008000,
                       'Test::More'    => 0.88
    },
    add_to_cleanup => [
               qw[AnyEvent-Handle-Throttle-*],
               map {"*$_"} ('.' . $Config{'so'}, $Config{'_o'}, $Config{'_a'})
    ],
    no_index   => {directory => [qw[t example inc]]},
    test_files => \@tests,
    meta_merge => {
        generated_by => 'Conversion, software version 7.0',
        keywords =>
            [qw[AnyEvent Handle Throttle bandwidth limit cap throughput]],
        resources => {
            bugtracker => {
                web =>
                    'http://github.com/sanko/anyevent-handle-throttle/issues',
                mailto => 'sanko@cpan.org'
            },
            repository => {
                 url => 'git://github.com/sanko/anyevent-handle-throttle.git',
                 web => 'http://github.com/sanko/anyevent-handle-throttle',
                 type => 'git'
            },
            ChangeLog =>
                'http://github.com/sanko/anyevent-handle-throttle/commits/master',
            license => ['http://www.perlfoundation.org/artistic_license_2_0']
        }
    }
);
##################################################################### TODO ###
$mb->notes(automated_testing => $automated_testing ? 1 : 0);
$mb->notes(release_testing   => $is_developer);
$mb->notes(test_suite        => \@tests);
$mb->notes(gmtime            => scalar gmtime);
#################################### 'Dynamic' values used by build system ###
$mb->notes(svn => $mb->dist_version =~ m[\.0?(\d{4})]);
############################################################## Get to work ###
$mb->create_build_script;
##############################################################################
exit 0;

sub okay_tcp4 {
    return 0 if not -f 't/90000_data/94000_scripts/94004_TCP4_loopback.pl';
    system(qq["$^X" t/90000_data/94000_scripts/94004_TCP4_loopback.pl]);
    return $? ? 0 : 1;
}

sub find_cb {
    return if -d $_ or -l $_;
    return unless -T $_;
    return unless $_ =~ m[.+\.t$];
    return push @tests, $File::Find::name;
}

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
