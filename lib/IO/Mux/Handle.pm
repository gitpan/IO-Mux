package IO::Mux::Handle ;
@ISA = qw(IO::Handle) ;

use strict ;
use IO::Handle ;


our $VERSION = '0.05' ;


sub new {
	my $class = shift ;
	my $mux = shift ;

	my $this = $class->SUPER::new() ;
    tie(*{$this}, 'IO::Mux::Tie::Handle', $mux) ;

	return $this ;	
}


sub open {
 	my $this = shift ;
 	my $id = shift ;

 	return open($this, $id) ;
}


sub get_error {
	my $this = shift ;

	return $this->get_tie()->get_error() ;
}


sub set_error {
	my $this = shift ;
	my $msg = shift ;
	
	$this->get_tie()->set_error($msg) ;
}


sub get_tie {
	my $this = shift ;

	return tied(*{$this}) ;
}



#################################################
package IO::Mux::Tie::Handle ;
@IO::Mux::Tie::Handle::ISA = qw(Tie::Handle) ;

use Tie::Handle ;
use IO::Mux::Packet ;
use Errno ;


sub TIEHANDLE {
	my $class = shift ;
	my $mux = shift ;

	return $class->new($mux) ;
}


sub new {
	my $class = shift ;
	my $mux = shift ;

	my $this = {} ;
	$this->{mux} = $mux ;
	$this->{id} = undef ;
	$this->{closed} = 1 ;
	$this->{'eof'} = 0 ;
	$this->{error} = undef ;

	bless($this, $class) ;
}


sub OPEN {
	my $this = shift ;
	my $id = shift ;

	$this->CLOSE() ;

	$id =~ s/\t/ /g ; # no \t's allowed in the id
	if ($this->get_mux()->buffer_exists($id)){
		$this->set_error("Id '$id' is already in use by another handle") ;
		return undef ;
	}

	$this->{id} = $id ;
    # Allocate the buffer
    $this->get_mux()->get_buffer($id) ;
	$this->{closed} = 0 ;
	$this->{'eof'} = 0 ;
	$this->{error} = undef ;

    return 1 ;
}


sub get_mux {
	my $this = shift ;

	return $this->{mux} ;
}


sub get_id {
	my $this = shift ;

	return $this->{id} ;
}


sub get_eof {
	my $this = shift ;

	return $this->{'eof'} ;
}


sub set_eof {
	my $this = shift ;

	$this->{'eof'} = 1 ;
}


sub get_error {
	my $this = shift ;

	return $this->{error} ;
}


sub set_error {
	my $this = shift ;
	my $msg = shift ;

	$this->{error} = $msg ;
	if (exists($!{EIO})){
		$! = Errno::EIO() ; 
	}
	else {
		$! = 99999 ; 
	}
}


sub get_buffer {
	my $this = shift ;

	return $this->get_mux()->get_buffer($this->get_id()) ;
}


sub kill_buffer {
	my $this = shift ;

	return $this->get_mux()->kill_buffer($this->get_id()) ;
}



my $cnt = 0 ;
sub WRITE {
	my $this = shift ;
	my ($buf, $len, $offset) = @_ ;

	return undef if $this->{closed} ;

	my $p = new IO::Mux::Packet($this->get_id(), substr($buf, $offset || 0, $len)) ;
	my $rc = $this->{mux}->write($p) ;

	return $rc ;
}


sub READ {
	my $this = shift ;
	my ($buf, $len, $offset) = @_ ;

	return undef if $this->{closed} ;
	return 0 if $this->get_eof() ;

	# Load the buffer until there is enough data or EOF.
	while ($this->get_buffer()->get_length() < $len){
		my $rc = $this->read_more_data() ;
		if (! defined($rc)){
			return undef ;
		}
		elsif (! $rc){
			# EOF
			last ;
		}
	}

	# Shorten the length if we hit EOF...
	if ($this->get_buffer()->get_length() < $len){
		$len = $this->get_buffer()->get_length() ;
	}

	if ($len > 0){
		# Extract $len bytes from the beginning of the buffer and
		my $data = $this->get_buffer()->shift_data($len) ;
		substr($buf, $offset || 0, $len) = $data ;
		$_[0] = $buf ;
	}

	return $len ;
}


sub READLINE {
	my $this = shift ;

	return undef if $this->{closed} ;
	return undef if $this->get_eof() ;

	my $idx = -1 ;
	while (($idx = index($this->get_buffer()->get_data(), "\n")) == -1){
		my $rc = $this->read_more_data() ;
		if (! defined($rc)){
			return undef ;
		}
		elsif (! $rc){
			# EOF
			last ;
		}
	}

	if ($idx != -1){
		return $this->get_buffer()->shift_data($idx + 1) ;
	}
	else{
		return $this->get_buffer()->shift_data($this->get_buffer()->get_length()) ;
	}
}


sub read_more_data {
	my $this = shift ;

	my $rc = undef ;
	eval {
		$rc = $this->{mux}->read($this->get_id()) ;
	} ;
	if ($@){
		$this->set_error($@) ;
		return undef ;
	}
	elsif (! defined($rc)){
		return $rc ;
	}
	elsif (! $rc){
		# We have reached EOF.
		$this->set_eof() ;
	}
	
	return $rc ;
}


sub EOF { 
	my $this = shift ;

	return 1 if $this->{closed} ;
	return $this->get_eof() ;
}


sub CLOSE { 
	my $this = shift ;

	my $ret = 0 ;
	if (! $this->{closed}){
		my $p = new IO::Mux::Packet($this->{id}, 0) ;
		$p->make_eof() ;
		# Here the real filehandle is possibly closed, so we must silence
		# the warning. We may also get a SIGPIPE, which we will solve
		# by closing the real handle.
		local $SIG{__WARN__} = sub { 
			warn $_[0] unless ($_[0] =~ /closed filehandle/i) ; 
		} ;
		local $SIG{PIPE} = sub {
			close($this->get_mux()->get_handle()) ;
		} ;

		$ret = $this->get_mux()->write($p) ;
		$this->{closed} = 1 ;
		$this->kill_buffer() ;
		return 1 ;
	}

	return $ret ;
}


sub SEEK {
	my $this = shift ;
	my $pos = shift ;
	my $whence = shift ;

	return 0 ;
}


sub BINMODE {
	my $this = shift ;

	return undef if $this->{closed} ;
	return 1 ;
}


sub FILENO {
	my $this = shift ;

	return $this->get_id() ;
}


sub TELL {
	my $this = shift ;

	return -1 if $this->{closed} ;
	return 0 ;
}


sub DESTROY {
	my $this = shift ;

	$this->CLOSE() ;
}



1 ;
__END__
=head1 NAME

IO::Mux::Handle - Virtual handle used with the L<IO::Mux> multiplexer.

=head1 SYNOPSIS

  use IO::Mux ;

  my $mux = new IO::Mux(\*SOCKET) ;
  my $iomh = new IO::Mux::Handle($mux) ;

  open($iomh, "identifier") or die("Can't open: " . $io->get_error()) ;
  print $iomh "hello\n" ;
  while (<$iomh>){ 
    print $_ ;
  }
  close($iomh) ;


=head1 DESCRIPTION

C<IO::Mux::Handle> objects are used to create virtual handles that are 
multiplexed through an L<IO::Mux> object.


=head1 CONSTRUCTOR

=over 4

=item new ( IOMUX )

Creates a new C<IO::Mux::Handle> that is multiplexed over the real handle 
managed by IOMUX.

=back


=head1 METHODS

Since C<IO::Mux::Handle> extends L<IO::Handle>, most L<IO::Handle> methods 
that make sense in this context are supported. The corresponding builtins can 
also be used. Errors are reported using the standard return values and 
mechanisms. See below (L<IO::Mux::Handle/ERROR REPORTING>) for more details.

=over 4

=item $iomh->open ( ID )

Opens $iomh and associates it with the identifier ID. ID can be any scalar 
value, but any tabs ('\t') in ID will be replaced by spaces (' ') in order to 
make it compatible with the underlying multiplexing protocol.

Returns 1 on success or undef on error (the error message can be retreived by 
calling $iomh->get_error()).

=item $iomh->get_error ()

Returns the last error associated with $iomh.

=back


=head1 ERROR REPORTING

While manipulating C<IO::Mux::Handle> objects, two types of errors can occur:

=over 4

=item Errors encountered on the real underlying handle

When error occurs on the underlying (real) handle, $! is set as usual and 
the approriate return code is used.

=item Errors generated by C<IO::Mux::*> module code

Sometimes errors can be generated by the C<IO::Mux:*> code itself. In this 
case, $! is set to C<EIO> if possible (see L<Errno> for more details). If 
C<EIO> does not exists on your system, $! is set to 99999. Also, the actual 
C<IO::Mux::*> error message can be retrieved by calling $iomh->get_error().

Therefore, when working with C<IO::Mux::Handle> objects, it is always a good 
idea to check $iomh->get_error() when $! is supposed to be set, i.e.:

  print $iomh "hi!\n" or die("Can't print: $! (" . $iomh->get_error() . ")") ;

=back


=head1 SEE ALSO

L<IO::Handle>, L<IO::Mux>

=head1 AUTHOR

Patrick LeBoutillier, E<lt>patl@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Patrick LeBoutillier

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
