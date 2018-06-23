use strict; use warnings;
use lib -e 't' ? 't' : 'test';
use TestInlineSetup;

use Inline Config => DIRECTORY => $TestInlineSetup::DIR;
use Test::More tests => 5;
my $tmpdir= File::Spec->catdir($TestInlineSetup::DIR, '_tmp');
mkdir $tmpdir or die "mkdir($tmpdir): $!";
my $tmplib= File::Spec->catdir($tmpdir, 'lib');
mkdir $tmplib or die "mkdir($tmplib): $!";
lib->import($tmplib);

my @test_versions= qw( 0.00 1.23 12.3 0.00_01 0.000_001 );
for my $i (0..$#test_versions) {
    my $ver= $test_versions[$i];
    # Inline only allows a VERSION / NAME on modules which have been processed with
    # Inline::MakeMaker.  So, need to simulate the whole process of running MakeMaker
    # and installing to custom lib dir, then loading package.
    my $builddir= File::Spec->catdir($tmpdir, "build$i");
    mkdir $builddir or die "mkdir($builddir): $!";
    mkdir File::Spec->catdir($builddir, "lib") or die "mkdir: $!";
    open my $fh, '>', File::Spec->catfile($builddir, 'lib', "MyModule${i}.pm")
        or die "open: $!";
    # TODO: 'Foo' can't be installed because it isn't on the whitelist.
    # Maybe allow Foo to be installed?  What does that involve?
    print $fh <<"END";

package MyModule$i;
use strict; use warnings;
BEGIN { \$MyModule${i}::VERSION= '$ver'; }
use Inline
    Foo => 'foo-sub add { foo-return \$_[0] + \$_[1]; }',
    NAME => 'MyModule$i',
    VERSION => '$ver';
1;

END
    close $fh or die "close: $!";
    open $fh, '>', File::Spec->catfile($builddir, "Makefile.PL")
        or die "open: $!";
    print $fh <<"END";

use Inline::MakeMaker;

WriteMakefile(
    NAME         => 'MyModule$i',
    VERSION_FROM => 'lib/MyModule$i.pm',
);

END
    close $fh or die "close: $!";

    if (system("cd \"$builddir\" && $^X Makefile.PL") != 0) {
        fail('Failed to execute Makefile.PL');
    }
    # TODO: platform-independent make?  How does Makefile.PL work when there is no make.exe on Win23?
    elsif (system("cd \"$builddir\" && make install") != 0) {
        fail('Failed to run "make"');
    }
    else {
        ok( eval "require MyModule$_;", 'module with version '.$test_versions[$_] )
            or diag $@;
    }
}
