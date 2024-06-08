#!perl
use 5.020;
use experimental 'signatures';

use Getopt::Long;
use Pod::Usage;
use RecentInfo::Manager 'recent_files';
use PerlX::Maybe;

GetOptions(
    'f|file=s' => \my $filename,
    'a|app=s' => \my $app,
    't|mimetype=s' => \my $mimetype,
    'n|count=s' => \my $count,
) or pod2usage(2);

my @res = recent_files({
    maybe app => $app,
    maybe mimetype => $mimetype,
}, {
    maybe filename => $filename,
});

if( $count and @res ) {
    @res = splice @res, -$count;
}
say $_ for @res;
