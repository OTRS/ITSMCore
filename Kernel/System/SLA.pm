# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# $origin: otrs - 2cc2100e0cefcfafddd79e78b9f165481e6ba1f8 - Kernel/System/SLA.pm
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SLA;

use strict;
use warnings;

use Kernel::System::CheckItem;
use Kernel::System::Valid;
# ---
# ITSM
# ---
use Kernel::System::GeneralCatalog;
# ---

=head1 NAME

Kernel::System::SLA - sla lib

=head1 SYNOPSIS

All sla functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Encode;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::DB;
    use Kernel::System::SLA;

    my $ConfigObject = Kernel::Config->new();
    my $EncodeObject = Kernel::System::Encode->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $SLAObject = Kernel::System::SLA->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
        MainObject   => $MainObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (qw(DBObject ConfigObject EncodeObject LogObject MainObject)) {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }
    $Self->{CheckItemObject} = Kernel::System::CheckItem->new( %{$Self} );
    $Self->{ValidObject}     = Kernel::System::Valid->new( %{$Self} );
# ---
# ITSM
# ---
    $Self->{GeneralCatalogObject} = Kernel::System::GeneralCatalog->new( %{$Self} );
# ---

    # load generator preferences module
    my $GeneratorModule = $Self->{ConfigObject}->Get('SLA::PreferencesModule')
        || 'Kernel::System::SLA::PreferencesDB';
    if ( $Self->{MainObject}->Require($GeneratorModule) ) {
        $Self->{PreferencesObject} = $GeneratorModule->new( %{$Self} );
    }

    return $Self;
}

=item SLAList()

return a hash list of slas

    my %SLAList = $SLAObject->SLAList(
        ServiceID => 1,  # (optional)
        Valid     => 0,  # (optional) default 1 (0|1)
        UserID    => 1,
    );

=cut

sub SLAList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # set valid param
    if ( !defined $Param{Valid} ) {
        $Param{Valid} = 1;
    }

    # add ServiceID
    my %SQLTable;
    $SQLTable{sla} = 'sla s';
    my @SQLWhere;
    if ( $Param{ServiceID} ) {

        # quote
        $Param{ServiceID} = $Self->{DBObject}->Quote( $Param{ServiceID}, 'Integer' );

        $SQLTable{service} = 'service_sla r';
        push @SQLWhere, "s.id = r.sla_id AND r.service_id = $Param{ServiceID}";
    }

    # add valid part
    if ( $Param{Valid} ) {

        # create the valid list
        my $ValidIDs = join ', ', $Self->{ValidObject}->ValidIDsGet();

        push @SQLWhere, "s.valid_id IN ( $ValidIDs )";
    }

    # create the table and where strings
    my $TableString = join q{, }, values %SQLTable;
    my $WhereString = @SQLWhere ? ' WHERE ' . join q{ AND }, @SQLWhere : '';

    # ask database
    $Self->{DBObject}->Prepare(
        SQL => "SELECT s.id, s.name FROM $TableString $WhereString",
    );

    # fetch the result
    my %SLAList;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $SLAList{ $Row[0] } = $Row[1];
    }

    return %SLAList;
}

=item SLAGet()

Returns an SLA as a hash

    my %SLAData = $SLAObject->SLAGet(
        SLAID  => 123,
        UserID => 1,
    );

Returns:

    my %SLAData = (
          'SLAID'               => '2',
          'Name'                => 'Diamond Pacific - S2',
          'Calendar'            => '2',
          'FirstResponseTime'   => '60',  # in minutes according to business hours
          'FirstResponseNotify' => '70',  # in percent
          'UpdateTime'          => '360', # in minutes according to business hours
          'UpdateNotify'        => '70',  # in percent
          'SolutionTime'        => '960', # in minutes according to business hours
          'SolutionNotify'      => '80',  # in percent
          'ServiceIDs'          => [
                                     '4'
                                     '7'
                                     '8'
                                   ],
          'ValidID'             => '1',
          'Comment'             => 'Some Comment',
# ---
# ITSM
# ---
          'TypeID'                  => '5',
          'Type'                    => 'Incident',
          'MinTimeBetweenIncidents' => '4000',  # in minutes
# ---
          'CreateBy'            => '93',
          'CreateTime'          => '2011-06-16 22:54:54',
          'ChangeBy'            => '93',
          'ChangeTime'          => '2011-06-16 22:54:54',
    );

=cut

sub SLAGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(SLAID UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # check if result is already cached
    my $CacheKey = 'Cache::SLAGet::' . $Param{SLAID};
    if ( $Self->{$CacheKey} ) {
        return %{ $Self->{$CacheKey} };
    }

    # get sla from db
    $Self->{DBObject}->Prepare(
        SQL => 'SELECT id, name, calendar_name, first_response_time, first_response_notify, '
            . 'update_time, update_notify, solution_time, solution_notify, '
            . 'valid_id, comments, create_time, create_by, change_time, change_by '
# ---
# ITSM
# ---
            . ", type_id, min_time_bet_incidents "
# ---
            . 'FROM sla WHERE id = ?',
        Bind => [
            \$Param{SLAID},
        ],
        Limit => 1,
    );

    # fetch the result
    my %SLAData;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $SLAData{SLAID}               = $Row[0];
        $SLAData{Name}                = $Row[1];
        $SLAData{Calendar}            = $Row[2] || '';
        $SLAData{FirstResponseTime}   = $Row[3];
        $SLAData{FirstResponseNotify} = $Row[4];
        $SLAData{UpdateTime}          = $Row[5];
        $SLAData{UpdateNotify}        = $Row[6];
        $SLAData{SolutionTime}        = $Row[7];
        $SLAData{SolutionNotify}      = $Row[8];
        $SLAData{ValidID}             = $Row[9];
        $SLAData{Comment}             = $Row[10] || '';
        $SLAData{CreateTime}          = $Row[11];
        $SLAData{CreateBy}            = $Row[12];
        $SLAData{ChangeTime}          = $Row[13];
        $SLAData{ChangeBy}            = $Row[14];
# ---
# ITSM
# ---
        $SLAData{TypeID}                  = $Row[15];
        $SLAData{MinTimeBetweenIncidents} = $Row[16] || 0;
# ---
    }

    # check sla
    if ( !$SLAData{SLAID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "No such SLAID ($Param{SLAID})!",
        );
        return;
    }
# ---
# ITSM
# ---
    # get sla type list
    my $SLATypeList = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::SLA::Type',
    );
    $SLAData{Type} = $SLATypeList->{ $SLAData{TypeID} } || '';
# ---

    # get all service ids
    $Self->{DBObject}->Prepare(
        SQL  => 'SELECT service_id FROM service_sla WHERE sla_id = ? ORDER BY service_id ASC',
        Bind => [ \$SLAData{SLAID} ],
    );

    # fetch the result
    my @ServiceIDs;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        push @ServiceIDs, $Row[0];
    }

    # add the ids
    $SLAData{ServiceIDs} = \@ServiceIDs;

    # get sla preferences
    my %Preferences = $Self->SLAPreferencesGet( SLAID => $Param{SLAID} );

    # merge hash
    if (%Preferences) {
        %SLAData = ( %SLAData, %Preferences );
    }

    # cache the result
    $Self->{$CacheKey} = \%SLAData;

    return %SLAData;
}

=item SLALookup()

returns the name or the sla id

    my $SLAName = $SLAObject->SLALookup(
        SLAID => 123,
    );

    or

    my $SLAID = $SLAObject->SLALookup(
        Name => 'SLA Name',
    );

=cut

sub SLALookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{SLAID} && !$Param{Name} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need SLAID or Name!',
        );
        return;
    }

    if ( $Param{SLAID} ) {

        # check cache
        my $CacheKey = 'Cache::SLALookup::ID::' . $Param{SLAID};
        if ( defined $Self->{$CacheKey} ) {
            return $Self->{$CacheKey};
        }

        # lookup
        $Self->{DBObject}->Prepare(
            SQL   => 'SELECT name FROM sla WHERE id = ?',
            Bind  => [ \$Param{SLAID}, ],
            Limit => 1,
        );

        # fetch the result
        my $Name;
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            $Name = $Row[0];
        }

        # cache
        $Self->{$CacheKey} = $Name;

        return $Name;
    }
    else {

        # check cache
        my $CacheKey = 'Cache::SLALookup::Name::' . $Param{Name};
        if ( defined $Self->{$CacheKey} ) {
            return $Self->{$CacheKey};
        }

        # lookup
        $Self->{DBObject}->Prepare(
            SQL   => 'SELECT id FROM sla WHERE name = ?',
            Bind  => [ \$Param{Name} ],
            Limit => 1,
        );

        # fetch the result
        my $SLAID;
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            $SLAID = $Row[0];
        }

        # cache
        $Self->{$CacheKey} = $SLAID;

        return $SLAID;
    }
}

=item SLAAdd()

add a sla

    my $SLAID = $SLAObject->SLAAdd(
        ServiceIDs          => [ 1, 5, 7 ],  # (optional)
        Name                => 'SLA Name',
        Calendar            => 'Calendar1',  # (optional)
        FirstResponseTime   => 120,          # (optional)
        FirstResponseNotify => 60,           # (optional) notify agent if first response escalation is 60% reached
        UpdateTime          => 180,          # (optional)
        UpdateNotify        => 80,           # (optional) notify agent if update escalation is 80% reached
        SolutionTime        => 580,          # (optional)
        SolutionNotify      => 80,           # (optional) notify agent if solution escalation is 80% reached
        ValidID             => 1,
        Comment             => 'Comment',    # (optional)
        UserID              => 1,
# ---
# ITSM
# ---
        TypeID                  => 2,
        MinTimeBetweenIncidents => 3443,     # (optional)
# ---
    );

=cut

sub SLAAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
# ---
# ITSM
# ---
#    for my $Argument (qw(Name ValidID UserID)) {
    for my $Argument (qw(Name ValidID UserID TypeID)) {
# ---
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check service ids
    if ( defined $Param{ServiceIDs} && ref $Param{ServiceIDs} ne 'ARRAY' ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'ServiceIDs needs to be an array reference!',
        );
        return;
    }

    # set default values
    $Param{ServiceIDs}          ||= [];
    $Param{Calendar}            ||= '';
    $Param{Comment}             ||= '';
    $Param{FirstResponseTime}   ||= 0;
    $Param{FirstResponseNotify} ||= 0;
    $Param{UpdateTime}          ||= 0;
    $Param{UpdateNotify}        ||= 0;
    $Param{SolutionTime}        ||= 0;
    $Param{SolutionNotify}      ||= 0;
# ---
# ITSM
# ---
    $Param{MinTimeBetweenIncidents} ||= 0;
# ---

    # cleanup given params
    for my $Argument (qw(Name Comment)) {
        $Self->{CheckItemObject}->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # find exiting sla's with the same name
    $Self->{DBObject}->Prepare(
        SQL   => 'SELECT id FROM sla WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $NoAdd;
    while ( $Self->{DBObject}->FetchrowArray() ) {
        $NoAdd = 1;
    }

    # abort insert of new sla, if name already exists
    if ($NoAdd) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Can't add new SLA! '$Param{Name}' already exists.",
        );
        return;
    }

    # add sla to database
    return if !$Self->{DBObject}->Do(
# ---
# ITSM
# ---
#        SQL => 'INSERT INTO sla '
#            . '(name, calendar_name, first_response_time, first_response_notify, '
#            . 'update_time, update_notify, solution_time, solution_notify, '
#            . 'valid_id, comments, create_time, create_by, change_time, change_by) VALUES '
#            . '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
#        Bind => [
#            \$Param{Name},                \$Param{Calendar},       \$Param{FirstResponseTime},
#            \$Param{FirstResponseNotify}, \$Param{UpdateTime},     \$Param{UpdateNotify},
#            \$Param{SolutionTime},        \$Param{SolutionNotify}, \$Param{ValidID}, \$Param{Comment},
#            \$Param{UserID}, \$Param{UserID},
#        ],
        SQL => 'INSERT INTO sla '
            . '(name, calendar_name, first_response_time, first_response_notify, '
            . 'update_time, update_notify, solution_time, solution_notify, '
            . 'valid_id, comments, create_time, create_by, change_time, change_by, '
            . 'type_id, min_time_bet_incidents) VALUES '
            . '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?, ?, ?)',
        Bind => [
            \$Param{Name},                    \$Param{Calendar},       \$Param{FirstResponseTime},
            \$Param{FirstResponseNotify},     \$Param{UpdateTime},     \$Param{UpdateNotify},
            \$Param{SolutionTime},            \$Param{SolutionNotify}, \$Param{ValidID}, \$Param{Comment},
            \$Param{UserID}, \$Param{UserID}, \$Param{TypeID},         \$Param{MinTimeBetweenIncidents},
        ],
# ---
    );

    # get sla id
    return if !$Self->{DBObject}->Prepare(
        SQL   => 'SELECT id FROM sla WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $SLAID;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $SLAID = $Row[0];
    }

    # check sla id
    if ( !$SLAID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Can't find SLAID for '$Param{Name}'!",
        );
        return;
    }

    # remove all existing allocations
    $Self->{DBObject}->Do(
        SQL  => 'DELETE FROM service_sla WHERE sla_id = ?',
        Bind => [ \$SLAID ],
    );

    # add the new allocations
    for my $ServiceID ( @{ $Param{ServiceIDs} } ) {

        # add one allocation
        $Self->{DBObject}->Do(
            SQL  => 'INSERT INTO service_sla (service_id, sla_id) VALUES (?, ?)',
            Bind => [ \$ServiceID, \$SLAID ],
        );
    }

    return $SLAID;
}

=item SLAUpdate()

update a existing sla

    my $True = $SLAObject->SLAUpdate(
        SLAID               => 2,
        ServiceIDs          => [ 1, 2, 3 ],  # (optional)
        Name                => 'Service Name',
        Calendar            => 'Calendar1',  # (optional)
        FirstResponseTime   => 120,          # (optional)
        FirstResponseNotify => 60,           # (optional) notify agent if first response escalation is 60% reached
        UpdateTime          => 180,          # (optional)
        UpdateNotify        => 80,           # (optional) notify agent if update escalation is 80% reached
        SolutionTime        => 580,          # (optional)
        SolutionNotify      => 80,           # (optional) notify agent if solution escalation is 80% reached
        ValidID             => 1,
        Comment             => 'Comment',    # (optional)
        UserID              => 1,
# ---
# ITSM
# ---
        TypeID                  => 2,
        MinTimeBetweenIncidents => 3443,  # (optional)
# ---
    );

=cut

sub SLAUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
# ---
# ITSM
# ---
#    for my $Argument (qw(SLAID Name ValidID UserID)) {
    for my $Argument (qw(SLAID Name ValidID UserID TypeID)) {
# ---
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check service ids
    if ( defined $Param{ServiceIDs} && ref $Param{ServiceIDs} ne 'ARRAY' ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'ServiceIDs need to be an array reference!',
        );
        return;
    }

    # set default values
    $Param{ServiceIDs}          ||= [];
    $Param{Calendar}            ||= '';
    $Param{Comment}             ||= '';
    $Param{FirstResponseTime}   ||= 0;
    $Param{FirstResponseNotify} ||= 0;
    $Param{UpdateTime}          ||= 0;
    $Param{UpdateNotify}        ||= 0;
    $Param{SolutionTime}        ||= 0;
    $Param{SolutionNotify}      ||= 0;
# ---
# ITSM
# ---
    $Param{MinTimeBetweenIncidents} ||= 0;
# ---

    # cleanup given params
    for my $Argument (qw(Name Comment)) {
        $Self->{CheckItemObject}->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # find exiting sla's with the same name
    return if !$Self->{DBObject}->Prepare(
        SQL   => 'SELECT id FROM sla WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $Update = 0;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        if ( $Row[0] != $Param{SLAID} ) {
            $Update = $Row[0];
        }
    }

    # abort update of sla, if name already exists
    if ($Update) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Can't update SLA! '$Param{Name}' already exists.",
        );
        return;
    }

    # reset cache
    delete $Self->{ 'Cache::SLAGet::' . $Param{SLAID} };
    delete $Self->{ 'Cache::SLALookup::Name::' . $Param{Name} };
    delete $Self->{ 'Cache::SLALookup::ID::' . $Param{SLAID} };

    # update sla
    return if !$Self->{DBObject}->Do(
# ---
# ITSM
# ---
#        SQL => 'UPDATE sla SET name = ?, calendar_name = ?, '
#            . 'first_response_time = ?, first_response_notify = ?, '
#            . 'update_time = ?, update_notify = ?, solution_time = ?, solution_notify = ?, '
#            . 'valid_id = ?, comments = ?, change_time = current_timestamp, change_by = ? '
#            . 'WHERE id = ?',
#        Bind => [
#            \$Param{Name},                \$Param{Calendar},       \$Param{FirstResponseTime},
#            \$Param{FirstResponseNotify}, \$Param{UpdateTime},     \$Param{UpdateNotify},
#            \$Param{SolutionTime},        \$Param{SolutionNotify}, \$Param{ValidID}, \$Param{Comment},
#            \$Param{UserID}, \$Param{SLAID},
#        ],
        SQL => 'UPDATE sla SET name = ?, calendar_name = ?, '
            . 'first_response_time = ?, first_response_notify = ?, '
            . 'update_time = ?, update_notify = ?, solution_time = ?, solution_notify = ?, '
            . 'valid_id = ?, comments = ?, change_time = current_timestamp, change_by = ?, '
            . 'type_id = ?, min_time_bet_incidents = ? '
            . 'WHERE id = ?',
        Bind => [
            \$Param{Name},                \$Param{Calendar},   \$Param{FirstResponseTime},
            \$Param{FirstResponseNotify}, \$Param{UpdateTime}, \$Param{UpdateNotify},
            \$Param{SolutionTime}, \$Param{SolutionNotify}, \$Param{ValidID}, \$Param{Comment},
            \$Param{UserID}, \$Param{TypeID}, \$Param{MinTimeBetweenIncidents}, \$Param{SLAID},
        ],
# ---
    );

    # remove all existing allocations
    return if !$Self->{DBObject}->Do(
        SQL  => 'DELETE FROM service_sla WHERE sla_id = ?',
        Bind => [ \$Param{SLAID}, ]
    );

    # add the new allocations
    for my $ServiceID ( @{ $Param{ServiceIDs} } ) {

        # add one allocation
        return if !$Self->{DBObject}->Do(
            SQL  => 'INSERT INTO service_sla (service_id, sla_id) VALUES (?, ?)',
            Bind => [ \$ServiceID, \$Param{SLAID} ],
        );
    }

    return 1;
}

=item SLAPreferencesSet()

set SLA preferences

    $SLAObject->SLAPreferencesSet(
        SLAID => 123,
        Key       => 'UserComment',
        Value     => 'some comment',
        UserID    => 123,
    );

=cut

sub SLAPreferencesSet {
    my $Self = shift;

    return $Self->{PreferencesObject}->SLAPreferencesSet(@_);
}

=item SLAPreferencesGet()

get SLA preferences

    my %Preferences = $SLAObject->SLAPreferencesGet(
        SLAID => 123,
        UserID    => 123,
    );

=cut

sub SLAPreferencesGet {
    my $Self = shift;

    return $Self->{PreferencesObject}->SLAPreferencesGet(@_);
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
