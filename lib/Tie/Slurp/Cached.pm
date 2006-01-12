package Tie::Slurp::Cached;

use 5.006;
use strict;
use warnings;
use Carp;
use Fcntl qw/:DEFAULT :flock :seek/;

our $VERSION = '0.01';

use vars qw/$NoBlocking $WriteFirst $DontSaveAtDestroyTime/;

sub TIESCALAR {
  my ($class, $filename) = @_;

  sysopen my $fh, $filename, O_RDWR | O_CREAT
    or croak "Could not open file '$filename': $!";

  my $lock_options  = LOCK_EX;
     $lock_options |= LOCK_NB if $NoBlocking;

  flock $fh, $lock_options
    or croak "Could not lock file '$filename': $!";

  sysread $fh, my $data, -s $filename;

  bless {
    fh    => $fh,
    fname => $filename,
    data  => $data
  }, $class;
}

sub FETCH {
  my $this = shift;

  return $this->{data};
}

sub STORE {
  my ($this, $value) = @_;

  $this->{data} = $value;
}

sub UNTIE {
  my ($this, $count) = @_;

  croak "untie attempted while $count inner references still exist" if $count;

  _save($this);

  # In fact, we don't need this. Just for clarity.

  close $this->{fh};

  # This is for DESTROY called after UNTIE.
  # As we closed the handle, we can't save any more.

  undef $this->{fh};
}

sub DESTROY {
  my $this = shift;

  # This is for compatibility, and for lazy users who forget 
  # (or are too lazy) to untie.

  _save($this) unless $DontSaveAtDestroyTime;
}

sub _save {
  my $this = shift;

  return unless $$this{fh};

  # Maybe we don't need this, but for clarity and safety.

  sysseek $this->{fh}, 0, SEEK_SET
    or croak "Could not rewind file '$$this{fname}': $!";

  # We might lose data in a very unfortunate occasion.
  # Renaming is a bit safer but I don't want to leave 
  # unwanted/unexpected temporary files.

  unless ($WriteFirst) {
    truncate $this->{fh}, 0
      or croak "Could not truncate file '$$this{fname}': $!";
  }

  syswrite $this->{fh}, $this->{data}
    or croak "Could not write file '$$this{fname}': $!";

  if ($WriteFirst) {
    my $cur = sysseek $this->{fh}, 0, SEEK_CUR
      or croak "Could not seek file '$$this{fname}': $!";
    truncate $this->{fh}, $cur
      or croak "Could not truncate file '$$this{fname}': $!";
  }
}

package Tie::Slurp::Cached::ReadOnly;

use strict;
use warnings;
use Carp;
use Fcntl qw/:DEFAULT :flock/;

use vars qw/$NoBlocking/;

sub TIESCALAR {
  my ($class, $filename) = @_;

  sysopen my $fh, $filename, O_RDONLY
    or croak "Could not open file '$filename': $!";

  my $lock_options  = LOCK_SH;
     $lock_options |= LOCK_NB if $NoBlocking;

  flock $fh, $lock_options
    or croak "Could not lock file '$filename': $!";

  sysread $fh, my $data, -s $filename;

  bless {
    fh    => $fh,
    fname => $filename,
    data  => $data
  }, $class;
}

sub FETCH {
  my $this = shift;

  return $this->{data};
}

sub STORE {
  my ($this, $value) = @_;

  croak "$$this{fname} is read-only";
}

sub UNTIE {
  my ($this, $count) = @_;

  croak "untie attempted while $count inner references still exist" if $count;

  close $this->{fh};

  undef $this->{fh};
}

sub DESTROY {

}

1;
__END__

=head1 NAME

Tie::Slurp::Cached - slurps with locks a la perltie

=head1 SYNOPSIS

  use Tie::Slurp::Cached;

  # croak immediately if locked
  $Tie::Slurp::Cached::NoBlocking = 1;

  # tie (and open/lock) files
  tie my $template => 'Tie::Slurp::Cached::ReadOnly' => 'template.html';
  tie my $output   => 'Tie::Slurp::Cached'           => 'output.html';

  # do some operations
  ($output = $template) =~ s/\[(\w+)\]/$data{$1}/g;

  # untie to save/close/unlock
  untie $output;

  # $template would be closed/unlocked implicitly at destroy time.

=head1 DESCRIPTION

Tie::Slurp::Cached works almost the same as L<Tie::Slurp>. But, with this
module, the specified file opens (and locks) at C<tie> time to read/cache
the contents (if any). When you do something to the C<tie>d scalar,
the cached contents vary as you expect, without any file accesses.
When you finish necessary operations, C<untie> the scalar to save the
changed contents to the file. If you forget (or are too lazy) to C<untie>,
Tie::Slurp::Cached implicitly saves them (and then, closes the file
if appropriate) at C<DESTROY> time. 

As Tie::Slurp::Cached keeps an exclusive lock while C<tie>-ing, 'race
condition' problem doesn't occur (er, basically). You can use this
more safely (see below) to implement an incremental counter, or to
apply several changes to a file, than Tie::Slurp.

Tie::Slurp::Cached::ReadOnly works almost the same as Tie::Slurp::Cached.
However, you can't change the contents through the ReadOnly-C<tie>d scalar,
and the ReadOnly's lock is not exclusive. You can't write while someone's
C<tie>-ing (either Writable or ReadOnly), but you can read while someone's
ReadOnly C<tie>-ing, just as you expect.

=head1 CONFIGURATION

=head2 $Tie::Slurp::Cached::NoBlocking, $Tie::Slurp::Cached::ReadOnly::NoBlocking

These variables change the lock option. If set true, LOCK_NB will be added
for *future* locks. The default is C<undef>.

=head2 $Tie::Slurp::Cached::WriteFirst

By default, this module might lose previously saved contents in a very
unfortunate condition. This is because it C<truncate()>s before
C<syswrite()>s. If this variable is set true, it C<syswrite()>s first,
then C<truncate()>s the unwanted part. The default is C<undef>.

=head2 $Tie::Slurp::Cached::DontSaveAtDestroyTime

By default, this module saves the contents at C<DESTROY> time. But in
some cases, you might want to disable this feature, especially if you
want to save (commit) your changes only when you have no errors in between.
If set true, it won't save at C<DESTROY> time. The default is C<undef>.

=head1 SEE ALSO

L<Tie::Slurp>

L<perltie>

=head1 AUTHOR

Kenichi Ishigaki, E<lt>ishigaki@cpan.orgE<gt>

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
