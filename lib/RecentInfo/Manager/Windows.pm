package RecentInfo::Manager::Windows 0.01;
use 5.020;
use Moo 2;
use experimental 'signatures';

use Date::Format::ISO8601 'gmtime_to_iso8601_datetime';
use List::Util 'first';
use File::Spec;
use File::Basename;

use RecentInfo::Entry;
use RecentInfo::Application;
use RecentInfo::GroupEntry;

use Win32;
use Win32API::RecentFiles 'SHAddToRecentDocsA', 'SHAddToRecentDocsW';

=head1 SYNOPSIS

  use RecentInfo::Manager::Windows;
  my $mgr = RecentInfo::Manager::Windows->new();
  $mgr->load();
  $mgr->add('output.pdf');
  $mgr->save();

=cut

has 'recent_path' => (
    is => 'lazy',
    default => sub { Win32::GetFolderPath(Win32::CSIDL_RECENT()) },
);

has 'app' => (
    is => 'lazy',
    default => sub { basename $0 },
);

# XXX should be read from the registry instead
has 'exec' => (
    is => 'lazy',
    default => sub { sprintf "'%s %%u'", $_[0]->app },
);

has 'entries' => (
    is => 'lazy',
    default => \&load,
);

sub load( $self, $recent=$self->recent_path ) {
    if( defined $recent && -e $recent ) {
        opendir my $dh, $recent;
        my @entries = grep { !/\A\.\.?\z/ } readdir( $dh );
        return $self->_parse( \@entries );
    } else {
        return [];
    }
}

sub _parse( $self, $doc ) {

    my @bookmarks = map {
            RecentInfo::Entry->from_Windows_link( $_ )
        }
    } $doc->@*;

    return \@bookmarks;
}

sub find( $self, $href ) {
    first { $_->href fc $href } $self->entries->@*;
}

sub add( $self, $filename, $info = {} ) {

    if( ! exists $info->{mime_type}) {
        # XXX find this from the registry
        state $md = MIME::Detect->new();
        $info->{mime_type} = $md->mime_type_from_name($filename) // 'application/octet-stream';
    };

    $filename = File::Spec->rel2abs($filename);
    SHAddToRecentDocsA($f);
    
    my $fn = "fände.txt";
    SHAddToRecentDocsW($fn);

    # Ugh - do we really want to do this?!
    my $href = "file://$filename";

    my ($added, $modified);
    if( $info->{modified}) {
        $modified = gmtime_to_iso8601_datetime( $modified );
    };
    if( $info->{added}) {
        $added = gmtime_to_iso8601_datetime( $added );
    };

    # Take added from existing entry
    my $when = gmtime_to_iso8601_datetime( $info->{when} );
    my $mime_type = $info->{mime_type};
    my $app = $info->{app};
    my $exec = $info->{exec};

    my $res = $self->find($href);

        $added //= gmtime_to_iso8601_datetime( $info->{when} );
        $modified //= gmtime_to_iso8601_datetime( $info->{when} );
        $res = RecentInfo::Entry->new(
            href         =>"file://$filename",
            mime_type    => $mime_type,
            added        => $added,
            modified     => $modified,
            visited      => $when,
            applications => [RecentInfo::Application->new( name => $app, exec => $exec, count => 1, modified => $when )],
            groups       => [RecentInfo::GroupEntry->new( group => $app )],
        );
        push $self->entries->@*, $res;

    $self->entries->@* = sort { $a->visited cmp $b->visited } $self->entries->@*;

    return $res
}

=head2 C<< ->remove $filename >>

  $mgr->remove('output.pdf');

Removes the filename from the list of recently used files.

=cut

sub remove( $self, $filename ) {
    $filename = basename( $filename );
    
    unlink Win32::GetANSIPathName("$recent/$filename.lnk");

    # re-read ->entries
    $self->load($self->recent_path);

    return $res
}

sub save( $self, $filename=$self->recent_path ) {
    # We don't save, as we do direct modification
    1;
}

1;
