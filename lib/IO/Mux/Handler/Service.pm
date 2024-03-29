# Copyrights 2011 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.07.
use warnings;
use strict;

package IO::Mux::Handler::Service;
use vars '$VERSION';
$VERSION = '0.11';

use base 'IO::Mux::Handler';

use Log::Report       'io-mux';


sub mux_init($)
{   my ($self, $mux) = @_;
    $self->SUPER::mux_init($mux);
    $self->fdset(1, 1, 0, 0);  # 'read' new connections
}

sub mux_remove()
{   my $self = shift;
    $self->SUPER::mux_remove;
    $self->fdset(0, 1, 0, 0);
}


sub mux_connection($) {shift}

1;
