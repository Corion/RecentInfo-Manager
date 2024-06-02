#!perl
use 5.020;
use experimental 'signatures';

use RecentInfo::Manager;

my $recent = RecentInfo::Manager->new();

# Manual test 1 - check behaviour: a manually added file must exist - yes
# Manual test 2 - check behaviour: a manually added file must be unique - yes
# Manual test 3 - check behaviour: where is a manually added file added in the order?

my $org = do {
    open my $fh, '<:raw', $recent->filename;
    local $/;
    <$fh>;
};
$org =~ s/\s+(xmlns:(?:bookmark|mime))/ $1/gm;

$recent->add( test => { app => 'geany', mime_type => 'text/plain' });
my $new = $recent->toString;

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

$recent->save;
