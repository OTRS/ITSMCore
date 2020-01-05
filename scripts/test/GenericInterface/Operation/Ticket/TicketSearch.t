# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# $origin: otrs - 77d4495533edfdbd2370353edad87839ee636357 - scripts/test/GenericInterface/Operation/Ticket/TicketSearch.t
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;

use vars (qw($Self));

use MIME::Base64;

use Kernel::GenericInterface::Debugger;
use Kernel::GenericInterface::Operation::Ticket::TicketSearch;
use Kernel::GenericInterface::Operation::Session::SessionCreate;

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

# skip SSL certificate verification
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreSystemConfiguration => 1,
        SkipSSLVerify              => 1,
    },
);
my $HelperObject = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# get a random id
my $RandomID = int rand 1_000_000_000;

$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# get time object
my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

# get the start time for the test
my $StartTime = $TimeObject->SystemTime();

# get user object
my $UserObject = $Kernel::OM->Get('Kernel::System::User');

# create a new user for current test
my $UserID = $UserObject->UserAdd(
    UserFirstname => 'Test',
    UserLastname  => 'User',
    UserLogin     => 'TestUser' . $RandomID,
    UserPw        => 'some-pass',
    UserEmail     => 'test' . $RandomID . 'email@example.com',
    ValidID       => 1,
    ChangeUserID  => 1,
);

$Self->True(
    $UserID,
    'User Add ()',
);

# create type object
my $TypeObject = $Kernel::OM->Get('Kernel::System::Type');

# create new type
my $TypeID = $TypeObject->TypeAdd(
    Name    => 'TestType' . $RandomID,
    ValidID => 1,
    UserID  => 1,
);

# sanity check
$Self->True(
    $TypeID,
    "TypeAdd() - create testing type",
);

my %TypeData = $TypeObject->TypeGet(
    ID => $TypeID,
);

# sanity check
$Self->True(
    IsHashRefWithData( \%TypeData ),
    "QueueGet() - for testing type",
);

# get service object
my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');

# create new service
my $ServiceID = $ServiceObject->ServiceAdd(
    Name    => 'TestService' . $RandomID,
# ---
# ITSMCore
# ---
    TypeID      => 1,
    Criticality => '3 normal',
# ---
    ValidID => 1,
    UserID  => 1,
);

# sanity check
$Self->True(
    $ServiceID,
    "ServiceAdd() - create testing service",
);

my %ServiceData = $ServiceObject->ServiceGet(
    ServiceID => $ServiceID,
    UserID    => 1,
);

# sanity check
$Self->True(
    IsHashRefWithData( \%ServiceData ),
    "ServiceGet() - for testing service",
);

# start DynamicFields
my @TestDynamicFields;

my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

# create a dynamic field
my $FieldID1 = $DynamicFieldObject->DynamicFieldAdd(
    Name       => "DFT1$RandomID",
    Label      => 'Description',
    FieldOrder => 9991,
    FieldType  => 'Text',
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 'Default',
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);

push @TestDynamicFields, $FieldID1;

my $Field1Config = $DynamicFieldObject->DynamicFieldGet(
    ID => $FieldID1,
);

# create a dynamic field
my $FieldID2 = $DynamicFieldObject->DynamicFieldAdd(
    Name       => "DFT2$RandomID",
    Label      => 'Description',
    FieldOrder => 9992,
    FieldType  => 'Dropdown',
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue   => 'Default',
        PossibleValues => {
            ticket1_field2 => 'ticket1_field2',
            ticket2_field2 => 'ticket2_field2',
        },
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);

my $Field2Config = $DynamicFieldObject->DynamicFieldGet(
    ID => $FieldID2,
);

push @TestDynamicFields, $FieldID2;

# create a dynamic field
my $FieldID3 = $DynamicFieldObject->DynamicFieldAdd(
    Name       => "DFT3$RandomID",
    Label      => 'Description',
    FieldOrder => 9993,
    FieldType  => 'DateTime',        # mandatory, selects the DF backend to use for this field
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 'Default',
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);

my $Field3Config = $DynamicFieldObject->DynamicFieldGet(
    ID => $FieldID3,
);

push @TestDynamicFields, $FieldID3;

# create a dynamic field
my $FieldID4 = $DynamicFieldObject->DynamicFieldAdd(
    Name       => "DFT4$RandomID",
    Label      => 'Description',
    FieldOrder => 9993,
    FieldType  => 'Checkbox',        # mandatory, selects the DF backend to use for this field
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 'Default',
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);

my $Field4Config = $DynamicFieldObject->DynamicFieldGet(
    ID => $FieldID4,
);

push @TestDynamicFields, $FieldID4;

# create a dynamic field
my $FieldID5 = $DynamicFieldObject->DynamicFieldAdd(
    Name       => "DFT5$RandomID",
    Label      => 'Description',
    FieldOrder => 9995,
    FieldType  => 'Multiselect',     # mandatory, selects the DF backend to use for this field
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue   => [ 'ticket2_field5', 'ticket4_field5' ],
        PossibleValues => {
            ticket1_field5 => 'ticket1_field51',
            ticket2_field5 => 'ticket2_field52',
            ticket3_field5 => 'ticket2_field53',
            ticket4_field5 => 'ticket2_field54',
            ticket5_field5 => 'ticket2_field55',
        },
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);

my $Field5Config = $DynamicFieldObject->DynamicFieldGet(
    ID => $FieldID5,
);

push @TestDynamicFields, $FieldID5;

# create a dynamic field
my $FieldID6 = $DynamicFieldObject->DynamicFieldAdd(
    Name       => "DFT6$RandomID",
    Label      => 'Description',
    FieldOrder => 9993,
    FieldType  => 'Date',            # mandatory, selects the DF backend to use for this field
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 'Default',
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);

my $Field6Config = $DynamicFieldObject->DynamicFieldGet(
    ID => $FieldID6,
);

push @TestDynamicFields, $FieldID6;

# finish DynamicFields

# create ticket object
my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

# create 3 tickets

#ticket id container
my @TicketIDs;

# create ticket 1
my $TicketID1 = $TicketObject->TicketCreate(
    Title        => 'Ticket One Title ' . $RandomID,
    Queue        => 'Raw',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'new',
    CustomerID   => '123465' . $RandomID,
    CustomerUser => 'customerOne@example.com',
    Service      => 'TestService' . $RandomID,
    OwnerID      => 1,
    UserID       => 1,
);

# sanity check
$Self->True(
    $TicketID1,
    "TicketCreate() successful for Ticket One ID $TicketID1",
);

my $TicketNumber1 = $TicketObject->TicketNumberLookup(
    TicketID => $TicketID1,
);

# sanity check
$Self->True(
    $TicketNumber1,
    "TicketNumberLookup() successful for Ticket One ID $TicketID1",
);

# update escalation times directly in the DB
my $EscalationTime = $TimeObject->SystemTime() + 120;
return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
    SQL => '
        UPDATE ticket
        SET escalation_time = ?, escalation_response_time = ?, escalation_update_time = ?,
            escalation_solution_time = ?, change_time = current_timestamp, change_by = ?
        WHERE id = ?',
    Bind => [
        \$EscalationTime,
        \$EscalationTime,
        \$EscalationTime,
        \$EscalationTime,
        \'1',
        \$TicketID1,
    ],
);

# create backend object and delegates
my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
$Self->Is(
    ref $BackendObject,
    'Kernel::System::DynamicField::Backend',
    'Backend object was created successfully',
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field1Config,
    ObjectID           => $TicketID1,
    Value              => 'ticket1_field1',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field2Config,
    ObjectID           => $TicketID1,
    Value              => 'ticket1_field2',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field3Config,
    ObjectID           => $TicketID1,
    Value              => '2001-01-01 01:01:01',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field4Config,
    ObjectID           => $TicketID1,
    Value              => '0',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field5Config,
    ObjectID           => $TicketID1,
    Value              => [ 'ticket1_field51', 'ticket1_field52', 'ticket1_field53' ],
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field6Config,
    ObjectID           => $TicketID1,
    Value              => '2001-01-01 00:00:00',
    UserID             => 1,
);

# get the Ticket entry
# without dynamic fields
my %TicketEntryOne = $TicketObject->TicketGet(
    TicketID      => $TicketID1,
    DynamicFields => 0,
    UserID        => $UserID,
);

$Self->True(
    IsHashRefWithData( \%TicketEntryOne ),
    "TicketGet() successful for Local TicketGet One ID $TicketID1",
);

for my $Key ( sort keys %TicketEntryOne ) {
    if ( !$TicketEntryOne{$Key} ) {
        $TicketEntryOne{$Key} = '';
    }
    if ( $Key eq 'Age' ) {
        delete $TicketEntryOne{$Key};
    }
}

# get the Ticket entry
# with dynamic fields
my %TicketEntryOneDF = $TicketObject->TicketGet(
    TicketID      => $TicketID1,
    DynamicFields => 1,
    UserID        => $UserID,
);

$Self->True(
    IsHashRefWithData( \%TicketEntryOneDF ),
    "TicketGet() successful with DF for Local TicketGet One ID $TicketID1",
);

for my $Key ( sort keys %TicketEntryOneDF ) {
    if ( !$TicketEntryOneDF{$Key} ) {
        $TicketEntryOneDF{$Key} = '';
    }
    if ( $Key eq 'Age' ) {
        delete $TicketEntryOneDF{$Key};
    }
}

# add ticket id
push @TicketIDs, $TicketID1;

# create ticket 2
my $TicketID2 = $TicketObject->TicketCreate(
    Title        => 'Ticket Two Title ' . $RandomID,
    Queue        => 'Raw',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'new',
    CustomerID   => '123465' . $RandomID,
    CustomerUser => 'customerTwo' . $RandomID . '@example.com',
    OwnerID      => 1,
    UserID       => 1,
);

# sanity check
$Self->True(
    $TicketID2,
    "TicketCreate() successful for Ticket Two ID $TicketID2",
);

my $TicketNumber2 = $TicketObject->TicketNumberLookup(
    TicketID => $TicketID2,
);

# sanity check
$Self->True(
    $TicketNumber2,
    "TicketNumberLookup() successful for Ticket One ID $TicketID2",
);

# set dynamic field values
$BackendObject->ValueSet(
    DynamicFieldConfig => $Field1Config,
    ObjectID           => $TicketID2,
    Value              => 'ticket2_field1',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field2Config,
    ObjectID           => $TicketID2,
    Value              => 'ticket2_field2',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field3Config,
    ObjectID           => $TicketID2,
    Value              => '2011-11-11 11:11:11',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field4Config,
    ObjectID           => $TicketID2,
    Value              => '1',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field5Config,
    ObjectID           => $TicketID2,
    Value              => [
        'ticket1_field5',
        'ticket2_field5',
        'ticket4_field5',
    ],
    UserID => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Field6Config,
    ObjectID           => $TicketID2,
    Value              => '2011-11-11',
    UserID             => 1,
);

# get the Ticket entry
# without DF
my %TicketEntryTwo = $TicketObject->TicketGet(
    TicketID      => $TicketID2,
    DynamicFields => 0,
    UserID        => $UserID,
);

$Self->True(
    IsHashRefWithData( \%TicketEntryTwo ),
    "TicketGet() successful for Local TicketGet Two ID $TicketID2",
);

for my $Key ( sort keys %TicketEntryTwo ) {
    if ( !$TicketEntryTwo{$Key} ) {
        $TicketEntryTwo{$Key} = '';
    }
    if ( $Key eq 'Age' ) {
        delete $TicketEntryTwo{$Key};
    }
}

# get the Ticket entry
# with DF
my %TicketEntryTwoDF = $TicketObject->TicketGet(
    TicketID      => $TicketID2,
    DynamicFields => 1,
    UserID        => $UserID,
);

$Self->True(
    IsHashRefWithData( \%TicketEntryTwoDF ),
    "TicketGet() successful for Local TicketGet Two ID $TicketID2",
);

for my $Key ( sort keys %TicketEntryTwoDF ) {
    if ( !$TicketEntryTwoDF{$Key} ) {
        $TicketEntryTwoDF{$Key} = '';
    }
    if ( $Key eq 'Age' ) {
        delete $TicketEntryTwoDF{$Key};
    }
}

# add ticket id
push @TicketIDs, $TicketID2;

# create ticket 3
my $TicketID3 = $TicketObject->TicketCreate(
    Title        => 'Ticket Three Title',
    Queue        => 'Raw',
    Lock         => 'unlock',
    Priority     => '1 very low',
    State        => 'new',
    CustomerID   => '123465' . $RandomID,
    CustomerUser => 'customerThree@example.com',
    Type         => 'TestType' . $RandomID,
    OwnerID      => 1,
    UserID       => 1,
);

# sanity check
$Self->True(
    $TicketID3,
    "TicketCreate() successful for Ticket Three ID $TicketID3",
);

# get the Ticket entry
my %TicketEntryThree = $TicketObject->TicketGet(
    TicketID      => $TicketID3,
    DynamicFields => 0,
    UserID        => $UserID,
);

$Self->True(
    IsHashRefWithData( \%TicketEntryThree ),
    "TicketGet() successful for Local TicketGet Three ID $TicketID3",
);

for my $Key ( sort keys %TicketEntryThree ) {
    if ( !$TicketEntryThree{$Key} ) {
        $TicketEntryThree{$Key} = '';
    }
    if ( $Key eq 'Age' ) {
        delete $TicketEntryThree{$Key};
    }
}

# add ticket id
push @TicketIDs, $TicketID3;

# create ticket 4
my $TicketID4 = $TicketObject->TicketCreate(
    Title        => 'Ticket Four Title äöüßÄÖÜ€ис',
    Queue        => 'Junk',
    Lock         => 'lock',
    Priority     => '3 normal',
    State        => 'new',
    CustomerID   => '654321' . $RandomID,
    CustomerUser => 'customerFour@example.com',
    OwnerID      => 1,
    UserID       => 1,
);

# sanity check
$Self->True(
    $TicketID4,
    "TicketCreate() successful for Ticket Four ID $TicketID4",
);

# first article
my $ArticleID41 = $TicketObject->ArticleCreate(
    TicketID       => $TicketID4,
    ArticleType    => 'phone',
    SenderType     => 'agent',
    From           => 'Agent Some Agent Some Agent <email@example.com>',
    To             => 'Customer A <customer-a@example.com>',
    Cc             => 'Customer B <customer-b@example.com>',
    ReplyTo        => 'Customer B <customer-b@example.com>',
    Subject        => 'first article',
    Body           => 'A text for the body, Title äöüßÄÖÜ€ис',
    ContentType    => 'text/plain; charset=ISO-8859-15',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'first article',
    UserID         => 1,
    NoAgentNotify  => 1,
);

# second article
my $ArticleID42 = $TicketObject->ArticleCreate(
    TicketID    => $TicketID4,
    ArticleType => 'phone',
    SenderType  => 'agent',
    From        => 'Anot Real Agent <email@example.com>',
    To          => 'Customer A <customer-a@example.com>',
    Cc          => 'Customer B <customer-b@example.com>',
    ReplyTo     => 'Customer B <customer-b@example.com>',
    Subject     => 'second article',
    Body        => 'A text for the body, not too long',
    ContentType => 'text/plain; charset=ISO-8859-15',

    #    Attachment     => \@Attachments,
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'second article',
    UserID         => 1,
    NoAgentNotify  => 1,
);

# save articles without attachments
my @ArticleWithoutAttachments = $TicketObject->ArticleGet(
    TicketID => $TicketID4,
    UserID   => 1,
);

for my $Article (@ArticleWithoutAttachments) {

    for my $Key ( sort keys %{$Article} ) {
        if ( !$Article->{$Key} ) {
            $Article->{$Key} = '';
        }
        if ( $Key eq 'Age' || $Key eq 'AgeTimeUnix' ) {
            delete $Article->{$Key};
        }
    }
}

# file checks
for my $File (qw(xls txt doc png pdf)) {
    my $Location = $ConfigObject->Get('Home')
        . "/scripts/test/sample/StdAttachment/StdAttachment-Test1.$File";

    my $ContentRef = $MainObject->FileRead(
        Location => $Location,
        Mode     => 'binmode',
        Type     => 'Local',
    );

    my $ArticleWriteAttachment = $TicketObject->ArticleWriteAttachment(
        Content     => ${$ContentRef},
        Filename    => "StdAttachment-Test1.$File",
        ContentType => $File,
        ArticleID   => $ArticleID42,
        UserID      => 1,
    );
}

# get articles and attachments
my @ArticleBox = $TicketObject->ArticleGet(
    TicketID => $TicketID4,
    UserID   => 1,
);

# start article loop
ARTICLE:
for my $Article (@ArticleBox) {

    for my $Key ( sort keys %{$Article} ) {
        if ( !$Article->{$Key} ) {
            $Article->{$Key} = '';
        }
        if ( $Key eq 'Age' || $Key eq 'AgeTimeUnix' ) {
            delete $Article->{$Key};
        }
    }

    # get attachment index (without attachments)
    my %AtmIndex = $TicketObject->ArticleAttachmentIndex(
        ContentPath                => $Article->{ContentPath},
        ArticleID                  => $Article->{ArticleID},
        StripPlainBodyAsAttachment => 3,
        Article                    => $Article,
        UserID                     => 1,
    );

    next ARTICLE if !IsHashRefWithData( \%AtmIndex );

    my @Attachments;
    ATTACHMENT:
    for my $FileID ( sort keys %AtmIndex ) {
        next ATTACHMENT if !$FileID;
        my %Attachment = $TicketObject->ArticleAttachment(
            ArticleID => $Article->{ArticleID},
            FileID    => $FileID,
            UserID    => 1,
        );

        next ATTACHMENT if !IsHashRefWithData( \%Attachment );

        # convert content to base64
        $Attachment{Content}            = encode_base64( $Attachment{Content} );
        $Attachment{ContentID}          = '';
        $Attachment{ContentAlternative} = '';
        push @Attachments, {%Attachment};
    }

    # set Attachments data
    $Article->{Atms} = \@Attachments;

}    # finish article loop

# get the Ticket entry
my %TicketEntryFour = $TicketObject->TicketGet(
    TicketID      => $TicketID4,
    DynamicFields => 0,
    UserID        => $UserID,
);

$Self->True(
    IsHashRefWithData( \%TicketEntryFour ),
    "TicketGet() successful for Local TicketGet Four ID $TicketID4",
);

for my $Key ( sort keys %TicketEntryFour ) {
    if ( !$TicketEntryFour{$Key} ) {
        $TicketEntryFour{$Key} = '';
    }
    if ( $Key eq 'Age' ) {
        delete $TicketEntryFour{$Key};
    }
}

# add ticket id
push @TicketIDs, $TicketID4;

# set webservice name
my $WebserviceName = '-Test-' . $RandomID;

# create webservice object
my $WebserviceObject = $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice');
$Self->Is(
    'Kernel::System::GenericInterface::Webservice',
    ref $WebserviceObject,
    "Create webservice object",
);

my $WebserviceID = $WebserviceObject->WebserviceAdd(
    Name   => $WebserviceName,
    Config => {
        Debugger => {
            DebugThreshold => 'debug',
        },
        Provider => {
            Transport => {
                Type => '',
            },
        },
    },
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $WebserviceID,
    "Added Webservice",
);

# get remote host with some precautions for certain unit test systems
my $Host;
my $FQDN = $ConfigObject->Get('FQDN');

# try to resolve FAQN host
if ( $FQDN ne 'yourhost.example.com' && gethostbyname($FQDN) ) {
    $Host = $FQDN;
}

# try to resolve localhost instead
if ( !$Host && gethostbyname('localhost') ) {
    $Host = 'localhost';
}

# use hard coded localhost IP address
if ( !$Host ) {
    $Host = '127.0.0.1';
}

# prepare webservice config
my $RemoteSystem =
    $ConfigObject->Get('HttpType')
    . '://'
    . $Host
    . '/'
    . $ConfigObject->Get('ScriptAlias')
    . '/nph-genericinterface.pl/WebserviceID/'
    . $WebserviceID;

my $WebserviceConfig = {

    #    Name => '',
    Description =>
        'Test for Ticket Connector using SOAP transport backend.',
    Debugger => {
        DebugThreshold => 'debug',
        TestMode       => 1,
    },
    Provider => {
        Transport => {
            Type   => 'HTTP::SOAP',
            Config => {
                MaxLength => 10000000,
                NameSpace => 'http://otrs.org/SoapTestInterface/',
                Endpoint  => $RemoteSystem,
            },
        },
        Operation => {
            TicketSearch => {
                Type => 'Ticket::TicketSearch',
            },
            SessionCreate => {
                Type => 'Session::SessionCreate',
            },
        },
    },
    Requester => {
        Transport => {
            Type   => 'HTTP::SOAP',
            Config => {
                NameSpace => 'http://otrs.org/SoapTestInterface/',
                Encoding  => 'UTF-8',
                Endpoint  => $RemoteSystem,
            },
        },
        Invoker => {
            TicketSearch => {
                Type => 'Test::TestSimple',
            },
            SessionCreate => {
                Type => 'Test::TestSimple',
            },
        },
    },
};

# update webservice with real config
my $WebserviceUpdate = $WebserviceObject->WebserviceUpdate(
    ID      => $WebserviceID,
    Name    => $WebserviceName,
    Config  => $WebserviceConfig,
    ValidID => 1,
    UserID  => $UserID,
);
$Self->True(
    $WebserviceUpdate,
    "Updated Webservice $WebserviceID - $WebserviceName",
);

# Get SessionID
# create requester object
my $RequesterSessionObject = $Kernel::OM->Get('Kernel::GenericInterface::Requester');
$Self->Is(
    'Kernel::GenericInterface::Requester',
    ref $RequesterSessionObject,
    "SessionID - Create requester object",
);

# create a new user for current test
my $UserLogin = $HelperObject->TestUserCreate(
    Groups => [ 'admin', 'users' ],
);
my $Password = $UserLogin;

# start requester with our webservice
my $RequesterSessionResult = $RequesterSessionObject->Run(
    WebserviceID => $WebserviceID,
    Invoker      => 'SessionCreate',
    Data         => {
        UserLogin => $UserLogin,
        Password  => $Password,
    },
);

my $NewSessionID = $RequesterSessionResult->{Data}->{SessionID};

my $TestCounter = 1;

my @Tests = (
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            TicketNumber => $TicketNumber1,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID1],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID1,
            },
            Success => 1
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            TicketNumber => [
                $TicketNumber1,
                $TicketNumber2,
            ],
            SortBy  => 'Ticket',    # force order, because the Age (default) can be the same
            OrderBy => 'Down',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [ $TicketID2, $TicketID1 ],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => [ $TicketID2, $TicketID1 ],
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Title => 'Ticket Two Title ' . $RandomID,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID2],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID2,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Title => [
                'Ticket One Title ' . $RandomID,
                'Ticket Two Title ' . $RandomID,
            ],
            SortBy  => 'Ticket',    # force order, because the Age (default) can be the same
            OrderBy => 'Down',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [ $TicketID2, $TicketID1 ],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => [ $TicketID2, $TicketID1 ],
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Title  => 'Ticket Two Title ' . $RandomID,
            Queues => 'Raw'
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID2],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID2,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Title  => 'Ticket Two Title ' . $RandomID,
            Queues => 'Raw',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID2],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID2,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Title => 'Ticket Two Title ' . $RandomID,
            Locks => 'unlock',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID2],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID2,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Title  => 'Ticket Two Title ' . $RandomID,
            States => 'new',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID2],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID2,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Title      => 'Ticket Two Title ' . $RandomID,
            Priorities => '3 normal',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID2],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID2,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            CustomerID => '123465' . $RandomID,
            SortBy     => 'Ticket',               # force order, because the Age (default) can be the same
            OrderBy    => 'Down',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [ $TicketID3, $TicketID2, $TicketID1 ],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => [ $TicketID3, $TicketID2, $TicketID1 ],
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Queues     => ['Junk'],
            CustomerID => '654321' . $RandomID,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID4],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID4,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Types => [ 'TestType' . $RandomID ],
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID3],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID3,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            States => ['new'],
            Title  => 'Ticket Two Title ' . $RandomID,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID2],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID2,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            States  => ['new'],
            Title   => '*' . $RandomID,
            SortBy  => 'Ticket',          # force order, because the Age (default) can be the same
            OrderBy => 'Down',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [ $TicketID2, $TicketID1 ],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => [ $TicketID2, $TicketID1 ],
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Title      => '* äöüßÄÖÜ€ис',
            CustomerID => '654321' . $RandomID,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID4],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID4,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Priorities => ['1 very low'],
            CustomerID => '123465' . $RandomID,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID3],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID3,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test DF " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            "DynamicField_DFT1$RandomID" => {
                Equals => 'ticket2_field1',
            },
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID2],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID2,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test DF " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            "DynamicField_DFT1$RandomID" => {
                Like => '*_field1',
            },
            SortBy => 'TicketNumber',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [ $TicketID2, $TicketID1 ],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => [ $TicketID2, $TicketID1 ],
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test DF Date " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            "DynamicField_DFT6$RandomID" => {
                GreaterThanEquals => '2010-01-01',
            },
            SortBy => 'TicketNumber',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID2],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID2,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test DF " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            TicketLastChangeTimeNewerDate =>
                $TimeObject->SystemTime2TimeStamp( SystemTime => $StartTime ),
            TicketCreateTimeNewerDate =>
                $TimeObject->SystemTime2TimeStamp( SystemTime => $StartTime ),
            SortBy  => 'Ticket',    # force order, because the Age (default) can be the same
            OrderBy => 'Down',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [ $TicketID4, $TicketID3, $TicketID2, $TicketID1 ],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => [ $TicketID4, $TicketID3, $TicketID2, $TicketID1 ],
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test DF " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            TicketCreateTimeNewerDate =>
                $TimeObject->SystemTime2TimeStamp( SystemTime => $TimeObject->SystemTime() + 1 ),
            SortBy  => 'Ticket',    # force order, because the Age (default) can be the same
            OrderBy => 'Down',
        },
        ExpectedReturnLocalData => {
            Data    => {},
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data    => undef,
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test Limit " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            TicketLastChangeTimeNewerDate =>
                $TimeObject->SystemTime2TimeStamp( SystemTime => $StartTime ),
            TicketCreateTimeNewerDate =>
                $TimeObject->SystemTime2TimeStamp( SystemTime => $StartTime ),
            SortBy  => 'Ticket',    # force order, because the Age (default) can be the same
            OrderBy => 'Down',
            Limit   => 1,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID4],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID4,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test EscalationTime " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            TicketEscalationTimeNewerMinutes => 120,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID1],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID1,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test EscalationResponseTime " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            TicketEscalationResponseTimeNewerMinutes => 120,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID1],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID1,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test EscalationUpdateTime " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            TicketEscalationUpdateTimeNewerMinutes => 120,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID1],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID1,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
    {
        Name           => "Test EscalationSolutionTime " . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            TicketEscalationSolutionTimeNewerMinutes => 120,
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID1],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID1,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },

    {
        Name           => "Test ContentSearch Parameter" . $TestCounter++,
        SuccessRequest => 1,
        RequestData    => {
            Body          => 'not too long',
            Subject       => 'not too long',
            ContentSearch => 'OR',
        },
        ExpectedReturnLocalData => {
            Data => {
                TicketID => [$TicketID4],
            },
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data => {
                TicketID => $TicketID4,
            },
            Success => 1,
        },
        Operation => 'TicketSearch',
    },
);

# Add a wrong value test for each possible parameter on direct search

for my $Item (
    qw(TicketNumber Title From To Cc Subject Body CustomerID CustomerUserLogin StateType
    Fulltext
    )
    )
{
    my $FailTest = {
        Name           => "Test $Item",
        SuccessRequest => 1,
        RequestData    => {
            $Item => 'NotAReal' . $Item,
        },
        ExpectedReturnLocalData => {
            Data    => {},
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data    => undef,
            Success => 1
        },
        Operation => 'TicketSearch',
    };

    # push test
    push @Tests, $FailTest;
}

# Arrays as strings
for my $Item (
    qw(StateIDs StateTypeIDs QueueIDs PriorityIDs OwnerIDs
    CreatedQueueIDs CreatedUserIDs WatchUserIDs ResponsibleIDs
    TypeIDs ServiceIDs SLAIDs LockIDs Queues Types States
    Priorities Services SLAs Locks CreatedTypes CreatedUserIDs
    CreatedTypes CreatedTypeIDs CreatedPriorities
    CreatedPriorityIDs CreatedStates CreatedStateIDs
    CreatedQueues CreatedQueueIDs
    )
    )
{
    my $FailTest = {
        Name           => "Test $Item",
        SuccessRequest => 1,
        RequestData    => {
            $Item => 'NotAReal' . $Item,
        },
        ExpectedReturnLocalData => {
            Data    => {},
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data    => undef,
            Success => 1
        },
        Operation => 'TicketSearch',
    };

    # push test
    push @Tests, $FailTest;
}

# Arrays
for my $Item (
    qw(StateIDs StateTypeIDs QueueIDs PriorityIDs OwnerIDs
    CreatedQueueIDs CreatedUserIDs WatchUserIDs ResponsibleIDs
    TypeIDs ServiceIDs SLAIDs LockIDs Queues Types States
    Priorities Services SLAs Locks CreatedTypes CreatedUserIDs
    CreatedTypes CreatedTypeIDs CreatedPriorities
    CreatedPriorityIDs CreatedStates CreatedStateIDs
    CreatedQueues CreatedQueueIDs
    )
    )
{
    my $FailTest = {
        Name           => "Test $Item",
        SuccessRequest => 1,
        RequestData    => {
            $Item => [
                'NotAReal' . $Item . 'One',
                'NotAReal' . $Item . 'Two',
                'NotAReal' . $Item . 'Three',
            ],
        },
        ExpectedReturnLocalData => {
            Data    => {},
            Success => 1
        },
        ExpectedReturnRemoteData => {
            Data    => undef,
            Success => 1
        },
        Operation => 'TicketSearch',
    };

    # push test
    push @Tests, $FailTest;
}

# debugger object
my $DebuggerObject = Kernel::GenericInterface::Debugger->new(
    DebuggerConfig => {
        DebugThreshold => 'debug',
        TestMode       => 1,
    },
    WebserviceID      => $WebserviceID,
    CommunicationType => 'Provider',
);
$Self->Is(
    ref $DebuggerObject,
    'Kernel::GenericInterface::Debugger',
    'DebuggerObject instantiate correctly',
);

for my $Test (@Tests) {

    # create local object
    my $LocalObject = "Kernel::GenericInterface::Operation::Ticket::$Test->{Operation}"->new(
        DebuggerObject => $DebuggerObject,
        WebserviceID   => $WebserviceID,
    );

    $Self->Is(
        "Kernel::GenericInterface::Operation::Ticket::$Test->{Operation}",
        ref $LocalObject,
        "$Test->{Name} - Create local object",
    );

    # start requester with our webservice
    my $LocalResult = $LocalObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => $Test->{Operation},
        Data         => {
            UserLogin => $UserLogin,
            Password  => $Password,
            %{ $Test->{RequestData} },
        },
    );

    # check result
    $Self->Is(
        'HASH',
        ref $LocalResult,
        "$Test->{Name} - Local result structure is valid",
    );

    # create requester object
    my $RequesterObject = $Kernel::OM->Get('Kernel::GenericInterface::Requester');
    $Self->Is(
        'Kernel::GenericInterface::Requester',
        ref $RequesterObject,
        "$Test->{Name} - Create requester object",
    );

    # start requester with our webservice
    my $RequesterResult = $RequesterObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => $Test->{Operation},
        Data         => {
            SessionID => $NewSessionID,
            %{ $Test->{RequestData} },
            }
    );

    # check result
    $Self->Is(
        'HASH',
        ref $RequesterResult,
        "$Test->{Name} - Requester result structure is valid",
    );

    $Self->Is(
        $RequesterResult->{Success},
        $Test->{SuccessRequest},
        "$Test->{Name} - Requester successful result",
    );

    # remove ErrorMessage parameter from direct call
    # result to be consistent with SOAP call result
    if ( $LocalResult->{ErrorMessage} ) {
        delete $LocalResult->{ErrorMessage};
    }

    $Self->IsDeeply(
        $RequesterResult,
        $Test->{ExpectedReturnRemoteData},
        "$Test->{Name} - Requester success status (needs configured and running webserver)",
    );

    if ( $Test->{ExpectedReturnLocalData} ) {
        $Self->IsDeeply(
            $LocalResult,
            $Test->{ExpectedReturnLocalData},
            "$Test->{Name} - Local result matched with expected local call result.",
        );
    }
    else {
        $Self->IsDeeply(
            $LocalResult,
            $Test->{ExpectedReturnRemoteData},
            "$Test->{Name} - Local result matched with remote result.",
        );
    }

}    #end loop

# clean up

# clean up webservice
my $WebserviceDelete = $WebserviceObject->WebserviceDelete(
    ID     => $WebserviceID,
    UserID => $UserID,
);
$Self->True(
    $WebserviceDelete,
    "Deleted Webservice $WebserviceID",
);

for my $TicketID (@TicketIDs) {

    # delete the ticket Three
    my $TicketDelete = $TicketObject->TicketDelete(
        TicketID => $TicketID,
        UserID   => $UserID,
    );

    # sanity check
    $Self->True(
        $TicketDelete,
        "TicketDelete() successful for Ticket ID $TicketID",
    );
}

for my $FieldID (@TestDynamicFields) {

    # delete the dynamic field
    my $DFDelete = $DynamicFieldObject->DynamicFieldDelete(
        ID      => $FieldID,
        UserID  => 1,
        Reorder => 0,
    );

    # sanity check
    $Self->True(
        $DFDelete,
        "DynamicFieldDelete() successful for Field ID $FieldID",
    );
}

my $UpdateUser = $UserObject->UserUpdate(
    UserID        => $UserID,
    UserFirstname => 'TestModified',
    UserLastname  => 'UserModified',
    UserLogin     => 'TestUser' . $RandomID,
    UserEmail     => 'testmodified' . $RandomID . 'email@example.com',
    ValidID       => 2,
    ChangeUserID  => $UserID,
);

# sanity check
$Self->True(
    $UpdateUser,
    "UserUpdate() successful for User ID $UserID",
);

my $Success = $TypeObject->TypeUpdate(
    %TypeData,
    ValidID => 2,
    UserID  => 1,
);

# sanity check
$Self->True(
    $Success,
    "TypeUpdate() set type $TypeData{Name} to invalid",
);

1;
