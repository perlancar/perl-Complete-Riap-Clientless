package Complete::Riap::Clientless;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Complete::Common qw(:all);
use List::MoreUtils qw(uniq);

our %SPEC;
require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(complete_riap_url);

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Riap-related completion routines (clientless version)',
    description => <<'_',

This is an alternative to <pm:Complete::Riap>. It does not utilize a <pm:Riap>
client but instead inspect `%SPEC` package variables directly. Thus, it can only
be used to complete local Riap URL's.

_
};

$SPEC{complete_riap_url} = {
    v => 1.1,
    summary => 'Complete Riap URL',
    description => <<'_',

Only supports local Perl schemes (e.g. `/Pkg/Subpkg/function` or
`pl:/Pkg/Subpkg/`).

_
    args => {
        %arg_word,
        type => {
            schema => ['str*', in=>['function','package']], # XXX other types?
            summary => 'Filter by entity type',
        },
        riap_client => {
            schema => 'obj*',
        },
    },
    result_naked => 1,
};
sub complete_riap_url {
    require Complete::Path;

    my %args = @_;

    my $word = $args{word} // ''; $word = '/' if !length($word);
    $word = "/$word" unless $word =~ m!\A/!;
    my $type = $args{type} // '';

    my $starting_path;
    my $result_prefix = '';
    if ($word =~ s!\A/!!) {
        $starting_path = '/';
        $result_prefix = '/';
    } elsif ($word =~ s!\Apl:/!/!) {
        $starting_path = 'pl:';
        $result_prefix = 'pl:';
    } else {
        return [];
    }

    my $res = Complete::Path::complete_path(
        word => $word,
        path_sep => '/',
        list_func => sub {
            my ($path, $intdir, $isint) = @_;

            my @res;
            for my $inc (@INC) {
                next if ref($inc);

                # list .pm files and directories
                my $dir = $inc . $path;
                #say "D:try opendir $dir ...";
                if (opendir my($dh), $dir) {
                    for my $e (readdir $dh) {
                        next if $e eq '.' || $e eq '..';
                        next unless $e =~ /\A\w+(\.\w+)?\z/;
                        my $is_dir = (-d "$dir/$e");
                        if ($is_dir) {
                            push @res, "$e/";
                        } elsif ($e =~ /(.+)\.pm\z/) {
                            push @res, "$1/";
                        }
                    }
                }

                # list regexp patterns inside a .pm file
                (my $file = $dir) =~ s!/\z!!; $file .= ".pm";
                {
                    no strict 'refs';
                    last unless -f $file;
                    #say "D:$file is a .pm ...";
                    (my $mod_pm = $path) =~ s!\A/!!; $mod_pm =~ s!/\z!!;
                    (my $mod = $mod_pm) =~ s!/!::!g;
                    $mod_pm .= ".pm";

                    eval { require $mod_pm; 1 } or last;
                    my $spec = \%{"$mod\::SPEC"};
                    for my $k (keys %$spec) {
                        my $type;
                        if ($k =~ /\A[$@%]/) {
                            $type = 'var';
                        } elsif ($k =~ /\A\w+\z/) {
                            $type = 'function';
                        } else {
                            next;
                        }
                        next if $args{type} && $args{type} ne $type;
                        push @res, $k;
                    }
                }

            }
            [sort(uniq(@res))];
        },
        starting_path => $starting_path,
        result_prefix => $result_prefix,
        is_dir_func => sub { }, # not needed, we already suffixed "dir" with /
    );

    {words=>$res, path_sep=>'/'};
}

1;
#ABSTRACT:

=head1 SYNOPSIS

 use Complete::Riap::Clientless qw(complete_riap_url);
 my $res = complete_riap_url(word => '/Te', type=>'package');
 # -> {word=>['/Template/', '/Test/', '/Text/'], path_sep=>'/'}


=cut
