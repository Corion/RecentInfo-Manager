#!perl
use 5.020;
use experimental 'signatures';

use Getopt::Long;
use Pod::Usage;
use RecentInfo::Manager 'remove_recent_file';

GetOptions(
) or pod2usage(2);

my @args = @ARGV;
remove_recent_file(\@args);
