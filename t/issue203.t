#! /usr/bin/env perl
# http://code.google.com/p/perl-compiler/issues/detail?id=203
# perlio layers via use open attributes not stored
BEGIN {
  unless (-d '.git') {
    print "1..0 #SKIP Only if -d .git\n";
    exit;
  }
  if ($] >= 5.024) {
    print "1..0 #SKIP use open encoding deprecated\n";
    exit;
  }
  unshift @INC, 't';
  require TestBC;
}
use strict;
use Test::More tests => 1;

use B::C ();
my $when = "1.53_03";
my $todo = ($B::C::VERSION lt $when ? "TODO " : "");
$todo = "TODO " if $] < 5.024; # oops, some time ago 5.22 worked fine. 5.24 broke it upstream
ctestok(1,'C,-O0','ccode203i',<<'EOF',$todo.'#203 restore compile-time perlio layers via use open');
use open(IN => ":crlf", OUT => ":encoding(cp1252)");
open F, "<", "/dev/null"; 
my %l = map {$_=>1} PerlIO::get_layers(F, input  => 1);
print $l{crlf} ? q(ok) : keys(%l);
EOF
