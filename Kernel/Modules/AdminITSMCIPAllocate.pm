# --
# Kernel/Modules/AdminITSMCIPAllocate.pm - admin frontend of criticality, impact and priority
# Copyright (C) 2001-2009 OTRS AG, http://otrs.org/
# --
# $Id: AdminITSMCIPAllocate.pm,v 1.11 2009-05-18 09:48:35 mh Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminITSMCIPAllocate;

use strict;
use warnings;

use Kernel::System::GeneralCatalog;
use Kernel::System::ITSMCIPAllocate;
use Kernel::System::Priority;
use Kernel::System::Valid;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.11 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (qw(ConfigObject ParamObject LogObject LayoutObject)) {
        if ( !$Self->{$Object} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Object!" );
        }
    }
    $Self->{GeneralCatalogObject} = Kernel::System::GeneralCatalog->new(%Param);
    $Self->{CIPAllocateObject}    = Kernel::System::ITSMCIPAllocate->new(%Param);
    $Self->{PriorityObject}       = Kernel::System::Priority->new(%Param);
    $Self->{ValidObject}          = Kernel::System::Valid->new(%Param);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # ------------------------------------------------------------ #
    # criticality, impact and priority allocation
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'CIPAllocate' ) {

        # get option lists
        my %ObjectOption;
        $ObjectOption{CriticalityList} = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::Core::Criticality',
        );
        $ObjectOption{ImpactList} = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::Core::Impact',
        );
        my %OptionPriorityList = $Self->{PriorityObject}->PriorityList(
            UserID => 1,
        );
        $ObjectOption{PriorityList} = \%OptionPriorityList;

        # get all PriorityIDs of the matrix
        my $AllocateData;
        for my $ImpactID ( keys %{ $ObjectOption{ImpactList} } ) {

            CRITICALITYID:
            for my $CriticalityID ( keys %{ $ObjectOption{CriticalityList} } ) {

                # get form param
                my $PriorityID = $Self->{ParamObject}->GetParam(
                    Param => "PriorityID" . $ImpactID . '-' . $CriticalityID
                ) || '';

                next CRITICALITYID if !$PriorityID;

                $AllocateData->{$ImpactID}->{$CriticalityID} = $PriorityID;
            }
        }

        # update allocations
        $Self->{CIPAllocateObject}->AllocateUpdate(
            AllocateData => $AllocateData,
            UserID       => 1,
        );

        return $Self->{LayoutObject}->Redirect( OP => "Action=$Self->{Action}" );
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
    else {

        # get option lists
        my %ObjectOption;
        $ObjectOption{CriticalityList} = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::Core::Criticality',
        );
        $ObjectOption{ImpactList} = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::Core::Impact',
        );
        my %OptionPriorityList = $Self->{PriorityObject}->PriorityList(
            UserID => 1,
        );
        $ObjectOption{PriorityList} = \%OptionPriorityList;

        # get allocation data
        my $AllocateData = $Self->{CIPAllocateObject}->AllocateList(
            UserID => 1,
        );

        my $AllocateMatrix;
        $AllocateMatrix->[0]->[0]->{Class} = 'Description';

        # generate table description (Impact)
        my $Counter1 = 1;
        for my $Impact (
            sort { $ObjectOption{ImpactList}->{$a} cmp $ObjectOption{ImpactList}->{$b} }
            keys %{ $ObjectOption{ImpactList} }
            )
        {
            $AllocateMatrix->[$Counter1]->[0]->{ObjectType}   = 'Impact';
            $AllocateMatrix->[$Counter1]->[0]->{ImpactKey}    = $Impact;
            $AllocateMatrix->[$Counter1]->[0]->{ObjectOption} = $ObjectOption{ImpactList}{$Impact};
            $AllocateMatrix->[$Counter1]->[0]->{Class}        = 'Description';
            $Counter1++;
        }

        # generate table description (Criticality)
        my $Counter2 = 1;
        for my $Criticality (
            sort { $ObjectOption{CriticalityList}->{$a} cmp $ObjectOption{CriticalityList}->{$b} }
            keys %{ $ObjectOption{CriticalityList} }
            )
        {
            $AllocateMatrix->[0]->[$Counter2]->{ObjectType}     = 'Criticality';
            $AllocateMatrix->[0]->[$Counter2]->{CriticalityKey} = $Criticality;
            $AllocateMatrix->[0]->[$Counter2]->{ObjectOption}
                = $ObjectOption{CriticalityList}{$Criticality};
            $AllocateMatrix->[0]->[$Counter2]->{Class} = 'Description';
            $Counter2++;
        }

        # generate content
        for my $Row ( 1 .. ( $Counter1 - 1 ) ) {
            for my $Column ( 1 .. ( $Counter2 - 1 ) ) {

                # extract keys
                my $ImpactKey      = $AllocateMatrix->[$Row]->[0]->{ImpactKey};
                my $CriticalityKey = $AllocateMatrix->[0]->[$Column]->{CriticalityKey};

                # create option string
                my $OptionStrg = $Self->{LayoutObject}->BuildSelection(
                    Name       => 'PriorityID' . $ImpactKey . '-' . $CriticalityKey,
                    Data       => $ObjectOption{PriorityList},
                    SelectedID => $AllocateData->{$ImpactKey}{$CriticalityKey} || '',
                );

                $AllocateMatrix->[$Row]->[$Column]->{OptionStrg} = $OptionStrg;
                $AllocateMatrix->[$Row]->[$Column]->{Class}      = 'Content';
            }
        }

        # output allocation matrix
        for my $RowRef ( @{$AllocateMatrix} ) {
            $Self->{LayoutObject}->Block(
                Name => 'CIPAllocateRow',
            );

            for my $Cell ( @{$RowRef} ) {
                $Self->{LayoutObject}->Block(
                    Name => 'CIPAllocateRowColumn' . $Cell->{Class},
                    Data => $Cell,
                );
            }
        }

        # output header and navbar
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

        # generate output
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminITSMCIPAllocate',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();

        return $Output;
    }
}

1;
