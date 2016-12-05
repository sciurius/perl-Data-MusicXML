#!/usr/bin/perl

# parse -- parse MusicXML song data

# Author          : Johan Vromans
# Created On      : Thu Dec  1 20:15:22 2016
# Last Modified By: Johan Vromans
# Last Modified On: Sun Dec  4 17:14:44 2016
# Update Count    : 7
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../CPAN";
use lib "$FindBin::Bin/../lib";
use Data::MusicXML;

################ Setup  ################

# Process command line options, config files, and such.
my $options;
$options = app_setup( "parse", $Data::MusicXML::VERSION );

################ Presets ################

$options->{catalog} = "$FindBin::Bin/../res/catalog.xml";
$options->{trace} = 1   if $options->{debug};
$options->{verbose} = 1 if $options->{trace};

################ Activate ################

main($options);

################ The Process ################

sub main {
    my ($options) = @_;
    binmode(STDERR,':utf8');
    Data::MusicXML->new($options)->processfiles(@ARGV);
}

################ Options and Configuration ################

use Getopt::Long 2.13 qw( :config no_ignorecase );
use File::Spec;
use Carp;

# Package name.
my $my_package;
# Program name and version.
my ($my_name, $my_version);
my %configs;

sub app_setup {
    my ($appname, $appversion, %args) = @_;
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    # Package name.
    $my_package = $args{package};
    # Program name and version.
    if ( defined $appname ) {
	($my_name, $my_version) = ($appname, $appversion);
    }
    else {
	($my_name, $my_version) = qw( MyProg 0.01 );
    }

    my $options =
      {
       verbose		=> 0,		# verbose processing

       ### ADD OPTIONS HERE ###

       catalog		=> undef,

       # Development options (not shown with -help).
       debug		=> 0,		# debugging
       trace		=> 0,		# trace (show process)

       # Service.
       _package		=> $my_package,
       _name		=> $my_name,
       _version		=> $my_version,
       _stdin		=> \*STDIN,
       _stdout		=> \*STDOUT,
       _stderr		=> \*STDERR,
       _argv		=> [ @ARGV ],
      };

    # Colled command line options in a hash, for they will be needed
    # later.
    my $clo = {};

    # Sorry, layout is a bit ugly...
    if ( !GetOptions
	 ($clo,

	  ### ADD OPTIONS HERE ###

	  'catalog=s',

	  # Standard options.
	  'ident'		=> \$ident,
	  'help|h|?'		=> \$help,
	  'man'			=> \$man,
	  'verbose',
	  'trace',
	  'debug',
	 ) )
    {
	# GNU convention: message to STDERR upon failure.
	$pod2usage->(2);
    }
    # GNU convention: message to STDOUT upon request.
    $pod2usage->(1) if $help;
    $pod2usage->( VERBOSE => 2 ) if $man;
    app_ident(\*STDOUT) if $ident;

    $pod2usage->(2) unless @ARGV;

    # Plug in command-line options.
    @{$options}{keys %$clo} = values %$clo;

    $options;
}

sub app_ident {
    my ($fh) = @_;
    print {$fh} ("This is ",
		 $my_package
		 ? "$my_package [$my_name $my_version]"
		 : "$my_name version $my_version",
		 "\n");
}

1;

__END__

################ Documentation ################

=head1 NAME

parse - parse MusicXML data

=head1 SYNOPSIS

parse [options] file [...]

 Options:

    --catalog=XXX	LibXML catalog.

Miscellaneous options:

    --help  -h		this message
    --man		full documentation
    --ident		show identification
    --verbose		verbose information

=head1 DESCRIPTION

This program will read the given input file(s) and parse them.

=head1 OPTIONS

=over 8

=item B<--catalog=>I<XXX>

Specifies the catalog to use. See the libxml documentation.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.

=item I<file>

The input file(s) to process.

=back

=head1 AUTHOR

Johan Vromans, C<< <jv at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-musicxml at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-MusicXML>. I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this program with the perldoc command.

    perldoc 

=head1 COPYRIGHT & LICENSE

Copyright 2016 Johan Vromans, all rights reserved.

Clone me at L<GitHub|https://github.com/sciurius/perl-Data-MusicXML>

=cut
