package RecentInfo::Manager 0.01;
use 5.020;
use Moo 2;
use experimental 'signatures';

use XML::LibXML;
use XML::LibXML::PrettyPrint;
use IO::AtomicFile;
use Date::Format::ISO8601 'gmtime_to_iso8601_datetime';
use List::Util 'first';
use File::Spec;
use File::Basename;

use MIME::Detect;
use RecentInfo::Entry;
use RecentInfo::Application;
use RecentInfo::GroupEntry;

use Exporter 'import';
our @EXPORT_OK = (qw(add_recent_file remove_recent_file recent_files));

=head1 SYNOPSIS

  use RecentInfo::Manager 'add_recent_file';
  add_recent_file('output.pdf');

=cut

# Split up later into ::XBEL and ::Windows, and make this a factory (plus a role maybe)
# For Windows, those live as links under $ENV{APPDATA}\Microsoft\Windows\Recent
# similar information can be synthesized from there

# Also detect the MIME type here (for XBEL)
use MIME::Detect;

has 'filename' => (
    is => 'lazy',
    default => sub { File::Spec->catfile( $ENV{ XDG_DATA_HOME }, 'recently-used.xbel' )},
);

has 'app' => (
    is => 'lazy',
    default => sub { basename $0 },
);

has 'exec' => (
    is => 'lazy',
    default => sub { sprintf "'%s %%u'", $_[0]->app },
);

has 'entries' => (
    is => 'lazy',
    default => \&load,
);

sub load( $self, $recent=$self->filename ) {
    if( defined $recent && -f $recent && -s _ ) {
        my $doc = XML::LibXML
                      ->new( load_ext_dtd => 0, keep_blanks => 1, expand_entities => 0, )
                      ->load_xml( location => $recent );
        return $self->_parse( $doc );
    } else {
        return [];
    }
}

sub fromString( $self, $xml ) {
    my $doc = XML::LibXML
                  ->new( load_ext_dtd => 0, keep_blanks => 1, expand_entities => 0, )
                  ->load_xml( string => \$xml );
    return $self->_parse( $doc );
}

sub _parse( $self, $doc ) {
    # Just to make sure we read in valid(ish) data
    #validate_xml( $doc );
    # Parse our tree from the document, instead of using the raw XML
    # as we want to try out the Perl class?!
    # this means we lose comments etc.

    my @bookmarks = map {
        if( $_->nodeType == XML_TEXT_NODE ) {
            # ignore
            ()
        } else {
            RecentInfo::Entry->from_XML_fragment( $_ )
        }
    } $doc->getElementsByTagName('xbel')->[0]->childNodes()->get_nodelist;

    return \@bookmarks;
}

sub find( $self, $href ) {
    # This is case sensitive, which might be unexpected on Windows
    # and case-insensitive filesystems in general...
    first { $_->href eq $href } $self->entries->@*;
}

sub add( $self, $filename, $info = {} ) {

    $info->{when} //= time();
    $info->{app } //= $self->app;
    $info->{exec} //= $self->exec;
    $info->{visited} //= time();

    if( ! exists $info->{mime_type}) {
        state $md = MIME::Detect->new();
        $info->{mime_type} = $md->mime_type_from_name($filename) // 'application/octet-stream';
    };

    $filename = File::Spec->rel2abs($filename);

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

    if(! $res) {
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
    } else {
        $res->added($added) if $added;
        $res->modified($modified) if $modified;
        $res->visited($when);
        # Check if we are in the group, otherwise add ourselves

        if(! grep { $_->group eq $app } $res->groups->@*) {
            push $res->groups->@*, RecentInfo::GroupEntry->new( group => $app );
        };
        if(! grep { $_->name eq $app } $res->applications->@*) {
            push $res->applications->@*,
                RecentInfo::Application->new( name => $app, exec => $info->{exec}, count => 1, modified => $when )
        } else {
            # Update our most recent entry in ->applications
            my $app_entry = first { $_->name eq $app } $res->applications->@*;
            $app_entry->modified($when);
            $app_entry->count( $app_entry->count+1);
        };
    };

    $self->entries->@* = sort { $a->visited cmp $b->visited } $self->entries->@*;

    return $res
}

=head2 C<< ->remove $filename >>

  $mgr->remove('output.pdf');

Removes the filename from the list of recently used files.

=cut

sub remove( $self, $filename ) {
    $filename = File::Spec->rel2abs($filename);

    # Ugh - do we really want to do this?!
    my $href = "file://$filename";

    my $res;

    $self->entries->@* = map {
        if( $_->href eq $href ) {
            $res = $_;
            (); # discard the item
        } else {
            say $_->href;
            say $href;
            $_; # keep the item
        }
    } $self->entries->@*;

    $self->entries->@* = sort { $a->visited cmp $b->visited } $self->entries->@*;

    return $res
}

sub toString( $self ) {
    my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $xbel = $doc->createElement('xbel');
    $doc->setDocumentElement($xbel);
    $xbel->setAttribute("version" => '1.0');
    $xbel->setAttribute("xmlns:bookmark" => "http://www.freedesktop.org/standards/desktop-bookmarks");
    $xbel->setAttribute("xmlns:mime" => "http://www.freedesktop.org/standards/shared-mime-info");
    for my $bm ($self->entries->@*) {
        $xbel->addChild($bm->as_XML_fragment( $doc ));
    };

    my $pp = XML::LibXML::PrettyPrint->new(
        indent_string => '  ',
        element => {
            compact => [qw[ bookmark:group ]],
        },
    );
    $pp->pretty_print( $xbel );

    #validate_xml( $doc );

    my $str = $doc->toString(); # so we encode some entities?!

    # Now hardcore encode some entities within attributes/double quotes back
    # because I can't find how to coax XML::LibXML to properly encode entities:
    $str =~ s!exec="'!exec="&apos;!g;
    $str =~ s!'"( |>)!&apos;"$1!g;

    return $str
}

sub save( $self, $filename=$self->filename ) {
    my $str = $self->toString;
    my $fh = IO::AtomicFile->open( $filename, '>:raw' );
    print $fh $str;
    $fh->close;
}

# Maybe this should go into RecentInfo::Utils RecentInfo::Functions ?!

sub add_recent_file($filename, $file_options={}, $options={}) {
    my $mgr = RecentInfo::Manager->new(%$options);

    if( ! ref $filename ) {
        $filename = [ [$filename => $file_options] ];
    }

    my @files = map {
        ! ref $_ ? [$_ => $file_options] : $_
    } $filename->@*;

    for my $f (@files) {
        $mgr->add( $f->@* );
    };
    $mgr->save();
};

sub remove_recent_file($filename, $options={}) {
    my $mgr = RecentInfo::Manager->new(%$options);

    if( ! ref $filename ) {
        $filename = [ $filename ];
    }

    my @files = $filename->@*;

    for my $f (@files) {
        $mgr->remove( $f );
    };
    $mgr->save();
};

sub mime_match( $type, $pattern ) {
    $pattern =~ s/\*/.*/g;
    $type =~ /$pattern/
}

sub recent_files($recent_options=undef, $options={}) {
    my $mgr = RecentInfo::Manager->new(%$options);
    $recent_options //= {
        app => $mgr->app,
    };

    my $appname = $recent_options->{app};
    my $mimetype = $recent_options->{mime_type};

    my @res = map { $_->href } grep {
          defined $appname ? grep { $_->name eq $appname } $_->applications->@*
        : defined $mimetype ? mime_match( $_->mime_type, $mimetype )
        : 1
    } $mgr->entries->@*;

    return @res
};

1;
