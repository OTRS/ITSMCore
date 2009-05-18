# --
# Kernel/System/ITSMCIPAllocate.pm - all criticality, impact and priority allocation functions
# Copyright (C) 2001-2009 OTRS AG, http://otrs.org/
# --
# $Id: ITSMCIPAllocate.pm,v 1.12 2009-05-18 09:53:52 mh Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMCIPAllocate;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.12 $) [1];

=head1 NAME

Kernel::System::CIPAllocate - criticality, impact and priority allocation lib

=head1 SYNOPSIS

All criticality, impact and priority allocation functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::CIPAllocate;
    use Kernel::System::DB;
    use Kernel::System::Log;
    use Kernel::System::Main;

    my $ConfigObject = Kernel::Config->new();
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $CIPAllocateObject = Kernel::System::CIPAllocate->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (qw(DBObject ConfigObject LogObject)) {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    return $Self;
}

=item AllocateList()

return a 2d hash reference of allocations

    my $ListRef = $CIPAllocateObject->AllocateList(
        UserID => 1,
    );

=cut

sub AllocateList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # ask database
    $Self->{DBObject}->Prepare(
        SQL => 'SELECT criticality_id, impact_id, priority_id FROM cip_allocate',
    );

    # result list
    my %AllocateData;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $AllocateData{ $Row[1] }{ $Row[0] } = $Row[2];
    }

    return \%AllocateData;
}

=item AllocateUpdate()

update the allocation of criticality, impact and priority

    my $True = $CIPAllocateObject->AllocateUpdate(
        AllocateData => $DataRef,  # 2D hash reference
        UserID       => 1,
    );

=cut

sub AllocateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(AllocateData UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # check if allocate data is a hash reference
    if ( ref $Param{AllocateData} ne 'HASH' ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'AllocateData must be a 2D hash reference!',
        );
        return;
    }

    # check if allocate data is a 2D hash reference
    IMPACTID:
    for my $ImpactID ( keys %{ $Param{AllocateData} } ) {

        next IMPACTID if ref $Param{AllocateData}->{$ImpactID} eq 'HASH';

        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'AllocateData must be a 2D hash reference!'
        );
        return;
    }

    # delete old allocations
    $Self->{DBObject}->Do( SQL => 'DELETE FROM cip_allocate' );

    # insert new allocations
    for my $ImpactID ( keys %{ $Param{AllocateData} } ) {

        for my $CriticalityID ( keys %{ $Param{AllocateData}->{$ImpactID} } ) {

            # extract priority
            my $PriorityID = $Param{AllocateData}->{$ImpactID}->{$CriticalityID};

            # insert new allocation
            $Self->{DBObject}->Do(
                SQL => 'INSERT INTO cip_allocate '
                    . '(criticality_id, impact_id, priority_id, '
                    . 'create_time, create_by, change_time, change_by) VALUES '
                    . '(?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
                Bind => [
                    \$CriticalityID, \$ImpactID, \$PriorityID,
                    \$Param{UserID}, \$Param{UserID},
                ],
            );
        }
    }

    return 1;
}

=item PriorityAllocationGet()

return the priority id of a criticality and an impact

    my $PriorityID = $CIPAllocateObject->PriorityAllocationGet(
        CriticalityID => 321,
        ImpactID      => 123,
    );

=cut

sub PriorityAllocationGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(CriticalityID ImpactID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # get priority id from db
    $Self->{DBObject}->Prepare(
        SQL => 'SELECT priority_id FROM cip_allocate '
            . 'WHERE criticality_id = ? AND impact_id = ?',
        Bind => [ \$Param{CriticalityID}, \$Param{ImpactID} ],
        Limit => 1,
    );

    # fetch result
    my $PriorityID;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $PriorityID = $Row[0];
    }

    return $PriorityID;
}

1;

=back

=head1 TERMS AND CONDITIONS

This Software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see http://www.gnu.org/licenses/gpl-2.0.txt.

=cut

=head1 VERSION

$Revision: 1.12 $ $Date: 2009-05-18 09:53:52 $

=cut
