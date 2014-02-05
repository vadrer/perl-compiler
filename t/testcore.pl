# -*- cperl -*-
# t/testcore.t - run the core testsuite with the compilers C, CC and ByteCode
# Usage:
#   t/testcore.t -fail             known failing tests only
#   t/testcore.t -c                run C compiler tests only (also -bc or -cc)
#   t/testcore.t t/CORE/op/goto.t  run this test only
#
# Prereq:
# Copy your matching CORE t dirs into t/CORE.
# For now we test qw(base comp lib op run)
# Then fixup the @INC setters, and various require ./test.pl calls.
#
#   perl -pi -e 's/^(\s*\@INC = )/# $1/' t/CORE/*/*.t
#   perl -pi -e "s|^(\s*)chdir 't' if -d|\$1chdir 't/CORE' if -d|" t/CORE/*/*.t
#   perl -pi -e "s|require './|use lib "CORE"; require '|" `grep -l "require './" t/CORE/*/*.t`
#
# See TESTS for recent results


use Cwd;
use File::Copy;

BEGIN {
  unless (-d "t/CORE" or $ENV{NO_AUTHOR}) {
    print "1..0 #skip t/CORE missing. Read t/testcore.t how to setup.\n";
    exit 0;
  }
  unshift @INC, ("t");
}

require "test.pl";

sub vcmd {
  my $cmd = join "", @_;
  print "#",$cmd,"\n";
  run_cmd($cmd, 120); # timeout 2min
}

my $dir = getcwd();

#unlink ("t/perl", "t/CORE/perl", "t/CORE/test.pl", "t/CORE/harness");
#symlink "t/perl", $^X;
#symlink "t/CORE/perl", $^X;
#symlink "t/CORE/test.pl", "t/test.pl" unless -e "t/CORE/test.pl";
#symlink "t/CORE/harness", "t/test.pl" unless -e "t/CORE/harness";
`ln -sf $^X t/perl`;
`ln -sf $^X t/CORE/perl`;
# CORE t/test.pl would be better, but this fails only on 2 tests
-e "t/CORE/test.pl" or `ln -s $dir/t/test.pl t/CORE/test.pl`;
-e "t/CORE/harness" or `ln -s test.pl t/CORE/harness`; # better than nothing
#`ln -s $dir/t/test.pl harness`; # base/term
#`ln -s $dir/t/test.pl TEST`;    # cmd/mod 8

my %ALLOW_PERL_OPTIONS;
for (qw(
        comp/cpp.t
        run/runenv.t
       )) {
  $ALLOW_PERL_OPTIONS{"t/CORE/$_"} = 1;
}
my $SKIP = { "CC" =>
             { "t/CORE/op/bop.t" => "hangs",
               "t/CORE/op/die.t" => "hangs",
             }
           };

my @fail = map { "t/CORE/$_" }
  qw{
     base/rs.t
     base/term.t
     cmd/for.t
     cmd/subval.t
     cmd/while.t
     comp/colon.t
     comp/hints.t
     comp/multiline.t
     comp/packagev.t
     comp/parser.t
     comp/require.t
     comp/retainedlines.t
     comp/script.t
     comp/uproto.t
     comp/use.t
     io/argv.t
     io/binmode.t
     io/crlf.t
     io/crlf_through.t
     io/errno.t
     io/fflush.t
     io/fs.t
     io/inplace.t
     io/iprefix.t
     io/layers.t
     io/nargv.t
     io/open.t
     io/openpid.t
     io/perlio.t
     io/perlio_fail.t
     io/perlio_leaks.t
     io/perlio_open.t
     io/pipe.t
     io/print.t
     io/pvbm.t
     io/read.t
     io/say.t
     io/tell.t
     io/through.t
     io/utf8.t
     op/anonsub.t
     op/array.t
     op/attrs.t
     op/avhv.t
     op/bop.t
     op/chop.t
     op/closure.t
     op/concat.t
     op/defins.t
     op/do.t
     op/eval.t
     op/filetest.t
     op/flip.t
     op/fork.t
     op/goto.t
     op/goto_xs.t
     op/grent.t
     op/gv.t
     op/hashwarn.t
     op/index.t
     op/join.t
     op/length.t
     op/local.t
     op/lfs.t
     op/magic.t
     op/method.t
     op/misc.t
     op/mkdir.t
     op/my_stash.t
     op/numconvert.t
     op/pwent.t
     op/regmesg.t
     op/runlevel.t
     op/sort.t
     op/split.t
     op/sprintf.t
     op/stat.t
     op/study.t
     op/subst.t
     op/substr.t
     op/tie.t
     op/tr.t
     op/universal.t
     op/utf8decode.t
     op/vec.t
     op/ver.t
     uni/cache.t
     uni/chomp.t
     uni/chr.t
     uni/class.t
     uni/fold.t
     uni/greek.t
     uni/latin2.t
     uni/lex_utf8.t
     uni/lower.t
     uni/sprintf.t
     uni/tie.t
     uni/title.t
     uni/tr_7jis.t
     uni/tr_eucjp.t
     uni/tr_sjis.t
     uni/tr_utf8.t
     uni/upper.t
     uni/write.t
   };

my @tests = $ARGV[0] eq '-fail'
  ? @fail
  : ((@ARGV and $ARGV[0] !~ /^-/)
     ? @ARGV
     : <t/CORE/*/*.t>);
shift if $ARGV[0] eq '-fail';
my $Mblib = $^O eq 'MSWin32' ? '-Iblib\arch -Iblib\lib' : "-Iblib/arch -Iblib/lib";

sub run_c {
  my ($t, $backend) = @_;
  chdir $dir;
  my $result = $t; $result =~ s/\.t$/-c.result/;
  $result =~ s/-c.result$/-cc.result/ if $backend eq 'CC';
  my $a = $result; $a =~ s/\.result$//;
  unlink ($a, "$a.c", "t/$a.c", "t/CORE/$a.c", $result);
  # perlcc 2.06 should now work also: omit unneeded B::Stash -u<> and fixed linking
  # see t/c_argv.t
  my $backopts = $backend eq 'C' ? "-qq,C,-O3" : "-qq,CC";
  $backopts .= ",-fno-warnings" if $backend =~ /^C/ and $] >= 5.013005;
  $backopts .= ",-fno-fold"     if $backend =~ /^C/ and $] >= 5.013009;
  vcmd "$^X $Mblib -MO=$backopts,-o$a.c $t";
  # CORE often does BEGIN chdir "t", patched to chdir "t/CORE"
  chdir $dir;
  move ("t/$a.c", "$a.c") if -e "t/$a.c";
  move ("t/CORE/$a.c", "$a.c") if -e "t/CORE/$a.c";
  my $d = "";
  $d = "-DALLOW_PERL_OPTIONS" if $ALLOW_PERL_OPTIONS{$t};
  vcmd "$^X $Mblib script/cc_harness -q $d $a.c -o $a" if -e "$a.c";
  vcmd "./$a | tee $result" if -e "$a";
  prove ($a, $result, $i, $t, $backend);
  $i++;
}

sub prove {
  my ($a, $result, $i, $t, $backend) = @_;
  if ( -e "$a" and -s $result) {
    system(qq[prove -Q --exec cat $result || echo -n "n";echo "ok $i - $backend $t"]);
  } else {
    print "not ok $i - $backend $t\n";
  }
}

my @runtests = qw(C CC BC);
if ($ARGV[0] and $ARGV[0] =~ /^-(c|cc|bc)$/i) {
  @runtests = ( uc(substr($ARGV[0],1) ) );
}
my $numtests = scalar @tests * scalar @runtests;
my %runtests = map {$_ => 1} @runtests;

print "1..", $numtests, "\n";
my $i = 1;

for my $t (@tests) {
 C:
  if ($runtests{C}) {
    (print "ok $i #skip $SKIP->{C}->{$t}\n" and goto CC)
      if exists $SKIP->{C}->{$t};
    run_c($t, "C");
    }

 CC:
  if ($runtests{CC}) {
    (print "ok $i #skip $SKIP->{CC}->{$t}\n" and goto BC)
      if exists $SKIP->{CC}->{$t};
    run_c($t, "CC");
  }

 BC:
  if ($runtests{BC}) {
    (print "ok $i #skip $SKIP->{BC}->{$t}\n" and next)
      if exists $SKIP->{BC}->{$t};

    my $backend = 'Bytecode';
    chdir $dir;
    $result = $t; $result =~ s/\.t$/-bc.result/;
    unlink ("b.plc", "t/b.plc", "t/CORE/b.plc", $result);
    vcmd "$^X $Mblib -MO=-qq,Bytecode,-H,-s,-ob.plc $t";
    chdir $dir;
    move ("t/b.plc", "b.plc") if -e "t/b.plc";
    move ("t/CORE/b.plc", "b.plc") if -e "t/CORE/b.plc";
    vcmd "$^X $Mblib b.plc > $result" if -e "b.plc";
    prove ("b.plc", $result, $i, $t, $backend);
    $i++;
  }
}

END {
  unlink ( "t/perl", "t/CORE/perl", "harness", "TEST" );
  unlink ("a","a.c","t/a.c","t/CORE/a.c","aa.c","aa","t/aa.c","t/CORE/aa.c","b.plc");
}