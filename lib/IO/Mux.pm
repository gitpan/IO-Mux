package IO::Mux ;

use 5.008 ;
use strict ;
use Symbol ;
use IO::Mux::Handle ;
use IO::Mux::Packet ;
use IO::Mux::Buffer ;
use IO::Handle ;
use Carp ;


our $VERSION = '0.04' ;


sub new {
	my $class = shift ;
	my $fh = shift ;

	my $this = {} ;
	if (UNIVERSAL::isa($fh, 'GLOB')){
		# Make sure we save the actual IO bit, not the entire GLOB ref, because
		# une typical usage could be to place \*STDOUT in a IO::Mux object and then
		# do: *STDOUT = $mux. If wew save the GLOB ref, that will create infinite
		# recursion as the GLOB is deferenced each time to get the IO bit.
		$this->{'glob'} = $fh ;
		$fh = *{$fh}{IO} ;
	}
	$fh->autoflush(1) ;

	$this->{fh} = $fh ;
	$this->{buffers} = {} ;

	return bless($this, $class) ;
}


sub get_handle {
	my $this = shift ;

	return $this->{'glob'} || $this->{fh} ;
}


sub new_handle {
	my $this = shift ;

	return new IO::Mux::Handle($this) ;
}


sub get_buffer {
	my $this = shift ;
	my $id = shift ;

	if (! $this->buffer_exists($id)){
		$this->{buffers}->{$id} = new IO::Mux::Buffer() ; 
	}

	return $this->{buffers}->{$id} ;
}


sub buffer_exists {
	my $this = shift ;
	my $id = shift ;

	return defined($this->{buffers}->{$id}) ;
}


sub kill_buffer {
	my $this = shift ;
	my $id = shift ;

	delete $this->{buffers}->{$id} ;
}


sub read {
	my $this = shift ;
	my $id = shift ;

	my $p = undef ;
	while (! defined($p)){
		my $tp = $this->read_packet() ;
		if (! defined($tp)){
			return undef ;
		}
		elsif ($tp->get_id() eq $id){
			if (! $tp->is_eof()){
				$p = $tp ;
			}
			else {
				return 0 ;
			}
		}
	}

	return $p->get_length() ;
}


sub read_packet {
	my $this = shift ;

	my $p = IO::Mux::Packet->read($this->get_handle()) ;
	if (! defined($p)){
		return undef ;
	}
	elsif (! $p){
		return 0 ;
	}
	else {
		# Check for EOF packets
		if ($p->is_eof()){
			return $p ;
		}
		else {
			# Append the packet data to the correct buffer
			my $buf = $this->get_buffer($p->get_id()) ;
			$buf->push_packet($p) ;

			return $p ;
		}
	}
}


sub write {
	my $this = shift ;
	my $packet = shift ;

	return $packet->write($this->get_handle()) ;
}



1 ;
__END__
=head1 NAME

IO::Mux - Multiplex several virtual streams over a real pipe/socket

=head1 SYNOPSIS

  use IO::Mux ;

  pipe(R, W) ;

  if (fork){
      my $mux = new IO::Mux(\*W) ;
      my $alice = $mux->new_handle() ;
      open($alice, 'alice') ;
      my $bob = $mux->new_handle() ;
      open($bob, 'bob') ;

      print $alice "Hi Alice!\n" ;
      print $bob "Hi Bob!\n" ;
  }
  else {
      my $mux = new IO::Mux(\*R) ;
      my $alice = $mux->new_handle() ;
      open($alice, 'alice') ;
      my $bob = $mux->new_handle() ;
      open($bob, 'bob') ;

      print scalar(<$bob>) ;
      print scalar(<$alice>) ;
  }


=head1 DESCRIPTION

C<IO::Mux> allows you to multiplex sevaral virtual streams over a single pipe
or socket. This is achieved by creating an C<IO::Mux> object on each end of the 
real stream and then creating virtual handles (C<IO::Mux::Handle> objects) from
these C<IO::Mux> objects.

Each C<IO::Mux::Handle> object is assigned a unique identifier when opened, and 
C<IO::Mux::Handle> objects on each end of the real stream that have the same
identifier are "mapped" to each other.


=head1 CONSTRUCTOR

=over 4

=item new ( HANDLE )

Creates a new C<IO::Mux> object that multiplexes over HANDLE. C<autoflush> will
be turned on for HANDLE.

=back


=head1 METHODS

=over 4

=item $mux->get_handle ()

Returns the handle passed when $mux was created.

=item $mux->new_handle ()

Convenience method. Returns a new L<IO::Mux::Handle> object
created on $mux. Is equivalent to:

  new IO::Mux::Handle($mux) ;

The handle must then be opened before being used. See L<IO::Mux::Handle/open>
for more details.

=back


=head1 NOTE

Once a handle has been passed to an C<IO::Mux> object, it is important that 
it is not written to/read from directly as this will corrupt the C<IO::Mux> stream.

Once the C<IO::Mux> objects on both ends of the stream are out of scope (and have no data pending), normal usage of the handleis can resume.


=head1 SEE ALSO

L<IO::Mux::Handle>

=head1 AUTHOR

Patrick LeBoutillier, E<lt>patl@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Patrick LeBoutillier

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
