# Copyrights 2011 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.07.
use warnings;
use strict;

package IO::Mux::Open;
use vars '$VERSION';
$VERSION = '0.11';


use Log::Report 'io-mux';

my %modes =
  ( '-|'  => 'IO::Mux::Pipe::Read'
  , '|-'  => 'IO::Mux::Pipe::Write'
  , '|-|' => 'IO::Mux::IPC'
  , '|=|' => 'IO::Mux::IPC'
  , '>'   => 'IO::Mux::File::Write'
  , '>>'  => 'IO::Mux::File::Write'
  , '<'   => 'IO::Mux::File::Read'
  , tcp   => 'IO::Mux::Net::TCP'
  );

sub import(@)
{   my $class = shift;
    foreach my $mode (@_)
    {   my $impl = $modes{$mode}
            or error __x"unknown mode {mode} in use {pkg}"
              , mode => $mode, pkg => $class;
        eval "require $impl";
        panic $@ if $@;
    }
}
    

sub new($@)
{   my ($class, $mode) = (shift, shift);
    my $real  = $modes{$mode}
        or error __x"unknown mode '{mode}' to open() on mux", mode => $mode;

    $real->can('open')
        or error __x"package {pkg} for mode '{mode}' not required by {me}"
             , pkg => $real, mode => $mode, me => $class;

    $real->open($mode, @_);
}

#--------------

1;
