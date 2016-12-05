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

our $VERSION = '0.03';

=head1 SYNOPSIS

    use Data::MusicXML;

    my $p = Data::MusicXML->new();
    $p->processfile('Yellow_Dog_Blues.xml');

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
    $self->{songix} = 0;
    foreach ( @files ) {
	$self->processfile($_);
	$self->{songix}++;
    }
}

# Process a subtree, identified by $key.
sub _process {
    my ( $self, $data, $key, $handler, $ctx ) = @_;

    my @nodes = $data->fn($key);
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
    $parser->load_catalog( $self->{catalog} );
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
    my $rootnode = $data->findnodes($root)->[0];

    my $song = { title => 'NoName',
		 composer => 'NoBody',
		 key => 'C',
		 tempo => 100,
		 index => $self->{songix},
		 parts => [] };

    if ( my $d = $rootnode->fn1('movement-title') ) {
	$song->{title} = $song->{'movement-title'} = $d->to_literal;
	warn( "Title: ", decode_utf8($song->{title}), "\n" )
	  if $self->{debug};
    }
    if ( my $d = $rootnode->fn1('work/work-title') ) {
	$song->{title} = $song->{'work-title'} = $d->to_literal;
	warn( "Title: ", decode_utf8($song->{title}), "\n" )
	  if $self->{debug};
    }

    if ( my $d = $rootnode->fn1('identification/creator[@type=\'composer\']') ) {
	$song->{composer} = $d->to_literal;
	warn( "Composer: ", decode_utf8($song->{composer}), "\n" )
	  if $self->{debug};
    }

    $self->{song} = $song;

    $self->_process( $rootnode, "part", \&process_part,
		     { path => $root } );

    DDumper($song);

    use Data::MusicXML::iRealPro;
    for ( my $ix = 0; $ix < @{ $song->{parts} }; $ix++ ) {
	Data::MusicXML::iRealPro->to_irealpro( $song, $ix );
    }

}

sub process_part {
    my ( $self, $part, $data, $ctx ) = @_;

    # <part id="P1">
    #   <measure ... />
    # </part>

    my $this = {};
    push( @{ $self->{song}->{parts} }, $this );

    $this->{id} = $data->fn1('@id')->to_literal;
    warn( "Part $part: ", decode_utf8($this->{id}), "\n")
      if $self->{debug};

    # print DDumper($data);

    $this->{sections} = [];
    $self->_process( $data, "measure", \&process_measure, $ctx );

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

    my $this = $self->{song}->{parts}->[-1];

    use feature qw(state);
    state $lastchord;

    my $mark = "";
    foreach ( @{ $data->fn('direction/direction-type/rehearsal') } ) {
	$mark = $_->to_literal;
    }

    if ( $mark ) {
	push( @{ $this->{sections} },
	      { mark => $mark, measures => [] } );
    }
    elsif ( @{ $this->{sections} } == 0 ) {
	$this->{sections} = [ { measures => [] } ];
    }
    $this = $this->{sections}->[-1];

    my $clef = "";
    my $mode = "major";
    foreach ( @{ $data->fn('attributes/key/*') } ) {
	if ( $_->nodeName eq "fifths" ) {
	    $clef = $clefs[$_->to_literal];
	}
	if ( $_->nodeName eq "mode" ) {
	    $mode = $_->to_literal;
	}
    }

    printf STDERR ( "Measure %2d: \"%s\" %s%s %s\n",
		    $measure,
		    $data->fn1('@number')->to_literal,
		    $mark ? "[$mark] " : "",
		    $clef ? ( $clef, $mode ) : ( "", "" ),
		  )
      if $self->{debug};

    $clef .= "-" if $mode eq 'minor';
    $self->{song}->{key} ||= $clef;

    # warn DDumper($data);

    if ( my $d = $data->fn1('sound/tempo') ) {
	$ctx->{tempo} = $d->to_literal;
	$ctx->{_parent}->{tempo} = $ctx->{tempo};
	print STDERR ( " Tempo: ", $ctx->{tempo}, "\n" )
	  if $self->{debug};
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
		       "\n" ) if $self->{debug};
	$this->{time} = $ctx->{beats} ."/". $ctx->{'beat_type'};
    }
    else {
	$ctx->{beats} = $ctx->{_parent}->{beats};
	$ctx->{'beat_type'} = $ctx->{_parent}->{'beat_type'};
    }

    if ( my $d = $data->fn1('attributes/staves') ) {
	$ctx->{staves} = $d->to_literal;
    }

    if ( my $d = $data->fn1('attributes/divisions') ) {
	$ctx->{_parent}->{divisions} =
	$ctx->{divisions} = $d->to_literal;
	print STDERR ( " Divisions: ", $ctx->{divisions}, "\n" )
	  if $self->{debug};
    }
    else {
	$ctx->{divisions} = $ctx->{_parent}->{divisions};
    }

    # Process note and harmony nodes, in order.
    my ( $n, $h );
    $ctx->{currentbeat} = 0;
    my @chords = ( "_" ) x $ctx->{beats};
    foreach ( @{ $data->fn('note | ./harmony') } ) {
	print STDERR ("== beat: ", $ctx->{currentbeat}, "\n" )
	  if $self->{debug};
	$self->process_note( ++$n, $_, $ctx )
	  if $_->nodeName eq "note";
	if ( $_->nodeName eq "harmony" ) {
	    $chords[$ctx->{currentbeat}] =
	      $self->process_harmony( ++$h, $_, $ctx );
	}
    }

    if ( $chords[0] eq "_" && $lastchord ) {
	$chords[0] = $lastchord;
    }
    push( @{ $this->{measures} },
	  { number => $data->fn1('@number')->to_literal,
	    chords => [ @chords ] } );

    pop(@chords) while @chords && $chords[-1] eq "_";
    $lastchord = $chords[-1] if @chords;
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

    if ( my $d = $data->fn1('pitch') ) {
	$root = $d->fn('step')->[0]->to_literal;
	foreach ( @{ $d->fn('alter') } ) {
	    $root .= 'b' if $_->to_literal < 0;
	    $root .= '#' if $_->to_literal > 0;
	}
	if ( my $d = $d->fn1('octave') ) {
	    $root .= $d->to_literal;
	}
    }
    elsif ( $data->fn1('rest') ) {
	$root = 'rest';
    }

    printf STDERR ("Note %3d: %s %s x=%d d=%.2f s=%d\n",
		   $note,
		   $root,
		   $data->fn('type')->[0]->to_literal,
		   eval { $data->fn1('default-x')->to_literal } || 0,
		   $duration,
		   eval { $data->fn1('staff')->to_literal } || 1,
		  )
      if $self->{debug};

    $ctx->{currentbeat} += $duration
      unless $data->fn1('chord');
}

sub process_harmony {
    my ( $self, $harmony, $data, $ctx ) = @_;

#    warn DDumper($data);

    my $root = $data->fn1('root/root-step')->to_literal;
    foreach ( @{ $data->fn('root/root-alter') } ) {
	$root .= 'b' if $_->to_literal < 0;
	$root .= '#' if $_->to_literal > 0;
    }

    my $tquality = "";
    my $quality = $data->fn1('kind')->to_literal;
    if ( my $d = $data->fn1('kind/@text') ) {
	$tquality = $d->to_literal;
    }

    my @d;
    foreach ( @{ $data->fn('degree') } ) {
	push( @d, [ $_->fn1('degree-value')->to_literal,
		    $_->fn1('degree-alter')->to_literal,
		    $_->fn1('degree-type')->to_literal ] );
    }

    printf STDERR ( "Harm %3d: %s%s %s\n",
		    $harmony, $root, $quality, $tquality )
      if $self->{debug};

    return [ $root, $quality, $tquality, @d ? \@d : () ];

}


################ Convenience ################

# Convenient short for subnodes. Returns a nodelist.
sub XML::LibXML::Node::fn {
    $_[0]->findnodes( './' . $_[1] );
}

# Convenient short for single subnode. Returns a node.
sub XML::LibXML::Node::fn1 {
    my $nl = $_[0]->findnodes( './' . $_[1] . '[1]' );
    return unless $nl;
    $nl->[0];
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
