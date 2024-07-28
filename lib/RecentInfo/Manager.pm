package RecentInfo::Manager 0.01;
use 5.020;
use experimental 'signatures';

use Exporter 'import';
use Module::Load;
our @EXPORT_OK = (qw(add_recent_file remove_recent_file recent_files));

=head1 SYNOPSIS

  use RecentInfo::Manager 'add_recent_file';
  add_recent_file('output.pdf');

=cut

# For Windows, those live as links under $ENV{APPDATA}\Microsoft\Windows\Recent
# similar information can be synthesized from there


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

our $implementation;
sub new($factoryclass, @args) {
    $implementation //= $factoryclass->_best_implementation();

    # return a new instance
    $implementation->new(@args);
}

sub _best_implementation( $class, @candidates ) {
    my $impl;
    if( $^O =~ /cygwin|MSWin32/ ) {
        $impl = 'RecentInfo::Manager::Win32';
    } else {
        $impl = 'RecentInfo::Manager::XBEL';
    }

    load $impl;
    return $impl;
};

1;
