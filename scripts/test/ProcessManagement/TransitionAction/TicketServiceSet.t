# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# $origin: otrs - 4b5de865d1ad6c6a22b5bb35755d5ace2eab7d7b - scripts/test/ProcessManagement/TransitionAction/TicketServiceSet.t
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
my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
my $UserObject    = $Kernel::OM->Get('Kernel::System::User');
my $ModuleObject  = $Kernel::OM->Get('Kernel::System::ProcessManagement::TransitionAction::TicketServiceSet');

# define variables
my $UserID     = 1;
my $ModuleName = 'TicketServiceSet';
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
    {
        Name    => 'Service1' . $RandomID,
# ---
# ITSMCore
# ---
        TypeID      => 1,
        Criticality => '3 normal',
# ---
        ValidID => 1,
        UserID  => 1,
    },
    {
        Name    => 'Service2' . $RandomID,
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

$Success = $ServiceObject->CustomerUserServiceMemberAdd(
    CustomerUserLogin => $TestCustomerUserLogin,
    ServiceID         => $Services[1]->{ServiceID},
    Active            => 1,
    UserID            => 1,
);

# sanity test
$Self->True(
    $Success,
    "CustomerUserServiceMemberAdd() for user $TestCustomerUserLogin, and Service $Services[1]->{Name}"
        . " with true",
);

#
# Create a test tickets
#
my $TicketID1 = $TicketObject->TicketCreate(
    TN            => undef,
    Title         => $Services[0]->{ServiceID},
    QueueID       => 1,
    Lock          => 'unlock',
    Priority      => '3 normal',
    StateID       => 1,
    TypeID        => 1,
    Service       => undef,
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
                Service => 'open',
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
        Name   => 'Wrong Service',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                Service => 'NotExisting' . $RandomID,
            },
        },
        Success => 0,
    },
    {
        Name   => 'Wrong ServiceID',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                ServiceID => 'NotExisting' . $RandomID,
            },
        },
        Success => 0,
    },
    {
        Name   => 'Not assigned Service',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                Service => $Services[2]->{Name},
            },
        },
        Success => 0,
    },
    {
        Name   => 'Not Assigned ServiceID',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                ServiceID => $Services[2]->{ServiceID},
            },
        },
        Success => 0,
    },
    {
        Name   => "Ticket without customer with Service $Services[0]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket2,
            Config => {
                ServiceID => $Services[0]->{Name},
            },
        },
        Success => 0,
    },
    {
        Name   => "Ticket without customer with ServiceID $Services[1]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket2,
            Config => {
                ServiceID => $Services[0]->{ServiceID},
            },
        },
        Success => 0,
    },
    {
        Name   => "Correct Service $Services[0]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                Service => $Services[0]->{Name},
            },
        },
        Success => 1,
    },
    {
        Name   => "Correct Service $Services[1]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                Service => $Services[1]->{Name},
            },
        },
        Success => 1,
    },
    {
        Name   => "Correct ServiceID $Services[0]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                ServiceID => $Services[0]->{ServiceID},
            },
        },
        Success => 1,
    },
    {
        Name   => "Correct ServiceID $Services[1]->{Name}",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                ServiceID => $Services[1]->{ServiceID},
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
                ServiceID => '<OTRS_TICKET_Title>',
            },
        },
        Success => 1,
    },
    {
        Name   => "Wrong Ticket->NotExisting",
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket1,
            Config => {
                ServiceID => '<OTRS_TICKET_NotExisting>',
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
                Service => $Services[0]->{Name},
                UserID  => $TestUserID,
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
