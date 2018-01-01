# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::FilterContent::Fred;

use strict;
use warnings;
use URI::Escape;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Fred',
);

=head1 NAME

Kernel::Output::HTML::OutputFilterFred

=head1 SYNOPSIS

a output filter module specially for developer

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # perhaps no output is generated
    die 'Fred: At the moment, your code generates no output!' if !$Param{Data};

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # do not show the debug bar in Fred's setting window
    if ( $LayoutObject->{Action} && $LayoutObject->{Action} eq 'DevelFred' ) {
        return 1;
    }

    # do nothing if output is an attachment download or AJAX request
    if (
        ${ $Param{Data} } =~ /^Content-Disposition: attachment;/mi
        || ${ $Param{Data} } =~ /^Content-Disposition: inline;/mi
        )
    {
        return 1;
    }

    # do nothing if it is a redirect
    if (
        ${ $Param{Data} } =~ /^Status: 302 Moved/mi
        && ${ $Param{Data} } =~ /^location:/mi
        && length( ${ $Param{Data} } ) < 800
        )
    {
        print STDERR "REDIRECT\n";
        return 1;
    }

    # do nothing if it is fred it self
    if ( ${ $Param{Data} } =~ m{Fred-Setting<\/title>}msx ) {
        print STDERR "CHANGE FRED SETTING\n";
        return 1;
    }

    # do nothing if it does not contain the <html> element, might be
    # an embedded layout rendering
    if ( ${ $Param{Data} } !~ m{<html[^>]*>}msx ) {
        return 1;
    }

    # get data of the activated modules
    my $ModuleForRef   = $Kernel::OM->Get('Kernel::Config')->Get('Fred::Module');
    my $ModulesDataRef = {};
    for my $Module ( sort keys %{$ModuleForRef} ) {
        if ( $ModuleForRef->{$Module}->{Active} ) {
            $ModulesDataRef->{$Module} = {};
        }
    }

    for my $ModuleName ( sort keys %{$ModulesDataRef} ) {

        $Kernel::OM->Get( 'Kernel::System::Fred::' . $ModuleName )->DataGet(
            ModuleRef      => $ModulesDataRef->{$ModuleName},
            HTMLDataRef    => $Param{Data},
            FredModulesRef => $ModulesDataRef,
        );

        $Kernel::OM->Get( 'Kernel::Output::HTML::Fred::' . $ModuleName )->CreateFredOutput(
            ModuleRef => $ModulesDataRef->{$ModuleName},
        );
    }

    # build the content string
    my $Output = '';
    if ( $ModulesDataRef->{Console}->{Output} ) {
        $Output .= $ModulesDataRef->{Console}->{Output};
        delete $ModulesDataRef->{Console};
    }
    for my $Module ( sort keys %{$ModulesDataRef} ) {
        $Output .= $ModulesDataRef->{$Module}->{Output} || '';
    }

    my $JSOutput = '';
    $Output =~ s{(<script.+?/script>)}{
        $JSOutput .= $1;
        "";
    }smxeg;

    # Put output in the Fred Container
    $Output = $LayoutObject->Output(
        TemplateFile => 'DevelFredContainer',
        Data         => {
            Data => $Output
        },
    );

    # include the fred output in the original output
    if ( ${ $Param{Data} } !~ s/(\<body(|.+?)\>)/$1\n$Output\n\n\n\n/mx ) {
        ${ $Param{Data} } =~ s/^(.)/\n$Output\n\n\n\n$1/mx;
    }

    # Inject JS at the end of the body
    ${ $Param{Data} } =~ s{</body>}{$JSOutput\n\t</body>}smx;

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
