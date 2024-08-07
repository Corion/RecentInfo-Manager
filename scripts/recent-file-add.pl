#!perl
use 5.020;
use experimental 'signatures';

use Getopt::Long;
use Pod::Usage;
use RecentInfo::Manager 'add_recent_file';
use PerlX::Maybe;

GetOptions(
    'f|file=s'     => \my $filename,
    'a|app=s'      => \my $app,
    'e|exec=s'     => \my $exec_command,
    't|mimetype=s' => \my $mime_type,
) or pod2usage(2);

$exec_command //= "$app '%u'";

my @args = map {
    my $file = $_;
    my $mt = $mime_type // MIME::Detect->new()->mime_type_from_name($file) // 'application/octet-stream';
    $file => { app => $app, mime_type => $mt };
};
add_recent_file(\@args);
