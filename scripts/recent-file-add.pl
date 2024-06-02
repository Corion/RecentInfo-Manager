#!perl
use 5.020;
use experimental 'signatures';

my $xpc;

package RecentInfo::Application 0.01;
use 5.020;
use Moo 2;
use experimental 'signatures';

has ['name', 'exec'] => (
    is => 'ro',
    required => 1
);

has ['modified', 'count'] => (
    is => 'rw',
    required => 1
);

sub as_XML_fragment($self, $doc) {
    my $app = $doc->createElement('bookmark:application');
    $app->setAttribute("name" =>  $self->name);
    $app->setAttribute("exec" =>  $self->exec);
    $app->setAttribute("modified" =>  $self->modified);
    $app->setAttribute("count" => $self->count);
    return $app
}

sub from_XML_fragment( $class, $frag ) {
    $class->new(
        name  => $frag->getAttribute('name'),
        exec  => $frag->getAttribute('exec'),
        modified  => $frag->getAttribute('modified'),
        count => $frag->getAttribute('count'),
    );
}

package RecentInfo::GroupEntry 0.01;
use 5.020;
use Moo 2;
use experimental 'signatures';

has ['group'] => (
    is => 'ro',
    required => 1
);

sub as_XML_fragment($self, $doc) {
    my $group = $doc->createElement('bookmark:group');
    $group->addChild($doc->createTextNode($self->group));
    #$group->setTextContent($self->group);
    return $group
}

sub from_XML_fragment( $class, $frag ) {
    $class->new(
        group => $frag->textContent,
    );
}

package RecentInfo::Entry 0.01;
use 5.020;
use Moo 2;
use experimental 'signatures';

#has ['href', 'display_name', 'description'] => (
has ['href'] => (
    is => 'ro',
    required => 1,
);

has ['added', 'visited', 'modified'] => (
    is => 'rw',
    required => 1,
);

has ['mime_type'] => (
    is => 'ro',
    required => 1,
);

has ['applications', 'groups'] => (
    is => 'ro',
    default => sub { [] },
);

    #around 'BUILDARGS' {
    #    # Convert maybe $added etc. to DateTime or stuff like that?!
    #}

sub as_XML_fragment($self, $doc) {
    my $bookmark = $doc->createElement('bookmark');
    $bookmark->setAttribute( 'href' => $self->href );
    #$bookmark->setAttribute( 'app' => $self->app );
    # XXX Make sure to validate that $modified, $visited etc. are proper DateTime strings
    $bookmark->setAttribute( 'added' => $self->added );
    $bookmark->setAttribute( 'modified' => $self->modified );
    $bookmark->setAttribute( 'visited' => $self->visited );
    #$bookmark->setAttribute( 'exec' => "'perl %u'" );
    my $info = $bookmark->addNewChild( undef, 'info' );
    my $metadata = $info->addNewChild( undef, 'metadata' );
    #my $mime = $metadata->addNewChild( 'mime', 'mime-type' );
    my $mime = $metadata->addNewChild( undef,'mime:mime-type' );
    $mime->setAttribute( type => $self->mime_type );
    #$mime->appendText( $self->mime_type );
    $metadata->setAttribute('owner' => 'http://freedesktop.org' );
    # Should we allow this to be empty, or should we leave it out completely then?!

    if( $self->groups->@* ) {
        my $groups = $metadata->addNewChild( undef, "bookmark:groups" );
        for my $group ($self->groups->@* ) {
            $groups->addChild( $group->as_XML_fragment( $doc ));
        };
    }

    my $applications = $metadata->addNewChild( undef, "bookmark:applications" );
    for my $application ($self->applications->@* ) {
        $applications->addChild( $application->as_XML_fragment( $doc ));
    };

    return $bookmark;
}

sub from_XML_fragment( $class, $frag ) {
    my $meta = $xpc->findnodes('./info[1]/metadata', $frag)->[0];

    my %meta = (
        mime_type => $xpc->find('./mime:mime-type/@type', $meta)->[0]->nodeValue,
    );

    my @applications = $xpc->find('./bookmark:applications/bookmark:application', $meta)->@*;
    if( !@applications ) {
        warn $meta->toString;
        die "No applications found";
    };

    $class->new(
        href      => $frag->getAttribute('href'),
        added     => $frag->getAttribute('added'),
        modified  => $frag->getAttribute('modified'),
        visited   => $frag->getAttribute('visited'),
        # info/metadata/mime-type
        mime_type => $meta{ mime_type },
        applications => [map {
             RecentInfo::Application->from_XML_fragment($_)
        } $xpc->find('./bookmark:applications/bookmark:application', $meta)->@*],
        groups => [map {
            RecentInfo::GroupEntry->from_XML_fragment($_)
        } $xpc->find('./bookmark:groups/bookmark:group', $meta)->@*],
        #...
    )
}

package RecentInfo::Manager 0.01;
use 5.020;
use Moo 2;
use experimental 'signatures';

use XML::LibXML;
use XML::LibXML::PrettyPrint;
use IO::AtomicFile;
use Date::Format::ISO8601 'gmtime_to_iso8601_datetime';
use List::Util 'first';
use File::Basename;

# Split up later into ::XBEL and ::Windows

has 'filename' => (
    is => 'lazy',
    default => sub { "$ENV{ XDG_DATA_HOME }/recently-used.xbel" },
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
    is => 'ro',
    default => \&load,
);

sub load( $self, $recent=$self->filename ) {
    my $doc = XML::LibXML
                  ->new( load_ext_dtd => 0, keep_blanks => 1, expand_entities => 0, )
                  ->load_xml( location => $recent );

    $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs( bookmark => "http://www.freedesktop.org/standards/desktop-bookmarks");
    $xpc->registerNs( mime     => "http://www.freedesktop.org/standards/shared-mime-info" );

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
    # This is case sensitive, which might be unexpected on Windows...
    first { $_->href eq $href } $self->entries->@*;
}

sub add( $self, $filename, $info = {} ) {

    $info->{when} //= time();
    $info->{app } //= $self->app;
    $info->{exec} //= $self->exec;
    $info->{visited} //= time();
    $info->{mime_type} //= 'application/octet-stream';

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
            push $res->groups->@*,
                RecentInfo::Application->new( name => $app, exec => "'geany %u'", count => 1, modified => $when )
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

package main;

use 5.020;
use experimental 'signatures';

use XML::LibXML;
use XML::LibXML::PrettyPrint;
use File::Spec;

my $recent = RecentInfo::Manager->new();

#sub validate_xml( $tree ) {
#    return 1;
#
#    # One day, we might come up with a valid DTD for the recent documents
#    # XBEL. The existing things online don't validate what is generated by Glib.
#    state $dtd = do {
#        my $dtd_fn = 'dtd/xbel.dtd';
#        open my $fh, '<', $dtd_fn
#            or die "Couldn't read DTD '$dtd_fn': $!";
#        local ($/,@ARGV);
#        my $str = <$fh>;
#        XML::LibXML::Dtd->parse_string($str);
#    };
#
#    $tree->validate( $dtd );
#}


# Manual test 1 - check behaviour: a manually added file must exist?! - no, but they must be unique
# Manual test 2 - check behaviour: where is a manually added file added in the order?
# Test 1 - create XBEL XML for a single file

my $org = do {
    open my $fh, '<:raw', $recent->filename;
    local $/;
    <$fh>;
};
$org =~ s/\s+(xmlns:(?:bookmark|mime))/ $1/gm;

$recent->add( xtest => { app => 'geany', mime_type => 'text/plain' });
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
