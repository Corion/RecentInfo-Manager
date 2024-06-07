#!perl
use 5.020;
use Test2::V0 -no_srand;
use XML::LibXML;
use RecentInfo::Manager;
use experimental 'try', 'signatures';
use stable 'postderef';

# Do some roundtrip tests

my @tests;
{
    local $/ = "---\n";
    @tests = map {
        # name?
        # todo?
        chomp;
        {
            xbel => $_,
        }
    } <DATA>;
}

sub valid_xml( $xml, $msg ) {
    state $xmlschema = XML::LibXML::Schema->new( location => 'xsd/recently-used-xbel.xsd', no_network => 1 );
    my $doc = XML::LibXML->new->parse_string( $xml );

    my $todo = todo("The XSD is not well-written");
    try {
        $xmlschema->validate( $doc );
        pass($msg);
    } catch( $e ) {
        diag $e;
        fail($msg);
    }
}

for my $test (@tests) {
    my $xbel = RecentInfo::Manager->new( filename => undef );
    my $bm = $xbel->fromString( $test->{xbel});
    $xbel->entries->@* = $bm->@*;
    my $xml = $xbel->toString;

    valid_xml( $xml, "The input XML is valid" );

    $xml = $xbel->toString;
    valid_xml( $xml, "The generated XML is valid" );

    # Fudge the whitespace a bit
    $test->{xbel} =~ s!\s+xmlns:! xmlns:!msg;
    $test->{xbel} =~ s!\s+>!>!msg;
    $test->{xbel} =~ s!\s+version=! version=!msg;
    is $xml, $test->{xbel}, "The strings are identical";

    my $reconstructed = RecentInfo::Manager->new( filename => undef );
    $bm = $reconstructed->fromString( $xml );
    $reconstructed->entries->@* = $bm->@*;

    is $xbel, $reconstructed, "The reconstructed data structure is identical to the first parse";
}

done_testing();

__DATA__
<?xml version="1.0" encoding="UTF-8"?>
<xbel xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"
      xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info"
      version="1.0">
  <bookmark href="file:///home/corion/Projekte/MIME-Detect/Changes" added="2024-06-06T15:59:35.484580Z" modified="2024-06-06T15:59:35.484583Z" visited="2024-06-06T15:59:35.484580Z">
    <info>
      <metadata owner="http://freedesktop.org">
        <mime:mime-type type="text/plain"/>
        <bookmark:groups>
          <bookmark:group>geany</bookmark:group>
        </bookmark:groups>
        <bookmark:applications>
          <bookmark:application name="geany" exec="&apos;geany %u&apos;" modified="2024-06-06T15:59:35.484582Z" count="1"/>
        </bookmark:applications>
      </metadata>
    </info>
  </bookmark>
</xbel>
---
<?xml version="1.0" encoding="UTF-8"?>
<xbel xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"
      xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info"
      version="1.0"/>
