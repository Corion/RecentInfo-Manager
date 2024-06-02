#!perl
use 5.020;
use experimental 'signatures';

use Getopt::Long;
use Pod::Usage;
use RecentInfo::Manager;
use PerlX::Maybe;

GetOptions(
    'f|file=s' => \my $filename,
    'a|appname=s' => \my $appname,
    'n|count=s' => \my $count,
) or pod2usage(2);

my $recent = RecentInfo::Manager->new(
    maybe filename => $filename,
);

my @res = map { $_->href } grep {
    defined $appname ? $_->appname eq $appname
    : 1
} $recent->entries->@*;

if( $count ) {
    @res = splice @res, -$count;
}
say $_ for @res;
