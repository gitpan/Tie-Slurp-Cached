use strict;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'Tie::Slurp::Cached',
    VERSION_FROM      => 'lib/Tie/Slurp/Cached.pm',
    PREREQ_PM         => {},
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/Tie/Slurp/Cached.pm',
       AUTHOR         => 'Kenichi Ishigaki <ishigaki@cpan.org>') : ()
    ),
    ($ExtUtils::MakeMaker::VERSION >= 6.31 ?
      ( LICENSE => 'perl' ) : ()
    ),
);
