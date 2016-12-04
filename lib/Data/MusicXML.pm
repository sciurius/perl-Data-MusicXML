#! perl

package Data::MusicXML;

use warnings;
use strict;
use Carp qw( carp croak );

use XML::LibXML;
use DDumper;
use Encode qw( decode_utf8 encode_utf8 );

=head1 NAME

Data::MusicXML - Framework for parsing MusicXML

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Data::MusicXML;

    my $foo = Data::MusicXML->new();
    ...

=cut

sub new {
    my ( $pkg, $options ) = @_;

    my $self = bless( { }, $pkg );

    for ( qw( catalog trace debug verbose ) ) {
	$self->{$_} = $options->{$_} if exists $options->{$_};
    }

    return $self;
}

sub processfiles {
    my ( $self, @files ) = @_;
    foreach ( @files ) {
	$self->processfile($_);
    }
}

# Process a subtree, identified by $key.
sub _process {
    my ( $self, $data, $key, $handler, $ctx ) = @_;

    my @nodes = $data->findnodes( "./$key" );
    warn("No $key nodes found\n"), return unless @nodes;

    my $ix = 0;
    foreach ( @nodes ) {

	# Establish context and link in parent context, if any.
	my $c = $self->{_ctx}->{$key} =
	  { path => join("/", $ctx->{path}, $key) };
	$c->{_parent} = $ctx if $ctx;

	$handler->( $self, $ix+1, $_, $c );

	$ix++;
    }
}

sub processfile {
    my ( $self, $file ) = @_;

    croak( decode_utf8($file) . ": $!" ) unless -r $file;
    my $parser = XML::LibXML->new;
#    $parser->load_catalog( $self->{catalog} );
    $parser->set_options( { no_cdata => 1 } );
    my $data = $parser->parse_file($file);

    # <score-partwise>
    #   <work>
    #      <work-title>Yellow Dog Blues</work-title>
    #   </work>
    #   <movement-title>Yellow Dog Blues</movement-title>
    #   <identification>
    #     <encoding>
    #        <software>MuseScore 2.0.3</software>
    #        ...
    #     </encoding>
    #   </identification>
    #   <defaults ... />
    #   <credit page="1" ... />
    #   <credit page="1" ... />
    #   <part-list>
    #      <score-part id="P1" ... />
    #   </part-list>
    #   <part id="P1" ... />
    # </score-partwise>

    # print DDumper($data);

    my $root = "/score-partwise";

    if ( my $d = $data->findnodes( "$root/identification/encoding/software" ) ) {
	$self->{kludge} = 'irealpro'
	  if $d->[0]->to_literal =~ /^iReal Pro/;
    }

    if ( my $d = $data->findnodes( "$root/movement-title" ) ) {
	printf STDERR ( "Title: %s\n",
			decode_utf8($d->[0]->to_literal) );
    }
    if ( my $d = $data->findnodes( "$root/work/work-title" ) ) {
	printf STDERR ( "Title: %s\n",
			decode_utf8($d->[0]->to_literal) );
    }
    $self->_process( $data->findnodes($root)->[0], "part", \&process_part,
		     { path => $root } );
}

sub process_part {
    my ( $self, $part, $data, $ctx ) = @_;

    # <part id="P1">
    #   <measure ... />
    # </part>

    warn( "Part $part: ",
	  decode_utf8( $data->fn('@id')->[0]->to_literal ), "\n");

    # print DDumper($data);

    $self->{irp} = "";
    $self->_process( $data, "measure", \&process_measure, $ctx );

    $self->{irp} .= " Z ";
    $self->{irp} =~ s/([[:alnum:]]+)\s+([[:alnum:]])/$1, $2/g;
    warn( "===IRP===\n");
    print(
	  "Song: Dummy (Testing)\n",
	  "Style: Medium Swing (Jazz-Even 8ths); key: G-; tempo: 138; repeat: 3\n",
	  "\n",
	  $self->{irp}, "\n" );
}

sub process_measure {
    my ( $self, $measure, $data, $ctx ) = @_;

    # <measure number="24">
    #   <direction ... />
    #   <note ... />
    #   <harmony ... />
    #   <barline ... />
    # </measure>

    use Data::MusicXML::Data qw( @clefs );

    $self->{irp} .= " |";
    my $mark = "";
    foreach ( @{ $data->findnodes("./direction/direction-type/rehearsal") } ) {
	$mark = $_->to_literal;
	chop($self->{irp});
	chop($self->{irp});
	$self->{irp} =~ s;\|$;\];;
	$self->{irp} .= "[*" . $mark;
    }

    my $clef = "";
    my $mode = "major";
    foreach ( @{ $data->findnodes("./attributes/key/*") } ) {
	if ( $_->nodeName eq "fifths" ) {
	    $clef = $clefs[$_->to_literal];
	}
	if ( $_->nodeName eq "mode" ) {
	    $mode = $_->to_literal;
	}
    }

    printf STDERR ( "Measure %2d: \"%s\" %s%s %s\n",
		    $measure,
		    $data->fn('@number')->[0]->to_literal,
		    $mark ? "[$mark] " : "",
		    $clef ? ( $clef, $mode ) : ( "", "" ),
		  );
    # warn DDumper($data);

    if ( my $d = $data->fn('sound/tempo') ) {
	$ctx->{tempo} = $d->[0]->to_literal;
	$ctx->{_parent}->{tempo} = $ctx->{tempo};
	print STDERR ( " Tempo: ", $ctx->{tempo}, "\n" );
    }
    else {
	$ctx->{tempo} = $ctx->{_parent}->{tempo};
    }

    if ( my $d = $data->fn('attributes/time/*') ) {
	foreach ( @$d ) {
	    $ctx->{_parent}->{beats} = $ctx->{beats} = $_->to_literal
	      if $_->nodeName eq "beats";
	    $ctx->{_parent}->{'beat_type'} = $ctx->{'beat_type'} = $_->to_literal
	      if $_->nodeName eq "beat-type";
	}
	print STDERR ( " Beats: ",
		       $ctx->{beats}, "/", $ctx->{'beat_type'},
		       "\n" );
	$self->{irp} .= " T" . $ctx->{beats} . $ctx->{'beat_type'},
    }
    else {
	$ctx->{beats} = $ctx->{_parent}->{beats};
	$ctx->{'beat_type'} = $ctx->{_parent}->{'beat_type'};
    }

    if ( my $d = $data->fn('attributes/staves') ) {
	$ctx->{staves} = $d->[0]->to_literal;
    }

    if ( my $d = $data->fn('attributes/divisions') ) {
	$ctx->{_parent}->{divisions} =
	$ctx->{divisions} = $d->[0]->to_literal;
	print STDERR ( " Divisions: ", $ctx->{divisions}, "\n" );
    }
    else {
	$ctx->{divisions} = $ctx->{_parent}->{divisions};
    }

    # Process note and harmony nodes, in order.
    my ( $n, $h );
    $ctx->{currentbeat} = 0;
    my @chords = ( "_" ) x $ctx->{beats};
    foreach ( @{ $data->fn('note | ./harmony') } ) {
	print STDERR ("== beat: ", $ctx->{currentbeat}, "\n" );
	$self->process_note( ++$n, $_, $ctx )
	  if $_->nodeName eq "note";
	if ( $_->nodeName eq "harmony" ) {
	    $chords[$ctx->{currentbeat}] =
	      $self->process_harmony( ++$h, $_, $ctx );
	}
    }
    $self->{irp} .= " @chords";
}

sub process_note {
    my ( $self, $note, $data, $ctx ) = @_;

    use Data::MusicXML::Data qw( %durations );

    # Duration, in beats.
    my $duration = $data->fn('duration')->[0]->to_literal
      / $ctx->{divisions};
    # Duration is the actual duration, dots included.
    # $duration *= 1.5 if $data->fn('dot');

    my $root;

    if ( my $d = $data->fn('pitch') ) {
	$root = $d->[0]->fn('step')->[0]->to_literal;
	foreach ( @{ $d->[0]->fn('alter') } ) {
	    $root .= 'b' if $_->to_literal < 0;
	    $root .= '#' if $_->to_literal > 0;
	}
	if ( my $d = $d->[0]->fn('octave') ) {
	    $root .= $d->[0]->to_literal;
	}
    }
    elsif ( $data->fn('rest') ) {
	$root = 'rest';
    }

    printf STDERR ("Note %3d: %s %s x=%d d=%.2f s=%d\n",
		   $note,
		   $root,
		   $data->fn('type')->[0]->to_literal,
		   eval { $data->fn('default-x')->[0]->to_literal } || 0,
		   $duration,
		   eval { $data->fn('staff')->[0]->to_literal } || 1,
		   );

    $ctx->{currentbeat} += $duration
      unless $data->fn('chord');
}

sub process_harmony {
    my ( $self, $harmony, $data, $ctx ) = @_;

#    warn DDumper($data);

    my $root = $data->fn('root/root-step')->[0]->to_literal;
    foreach ( @{ $data->fn('root/root-alter') } ) {
	$root .= 'b' if $_->to_literal < 0;
	$root .= '#' if $_->to_literal > 0;
    }

    my $quality = "";
    my $tquality = $data->fn('kind')->[0]->to_literal;
    if ( my $d = $data->fn('kind/@text') ) {
	$quality = $d->[0]->to_literal;
    }
    else {
	$quality = $tquality unless $tquality eq 'major';
    }

    printf STDERR ( "Harm %3d: %s%s %s\n",
		    $harmony, $root, $quality, $tquality );

    $quality =~ s/dim/o/;
    $quality =~ s/^m(?!a)/-/;
    return $root . $quality;

}

sub XML::LibXML::Node::fn {
    $_[0]->findnodes( './' . $_[1] );
}

=head1 AUTHOR

Johan Vromans, C<< <JV at CPAN dot org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-musicxml at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-MusicXML>. I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::MusicXML

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-MusicXML>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-MusicXML>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2016 Johan Vromans, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Data::MusicXML
