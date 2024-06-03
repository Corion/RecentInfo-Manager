#!perl
use 5.020;
use experimental 'signatures';

use Getopt::Long;
use Pod::Usage;
use RecentInfo::Manager;
use PerlX::Maybe;

GetOptions(
    'f|file=s'     => \my $filename,
    'a|appname=s'  => \my $appname,
    'e|exec=s'     => \my $exec_command,
    't|mimetype=s' => \my $mime_type,
    'n|dry-run'    => \my $dry_run,
) or pod2usage(2);


$exec_command //= "$exec_command '%u'";
$mime_type //= MIME::Detect->new()->mime_type_from_name($filename) // 'application/octet-stream';

my $recent = RecentInfo::Manager->new();
for my $file (@ARGV) {
    $recent->add( $file => { app => $appname, mime_type => $mime_type });
};
my $new = $recent->toString;

# This should go into the module test suite
# Manual test 1 - check behaviour: a manually added file must exist - yes
# Manual test 2 - check behaviour: a manually added file must be unique - yes
# Manual test 3 - check behaviour: where is a manually added file added in the order?

my $org = do {
    open my $fh, '<:raw', $recent->filename;
    local $/;
    <$fh>;
};
$org =~ s/\s+(xmlns:(?:bookmark|mime))/ $1/gm;

use Algorithm::Diff;
my $diff = Algorithm::Diff->new([split /\r?\n/, $org],[split /\r?\n/, $new]);

$diff->Base( 1 );   # Return line numbers, not indices
while(  $diff->Next()  ) {
    next   if  $diff->Same();
    my $sep = '';
    if(  ! $diff->Items(2)  ) {
        printf "%d,%dd%d\n",
            $diff->Get(qw( Min1 Max1 Max2 ));
    } elsif(  ! $diff->Items(1)  ) {
        printf "%da%d,%d\n",
            $diff->Get(qw( Max1 Min2 Max2 ));
    } else {
        $sep = "---\n";
        printf "%d,%dc%d,%d\n",
            $diff->Get(qw( Min1 Max1 Min2 Max2 ));
    }
    say "< $_"   for  $diff->Items(1);
    say $sep;
    say "> $_"   for  $diff->Items(2);
}

$recent->save if ! $dry_run;
