use strict ;
use IO::Handle ;

use Test::More tests => 37 ;
BEGIN { use_ok('IO::Mux') } ;
BEGIN { use_ok('IO::Mux::Handle') } ;

pipe(R, W) ;

my $mr = new IO::Mux(\*R) ;
is($mr->get_handle(), \*R) ;
my $mw = new IO::Mux(\*W) ;
is($mw->get_handle(), \*W) ;

my $rc = undef ;
my $r = new IO::Mux::Handle($mr) ;
my $w = new IO::Mux::Handle($mw) ;
$rc = $r->open(1) ;
is($rc, 1) ;
$rc = $w->open(1) ;
is($rc, 1) ;

# Type testing
ok($r->isa('IO::Mux::Handle')) ;

my $buf = undef ;

# One packet tests
$rc = print $w "test1" ;
is($rc, 1) ;
$buf = '' ;
$rc = sysread($r, $buf, 4) ;
is($rc, 4) ;
is($buf, 'test') ;

# Read the numbers
$buf = '' ;
$rc = sysread($r, $buf, 1) ;
is($rc, 1) ;
is($buf, 1) ;

# Read lines
print $w "line1\n" ;
is(<$r>, "line1\n") ;

# Reads that span multiple packets.
$rc = print $w "p11" ;
is($rc, 1) ;
$rc = print $w "p21" ;
is($rc, 1) ;

$buf = '' ;
$rc = sysread($r, $buf, 6) ;
is($rc, 6) ;
is($buf, 'p11p21') ;

# We are done.
$rc = close($w) ;
is($rc, 1) ;
# Close again
$rc = close($w) ;
is($rc, 0) ;

# Read from EOF handle
$buf = '' ;
$rc = sysread($r, $buf, 1) ;
is($rc, 0) ;
ok(eof($r)) ;
# Read from EOF handle again
$buf = '' ;
$rc = sysread($r, $buf, 1) ;
is($rc, 0) ;
ok(eof($r)) ;

# Print to closed handle
$rc = print $w "test" ;
is($rc, undef) ;
# Print to read-only handle
$rc = print $r "test" ;
is($rc, undef) ;


# Successful re-open
$rc = $r->open(1) ;
is($rc, 1) ;
# Use standard open to re-open using same handle
$rc = open($w, 1) ;
ok($rc) ;
$rc = print $w "reopened\n" ;
is($rc, 1) ;
is(<$r>, "reopened\n") ;


# Failed re-open
my $r2 = $mr->new_handle() ;
$rc = $r2->open(1) ;
is($rc, undef) ;
like($r2->get_error(), qr/already in use/) ;


# Various system calls
$r->open('id') ;
$rc = tell($r) ;
is($rc, 0) ;
$rc = seek($r, 5, 1) ;
is($rc, 0) ;
$rc = binmode($r) ;
is($rc, 1) ;
$rc = fileno($r) ;
is($rc, 'id') ;

# Handle not opened
$r2 = $mr->new_handle() ;
$rc = print $r2 "test" ;
is($rc, undef) ;


# Close on real handle
close(W) ;
is(<$r>, undef) ;


