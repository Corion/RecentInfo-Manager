#!perl
use 5.020;
use Test2::V0 -no_srand;
use XML::LibXML;
use RecentInfo::Manager 'add_recent_file', 'recent_files';
use experimental 'try', 'signatures';
use stable 'postderef';

use File::Temp 'tempfile';

my( $fh, $name ) = tempfile;
close $fh;

END {
    unlink $name;
};

# Do some roundtrip tests
my @initial = recent_files(undef, { filename => $name });
is \@initial, [], "We start out with an empty recently used list";

add_recent_file($0, undef, { filename => $name });

my @new = recent_files(undef, { filename => $name });
is scalar @new, 1, "We added one file";

my @other = recent_files(undef, { app => 'foo', filename => $name });
is \@other, [], "Recent files for another program are empty with appname initialized";

@other = recent_files({ app => 'bar' }, { filename => $name });
is \@other, [], "Recent files for another program are empty with appname as parameter";

add_recent_file([$0, $0], undef, { filename => $name });
my @new = recent_files(undef, { filename => $name });
is scalar @new, 1, "Adding the same file multiple times keeps the number the same";

done_testing;
