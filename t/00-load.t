#! perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Data::MusicXML' );
}

diag( "Testing Data::MusicXML $Data::MusicXML::VERSION, Perl $], $^X" );
