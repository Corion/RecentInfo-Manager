#!perl
use 5.020;
use Test2::V0 -no_srand;
use Time::HiRes 'sleep';
use RecentInfo::Manager 'add_recent_file', 'remove_recent_file', 'recent_files';
use experimental 'try', 'signatures';
use stable 'postderef';

use File::Temp 'tempfile';

my $name;
{
    if( $^O =~ /MSWin32|cygwin/ ) {
        require Win32;
        $name = Win32::GetFolderPath(Win32::CSIDL_RECENT());
    } else {
        (my( $fh ), $name ) = tempfile;
        close $fh;
        END {
            unlink $name if defined $name;
        };
    };
};
note "Recent entries live under '$name'";
# Do some roundtrip tests
my @initial = recent_files(undef, { recent_path => $name });
is \@initial, [], "We start out with an empty recently used list";

add_recent_file($0, undef, { recent_path => $name });
sleep 0.1;

my @new = recent_files(undef, { recent_path => $name });
is scalar @new, 1, "We added one file";

my @other = recent_files(undef, { app => 'foo', recent_path => $name });
is \@other, [], "Recent files for another program are empty with appname initialized";
sleep 0.1;

@other = recent_files({ app => 'bar' }, { recent_path => $name });
is \@other, [], "Recent files for another program are empty with appname as parameter";
sleep 0.1;

add_recent_file([$0, $0], undef, { recent_path => $name });
@new = recent_files(undef, { recent_path => $name });
is scalar @new, 1, "Adding the same file multiple times keeps the number the same";
sleep 0.1;

remove_recent_file([$0, $0], { recent_path => $name });
@new = recent_files(undef, { recent_path => $name });
is scalar @new, 0, "We removed the file";
sleep 0.1;

done_testing;
