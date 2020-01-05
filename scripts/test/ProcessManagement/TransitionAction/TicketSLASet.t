# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# $origin: otrs - 77d4495533edfdbd2370353edad87839ee636357 - scripts/test/ProcessManagement/TransitionAction/TicketSLASet.t
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
my $HelperObject  = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');
my $SLAObject     = $Kernel::OM->Get('Kernel::System::SLA');
my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
my $UserObject    = $Kernel::OM->Get('Kernel::System::User');
my $ModuleObject  = $Kernel::OM->Get('Kernel::System::ProcessManagement::TransitionAction::TicketSLASet');

# define variables
my $UserID     = 1;
my $ModuleName = 'TicketSLASet';
my $RandomID   = $HelperObject->GetRandomID();

# add a customer user
my $TestCustomerUserLogin = $HelperObject->TestCustomerUserCreate();

# set user details
my $TestUserLogin = $HelperObject->TestUserCreate();
my $TestUserID    = $UserObject->UserLookup(
    UserLogin => $TestUserLogin,
);

#
# Create new services
#
my @Services = (
    {
        Name    => 'Service0' . $RandomID,
# ---
# ITSMCore
# ---
        TypeID      => 1,
        Criticality => '3 normal',
# ---
        ValidID => 1,
        UserID  => 1,
    },
);

for my $ServiceData (@Services) {
    my $ServiceID = $ServiceObject->ServiceAdd( %{$ServiceData} );

    # sanity test
    $Self->IsNot(
        $ServiceID,
        undef,
        "ServiceAdd() for $ServiceData->{Name}, ServiceID should not be undef",
    );

    # store the ServiceID
    $ServiceData->{ServiceID} = $ServiceID;
}

#
# Create new SLAs
#
my @SLAs = (
    {
        Name       => 'SLA0' . $RandomID,
        ServiceIDs => [ $Services[0]->{ServiceID} ],
# ---
# ITSMCore
# ---
        TypeID => 1,
# ---
        ValidID    => 1,
        UserID     => 1,
    },
    {
        Name       => 'SLA1' . $RandomID,
        ServiceIDs => [ $Services[0]->{ServiceID} ],
# ---
# ITSMCore
# ---
        TypeID => 1,
# ---
        ValidID    => 1,
        UserID     => 1,
    },
    {
        Name       => 'SLA2' . $RandomID,
        ServiceIDs => [],
# ---
# ITSMCore
# ---
        TypeID => 1,
# ---
        ValidID    => 1,
        UserID     => 1,
    },
);

for my $SLAData (@SLAs) {
    my $SLAID = $SLAObject->SLAAdd( %{$SLAData} );

    # sanity test
    $Self->IsNot(
        $SLAID,
        undef,
        "SLAAdd() for $SLAData->{Name}, SLAID should not be undef",
    );

    # store the SLAID
    $SLAData->{SLAID} = $SLAID;
}

#
# Assign services to customer (0 and 1)
#
my $Success = $ServiceObject->CustomerUserServiceMemberAdd(
    CustomerUserLogin => $TestCustomerUserLogin,
    ServiceID         => $Services[0]->{ServiceID},
    Active            => 1,
    UserID            => 1,
);

# sanity test
$Self->True(
    $Success,
    "CustomerUserServiceMemberAdd() for user $TestCustomerUserLogin, and Service $Services[0]->{Name}"
        . " with true",
);

#
# Create a test tickets
#
my $TicketID1 = $TicketObject->TicketCreate(
    TN            => undef,
    Title         => $SLAs[0]->{SLAID},
    QueueID       => 1,
    Lock          => 'unlock',
    Priority      => '3 normal',
    StateID       => 1,
    TypeID        => 1,
    Service       => $Services[0]->{Name},
    SLA           => undef,
    CustomerID    => undef,
    CustomerUser  => $TestCustomerUserLogin,
    OwnerID       => 1,
    ResponsibleID => 1,
    ArchiveFlag   => undef,
    UserID        => $UserID,
);

# sanity checks
$Self->True(
    $TicketID1,
    "TicketCreate() - $TicketID1",
);

my %Ticket1 = $TicketObject->TicketGet(
    TicketID => $TicketID1,
    UserID   => $UserID,
);
$Self->True(
    IsHashRefWithData( \%Ticket1 ),
    "TicketGet() - Get Ticket with ID $TicketID1.",
);

my $TicketID2 = $TicketObject->TicketCreate(
    TN            => undef,
    Title         => 'test',
    QueueID       => 1,
    Lock          => 'unlock',
    Priority      => '3 normal',
    StateID       => 1,
    TypeID        => 1,
    Service       => undef,
    SLA           => undef,
    CustomerID    => undef,
    CustomerUser  => undef,
    OwnerID       => 1,
    ResponsibleID => 1,
    ArchiveFlag   => undef,
    UserID        => $UserID,
);

# sanity checks
$Self->True(
    $TicketID2,
    "TicketCreate() - $TicketID2",
);

my %Ticket2 = $TicketObject->TicketGet(
    TicketID => $TicketID2,
    UserID   => $UserID,
);
$Self->True(
    IsHashRefWithData( \%Ticket2 ),
    "TicketGet() - Get Ticket with ID $TicketID2.",
);

# Run() tests
my @Tests = (
    {
        Name    => 'No Params',
        Config  => undef,
        Success => 0,
    },
    {
        Name   => 'No UserID',
        Config => {
            UserID => undef,
            Ticket => \%Ticket1,
            Config => {
                CustomerID => 'test',
            },
        },
        Success => 0,
    },
    {
        Name   => 'No Ticket',
        Config => {
            UserID => $UserID,
            Ticket => undef,
            Config => {
                CustomerID => 'test',
            },
        },
        Success => 0,
    },
    {
        Name   => 'No Config',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {},
        },
        Success => 0,
    },
    {
        Name   => 'Wrong Config',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                NoAgentNotify => 0,
            },
        },
        Success => 0,
    },
    {
        Name   => 'Wrong Ticket Format',
        Config => {
            UserID => $UserID,
            Ticket => 1,
            Config => {
                SLA => 'open',
            },
        },
        Success => 0,
    },
    {
        Name   => 'Wrong Config Format',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Wrong SLA',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLA => 'NotExisting' . $RandomID,
            },
        },
        Success => 0,
    },
    {
        Name   => 'Wrong SLAID',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLAID => 'NotExisting' . $RandomID,
            },
        },
        Success => 0,
    },
    {
        Name   => 'Not assigned SLA',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLA => $SLAs[2]->{Name},
            },
        },
        Success => 0,
    },
    {
        Name   => 'Not Assigned SLAID',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLAID => $SLAs[2]->{SLAID},
            },
        },
        Success => 0,
    },
    {
        Name   => "Ticket without service with SLA $SLAs[0]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket2,
            Config => {
                SLAID => $SLAs[0]->{Name},
            },
        },
        Success => 0,
    },
    {
        Name   => "Ticket without service with SLAID $SLAs[1]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket2,
            Config => {
                SLAID => $SLAs[0]->{SLAID},
            },
        },
        Success => 0,
    },
    {
        Name   => "Correct SLA $SLAs[0]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLA => $SLAs[0]->{Name},
            },
        },
        Success => 1,
    },
    {
        Name   => "Correct SLA $SLAs[1]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLA => $SLAs[1]->{Name},
            },
        },
        Success => 1,
    },
    {
        Name   => "Correct SLAID $SLAs[0]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLAID => $SLAs[0]->{SLAID},
            },
        },
        Success => 1,
    },
    {
        Name   => "Correct SLAID $SLAs[1]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLAID => $SLAs[0]->{SLAID},
            },
        },
        Success => 1,
    },
    {
        Name   => "Correct Ticket->Title",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLAID => '<OTRS_TICKET_Title>',
            },
        },
        Success => 1,
    },
    {
        Name   => "Correct Ticket->NotExisting",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLAID => '<OTRS_TICKET_NotExisting>',
            },
        },
        Success => 0,
    },
    {
        Name   => "Correct Using Different UserID",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                SLA    => $SLAs[0]->{Name},
                UserID => $TestUserID,
            },
        },
        Success => 1,
    },
);

for my $Test (@Tests) {

    # make a deep copy to avoid changing the definition
    my $OrigTest = Storable::dclone($Test);

    my $Success = $ModuleObject->Run(
        %{ $Test->{Config} },
        ProcessEntityID          => 'P1',
        ActivityEntityID         => 'A1',
        TransitionEntityID       => 'T1',
        TransitionActionEntityID => 'TA1',
    );

    if ( $Test->{Success} ) {

        $Self->True(
            $Success,
            "$ModuleName Run() - Test:'$Test->{Name}' | excecuted with True"
        );

        # get ticket
        my $TicketID = $TicketID1;
        if ( $Test->{Config}->{Ticket}->{TicketID} eq $TicketID2 ) {
            $TicketID = $TicketID2;
        }
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );

        ATTRIBUTE:
        for my $Attribute ( sort keys %{ $Test->{Config}->{Config} } ) {

            $Self->True(
                defined $Ticket{$Attribute},
                "$ModuleName - Test:'$Test->{Name}' | Attribute: $Attribute for TicketID:"
                    . " $TicketID exists with True",
            );

            my $ExpectedValue = $Test->{Config}->{Config}->{$Attribute};
            if (
                $OrigTest->{Config}->{Config}->{$Attribute}
                =~ m{\A<OTRS_TICKET_([A-Za-z0-9_]+)>\z}msx
                )
            {
                $ExpectedValue = $Ticket{$1} // '';
                $Self->IsNot(
                    $Test->{Config}->{Config}->{$Attribute},
                    $OrigTest->{Config}->{Config}->{$Attribute},
                    "$ModuleName - Test:'$Test->{Name}' | Attribute: $Attribute value: $OrigTest->{Config}->{Config}->{$Attribute} should been replaced",
                );
            }

            $Self->Is(
                $Ticket{$Attribute},
                $ExpectedValue,
                "$ModuleName - Test:'$Test->{Name}' | Attribute: $Attribute for TicketID:"
                    . " $TicketID match expected value",
            );
        }

        if ( $OrigTest->{Config}->{Config}->{UserID} ) {
            $Self->Is(
                $Test->{Config}->{Config}->{UserID},
                undef,
                "$ModuleName - Test:'$Test->{Name}' | Attribute: UserID for TicketID:"
                    . " $TicketID should be removed (as it was used)",
            );
        }
    }
    else {
        $Self->False(
            $Success,
            "$ModuleName Run() - Test:'$Test->{Name}' | executed with False"
        );
    }
}

#
# Destructors to remove our Testitems
#

# Tickets
my $Delete = $TicketObject->TicketDelete(
    TicketID => $TicketID1,
    UserID   => 1,
);
$Self->True(
    $Delete,
    "TicketDelete() - $TicketID2",
);

$Delete = $TicketObject->TicketDelete(
    TicketID => $TicketID1,
    UserID   => 1,
);
$Self->True(
    $Delete,
    "TicketDelete() - $TicketID2",
);

# SLA
for my $SLAData (@SLAs) {
    my $Success = $SLAObject->SLAUpdate(
        %{$SLAData},
        ValidID => 2,
    );

    # sanity test
    $Self->True(
        $Success,
        "SLAUpdate() for $SLAData->{Name}, Set SLA to invalid with true",
    );
}

# Services
for my $ServiceData (@Services) {
    my $Success = $ServiceObject->ServiceUpdate(
        %{$ServiceData},
        ValidID => 2,
    );

    # sanity test
    $Self->True(
        $Success,
        "ServiceUpdate() for $ServiceData->{Name}, Set service to invalid with true",
    );
}

1;
