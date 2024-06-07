package RecentInfo::Entry 0.01;
use 5.020;
use Moo 2;
use experimental 'signatures';
use Carp 'croak';

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

state $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs( bookmark => "http://www.freedesktop.org/standards/desktop-bookmarks");
$xpc->registerNs( mime     => "http://www.freedesktop.org/standards/shared-mime-info" );

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
    if(! $meta) {
        warn $frag->toString;
        croak "Invalid xml?! No <info>/<metadata> element found"
    };
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

1;
