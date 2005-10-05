package IO::Mux::Buffer ;

use strict ;
use IO::Mux::Packet ;
use Carp ;


our $VERSION = '0.06' ;


sub new {
	my $class = shift ;

	my $this = {} ;
	$this->{buf} = '' ;

	return bless($this, $class) ;
}


sub get_length {
	my $this = shift ;

	return length($this->{buf}) ;
}


sub get_data {
	my $this = shift ;

	return $this->{buf} ;
}


sub push_packet {
	my $this = shift ;
	my $packet = shift ;

	$this->{buf} .= $packet->get_data() ;
}


sub shift_data {
	my $this = shift ;
	my $len = shift || 0 ;

	return '' if $len < 0 ;

	if ($this->get_length() < $len){
		croak("Buffer contains less than '$len' bytes (length is " .
			 $this->get_length() ." bytes)") ;
	}

	my $data = substr($this->{buf}, 0, $len) ;
	substr($this->{buf}, 0, $len) = '' ;

	return $data ;
}



1 ;
