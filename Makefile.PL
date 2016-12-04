#! perl

# Ease the life of the CPAN testers.
exit 0 if $ENV{AUTOMATED_TESTING} && $] < 5.010000;

require 5.010;

use ExtUtils::MakeMaker;

my $master = 'lib/Data/MusicXML.pm';
my $version = MM->parse_version($master);

WriteMakefile
(
 NAME		=> 'Data::MusicXML',
 ABSTRACT_FROM  => $master,
 VERSION	=> "$version",
 AUTHOR	        => 'Johan Vromans <jvromans@squirrel.nl>',

 INSTALLDIRS	=> 'site',
 EXE_FILES	=> [ 'script/parse' ],
 PL_FILES	=> {
		    'script/pp.PL' => [ 'script/parse' ]
		   },

 PREREQ_PM      => {
		    'XML::LibXML'  => 2.0121,
		   },
 BUILD_REQUIRES  => {
		    'Test::More'   => 1.001014,
		   },

 MIN_PERL_VERSION => '5.010000',
 LICENSE => 'perl',
 META_MERGE => {
     'meta-spec' => { version => 2 },
     resources        => {
	 repository   => {
	     type => 'git',
	     url  => 'git://github.com/sciurius/perl-Data-MusicXML',
	     web  => 'https://github.com/sciurius/perl-Data-MusicXML',
         },
     },
 },

);

1;
