#! perl

use strict;
use warnings;
use utf8;
use Carp;

package Data::MusicXML::iRealPro;

our $VERSION = "0.01";

sub to_irealpro {
    my ( $self, $song, $part ) = @_;

    print( "\n" ) if $part+$song->{index};
    print( "Song ", 1+$part+$song->{index}, ": ",
	   $song->{title}, " (", $song->{composer}, ")\n",
	   "Style: Medium Swing;",
	   " key: ", $song->{key}, ";",
	   " tempo: ", $song->{tempo}, ";",
	   " repeat: 1\n",
	   "\n" );

    $part = $song->{parts}->[$part];
    my $irp = "";

    foreach my $s ( @{ $part->{sections} } ) {
	if ( $s->{mark} ) {
	    $irp .= '[*' . $s->{mark};
	}
	else {
	    $irp .= "[";
	}

	if ( $s->{time} ) {
	    $irp .= " T" . timesig( $s->{time} );
	}

	my $i = 0;
	foreach my $m ( @{ $s->{measures} } ) {
	    $irp .= " " . join(" ", map { irpchord($_) } @{ $m->{chords} }) . " |";
	    if ( ( $i +=  @{ $m->{chords} } ) >= 16 ) {
		$irp .= "\n|";
		$i = 0;
	    }
	}
	$irp =~ s/ \|(\n\|)?$//;
        $irp .= " ]\n";
    }

    # Make sure alpha items (chords) are separated by commas if necessary.
    $irp =~ s/([[:alnum:]]+)\s+([[:alnum:]])/$1, $2/g;
    $irp =~ s/([[:alnum:]]+)\s+([[:alnum:]])/$1, $2/g;

    # Add end bar.
    # $irp =~ s/\n$/ Z /;

    print( $irp, "\n" );
}

################ Chords ################

my %harmony_kinds =
  (
    # Triads.
    major		  => "",
    minor		  => "-",
    augmented		  => "+",
    diminished		  => "o",

    # Sevenths.
    dominant		  => "7",
    'major-seventh'	  => "^7",
    'minor-seventh'	  => "-7",
    'diminished-seventh'  => "o7",
    'augmented-seventh'	  => "+7",
    'half-diminished'	  => "h",
    'major-minor'	  => "-^7",

    # Sixths.
    'major-sixth'	  => "6",
    'minor-sixth'	  => "-6",

    # Ninths.
    'dominant-ninth'	  => "9",
    'major-ninth'	  => "^9",
    'minor-ninth'	  => "-9",

    # 11ths.
    'dominant-11th'	  => "11",
    'major-11th'	  => "^11",
    'minor-11th'	  => "-11",

    # 13ths.
    'dominant-13th'	  => "13",
    'major-13th'	  => "^13",
    'minor-13th'	  => "-13",

    # Suspended.
    'suspended-second'	  => "sus2",
    'suspended-fourth'	  => "sus4",

  );

my %chordqual =
  (  ""			=> '',
     "+"		=> 'p',
     "-"		=> 'm',
     "-#5"		=> 'mx5',
     "-11"		=> 'm11',
     "-6"		=> 'm6',
     "-69"		=> 'm69',
     "-7"		=> 'm7',
     "-7b5"		=> 'm7b5',
     "-9"		=> 'm9',
     "-^7"		=> 'mv7',
     "-^9"		=> 'mv9',
     "-b6"		=> 'mb6',
     "11"		=> '11',
     "13"		=> '13',
     "13#11"		=> '13x11',
     "13#9"		=> '13x9',
     "13b9"		=> '13b9',
     "13sus"		=> '13sus',
     "2"		=> '2',
     "5"		=> '5',
     "6"		=> '6',
     "69"		=> '69',
     "7"		=> '7',
     "7#11"		=> '7x11',
     "7#5"		=> '7x5',
     "7#9"		=> '7x9',
     "7#9#11"		=> '7x9x11',
     "7#9#5"		=> '7x9x5',
     "7#9b5"		=> '7x9b5',
     "7alt"		=> '7alt',
     "7b13"		=> '7b13',
     "7b13sus"		=> '7b13sus',
     "7b5"		=> '7b5',
     "7b9"		=> '7b9',
     "7b9#11"		=> '7b9x11',
     "7b9#5"		=> '7b9x5',
     "7b9#9"		=> '7b9x9',
     "7b9b13"		=> '7b9b13',
     "7b9b5"		=> '7b9b5',
     "7b9sus"		=> '7b9sus',
     "7sus"		=> '7sus',
     "7susadd3"		=> '7susadd3',
     "9"		=> '9',
     "9#11"		=> '9x11',
     "9#5"		=> '9x5',
     "9b5"		=> '9b5',
     "9sus"		=> '9sus',
     "^"		=> 'v',
     "^13"		=> 'v13',
     "^7"		=> 'v7',
     "^7#11"		=> 'v7x11',
     "^7#5"		=> 'v7x5',
     "^9"		=> 'v9',
     "^9#11"		=> 'v9x11',
     "add9"		=> 'add9',
     "alt"		=> '7alt',
     "h"		=> 'h',
     "h7"		=> 'h7',
     "h9"		=> 'h9',
     "o"		=> 'o',
     "o7"		=> 'o7',
     "sus"		=> 'sus',
  );

sub irpchord {
    my ( $c ) = @_;
    return $c unless ref($c) eq 'ARRAY';
    my ( $root, $quality, $text, $degree ) = @$c;
    if ( exists $harmony_kinds{$quality} ) {
	$text = $harmony_kinds{$quality};
    }
    else {
	$text = "?";
    }

    $degree ||= [];

    foreach ( @$degree ) {
	my ( $value, $alter, $type ) = @$_;
	next unless $type eq 'add' || $type eq 'alter';
	$text .= 'b' if $alter < 0;
	$text .= '#' if $alter > 0;
	$text .= $value;
    }

    return $root . $text if exists $chordqual{$text};
    return $root . '*' . $text . '*';
}

################ Time Signatures ################

my $_sigs;

sub timesig {
    my ( $time ) = @_;
    $_sigs ||= { "2/2" => "22",
		 "3/2" => "32",
		 "2/4" => "24",
		 "3/4" => "34",
		 "4/4" => "44",
		 "5/4" => "54",
		 "6/4" => "64",
		 "7/4" => "74",
		 "2/8" => "28",
		 "3/8" => "38",
		 "4/8" => "48",
		 "5/8" => "58",
		 "6/8" => "68",
		 "7/8" => "78",
		 "9/8" => "98",
		"12/8" => "12",
	       };

    $_sigs->{ $time }
      || Carp::croak("Invalid time signature: $time");
}

1;
