use strict;
use warnings;

use Test::More;

my ($testfile, $exception_ok, $tests);

# First, we check Test::Exception; half of the tests depend on it.
# If not available, our check should be lessened.

BEGIN {
  eval "use File::Spec";
  my $filespec_ok = $@ ? 0 : 1;
  my $tmpdir = $filespec_ok ? File::Spec->tmpdir : '.';
  unless (-w $tmpdir) {
    plan skip_all => 'No writable temporary directory available';
  }

  $testfile = $filespec_ok ?
    File::Spec->catfile($tmpdir,'TSCached.tst') : 'TSCached.tst';

  eval "use Test::Exception";
  $exception_ok = $@ ? 0 : 1;
  $tests        = $exception_ok ? 21 : 11;

  # Then, make sure we can use Tie::Slurp.

  plan tests => $tests;

  use_ok('Tie::Slurp::Cached');
}

# I don't want to wait while testing

$Tie::Slurp::Cached::NoBlocking           = 1;
$Tie::Slurp::Cached::ReadOnly::NoBlocking = 1;

# Make sure we have no previous test file.

unlink $testfile if -f $testfile;

# Let's tie.

ok(tie my $contents => 'Tie::Slurp::Cached' => $testfile);

# Now, we have an exclusive lock. Other ties should die.

if ($exception_ok) {
  dies_ok(sub {
    tie my $another_contents => 'Tie::Slurp::Cached' => $testfile
  }, 'Should croak');

  dies_ok(sub {
    tie my $another_contents => 'Tie::Slurp::Cached::ReadOnly' => $testfile
  }, 'Should croak, too');
}

# Make sure we have no data.

ok(!$contents);

# Let's store some test data.

my $teststr = 'test';

$contents = $teststr;

# Make sure we can retrieve it.

ok($contents eq $teststr);

# OK. Now we save it to the file actually.

untie $contents;

# Tie again. This time we should be able to fetch
# the previously stored data. The reason why we
# take $x is written in perlport.

my $x = tie $contents => 'Tie::Slurp::Cached' => $testfile;

# Make sure we have the data.

ok($contents eq $teststr);

my $teststr2 = 'test2';

$contents = $teststr2;

# We still have an inner reference ($x). So we shouldn't
# close/unlock here.

if ($exception_ok) {
  dies_ok(sub {untie $contents;}, 'Should croak');
}

undef $x;

# Now we have no inner references.
# Make sure we still have the lock and the handle.

if ($exception_ok) {
  dies_ok(sub {
    tie my $another_contents => 'Tie::Slurp::Cached' => $testfile
  }, 'Should croak');
}

my $teststr3 = 'test3';

$contents = $teststr3;

# We should have new value.

ok($contents eq $teststr3);

# This time we have no inner references. We should be able to
# close/unlock safely.

if ($exception_ok) {
  lives_ok(sub {untie $contents;}, 'Should not croak');
}
else {
  untie $contents;
}

# Make sure $DontSaveAtDestroyTime works

{
  $Tie::Slurp::Cached::DontSaveAtDestroyTime = 1;

  tie my $local_contents => 'Tie::Slurp::Cached' => $testfile;

  my $teststr4 = 'test4';

  $local_contents = $teststr4;

  # $local_contents should have been DESTROYed.
}

# $testfile should be the same as before.

tie $contents => 'Tie::Slurp::Cached' => $testfile;

ok($contents eq $teststr3);

untie $contents;

# OK. Then, let's check Tie::Slurp::ReadOnly.
# This time our lock should be shared.

ok(my $y = tie $contents => 'Tie::Slurp::Cached::ReadOnly' => $testfile);

# So, we should be able to have another ReadOnly object.

ok(tie my $another_contents => 'Tie::Slurp::Cached::ReadOnly' => $testfile);
# But no additional exclusive lock is allowed.

if ($exception_ok) {
  dies_ok(sub {
    tie my $yet_another_contents => 'Tie::Slurp::Cached' => $testfile
  }, 'Should croak');
}

# We should have the previously stored data.

ok($contents eq $teststr3);

# And the same.

ok($contents eq $another_contents);

my $teststr5 = 'test5';

# We shouldn't store new data. They are ReadOnly.

if ($exception_ok) {
  dies_ok(sub {$contents = $teststr5;}, 'Should croak');
  ok($contents eq $teststr3);
}

# We shouldn't be able to close here. We still have an inner
# reference ($y).

if ($exception_ok) {
  dies_ok(sub {untie $contents;}, 'Should croak');
}

# Clear the reference.

undef $y;

# Now we can safely close/unlock.

if ($exception_ok) {
  lives_ok(sub {untie $contents;}, 'Should not croak');
}
else {
  untie $contents;
}

untie $another_contents;

# Finished. Let's clean up.

unlink $testfile;
