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
    't|mimetype=s' => \my $mimetype,
    'n|count=s' => \my $count,
) or pod2usage(2);

my $recent = RecentInfo::Manager->new(
    maybe filename => $filename,
);

sub mime_match( $type, $pattern ) {
    $pattern =~ s/\*/.*/g;
    $type =~ /$pattern/
}

my @res = map { $_->href } grep {
      defined $appname ? $_->appname eq $appname
    : defined $mimetype ? mime_match( $_->mime_type, $mimetype )
    : 1
} $recent->entries->@*;

if( $count and @res ) {
    @res = splice @res, -$count;
}
say $_ for @res;
