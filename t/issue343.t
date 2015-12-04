#! /usr/bin/env perl
# https://github.com/rurban/perl-compiler/issues/343
# illegal empty outside pad
use strict;
BEGIN {
  unshift @INC, 't';
  require "test.pl";
}
use Test::More;
plan tests => 3;
#use Config;

my $pmfile = "t/Outpad.pm";
my $pmsrc = <<'EOF';
package Outpad;
my $func;

sub init {
    $func = 0;
    eval q{$func=\&Foo::Bar::baz;};
}
1;
EOF

my $script = <<'EOF';
BEGIN { unshift @INC, 't'; }
use Outpad ();
Outpad::init();
print qq/ok\n/;
EOF

open F, ">", "$pmfile";
print F $pmsrc;
close F;

my $todo = ""; #($]>5.021?"TODO 5.22 \#343 ":"");
ctestok(1,'C,-O3,-USocket','ccode343i',$script, $todo."empty outpad C");
ctestok(2,'CC,-USocket','cccode343i',$script, $todo."empty outpad CC");
plctestok(3,'ccode343i',$script, "empty outpad BC"); # needs patched 5.22

unlink($pmfile);
