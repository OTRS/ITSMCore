#!/usr/bin/perl
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# $origin: otrs - 4b5de865d1ad6c6a22b5bb35755d5ace2eab7d7b - bin/otrs.AddService.pl
# --
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

use Getopt::Std;

use Kernel::System::ObjectManager;
# ---
# ITSMCore
# ---
use Kernel::System::VariableCheck qw(:all);
# ---

my %Param;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'OTRS-otrs.AddService',
    },
);

my $NoOptions = $ARGV[0] ? 0 : 1;

# get options
my %Opts;
# ---
# ITSMCore
# ---
#getopts( 'hn:p:c:', \%Opts );
getopts( 'hn:p:c:C:t:', \%Opts );
# ---

if ( $Opts{h} || $NoOptions ) {
# ---
# ITSMCore
# ---
#    print STDERR "Usage: $FindBin::Script -n <Name> -p <Parent> -c <Comment>\n";
    print STDERR "Usage: $FindBin::Script -n <Name> -p <Parent> -c <Comment> -C <Criticality> -t <Type>\n\n";
# ---
    exit;
}

if ( !$Opts{n} ) {
    print STDERR "ERROR: Need -n <Name>\n";
    exit 1;
}

my $ServiceName;

# lookup parent service if given
if ( $Opts{p} ) {
    $Param{ParentID} = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
        Name   => $Opts{p},
        UserID => 1,
    );
    if ( !$Param{ParentID} ) {
        print STDERR "ERROR: Can't add Service: Parent '$Opts{p}' does not exist!\n";
        exit 1;
    }
    $ServiceName = $Opts{p} . '::';
}

$ServiceName .= $Opts{n};

# check if service already exists
my %ServiceList = $Kernel::OM->Get('Kernel::System::Service')->ServiceList(
    Valid  => 0,
    UserID => 1,
);
my %Reverse = reverse %ServiceList;
if ( $Reverse{$ServiceName} ) {
    print STDERR "ERROR: Can't add Service: Service '$ServiceName' already exists!\n";
    exit 1;
}
# ---
# ITSMCore
# ---

# get the dynamic field config for ITSMCriticality
my $DynamicFieldConfigArrayRef = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
    Valid       => 1,
    ObjectType  => [ 'Ticket' ],
    FieldFilter => {
        ITSMCriticality => 1,
    },
);

# get the dynamic field values for ITSMCriticality
my %PossibleValues;
DYNAMICFIELD:
for my $DynamicFieldConfig ( @{ $DynamicFieldConfigArrayRef } ) {
    next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

    # get PossibleValues
    $PossibleValues{ $DynamicFieldConfig->{Name} } =  $DynamicFieldConfig->{Config}->{PossibleValues} || {};
}

my %Criticality = %{ $PossibleValues{ITSMCriticality} };

$Param{Criticality} = $Criticality{ $Opts{C} || '' };
if ( !defined $Param{Criticality} ) {
    if ( !$Opts{C} ) {
        print STDERR "Error: Can't add Service: No criticality given via -C option!\n";
    }
    elsif ( !defined $Param{Criticality} ) {
        print STDERR "Error: Can't add Service: Criticality '$Opts{C}' unknown!\n";
    }
    print "\nAvailable options are:\n\n";
    for my $Criticality ( sort keys %Criticality ) {
        print "\t'$Criticality'\n";
    }
    exit 1;
}

# get service type list
my $ServiceTypeList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
    Class => 'ITSM::Service::Type',
);

my %ServiceType = reverse %{$ServiceTypeList};
$Param{TypeID} = $ServiceType{ $Opts{t} || '' };
if ( !defined $Param{TypeID} ) {
    if ( !$Opts{t} ) {
        print STDERR "Error: Can't add Service: No service type given via -t option!\n";
    }
    elsif ( !defined $Param{TypeID} ) {
        print STDERR "Error: Can't add Service: Service type '$Opts{t}' unknown!\n";
    }
    print "\nAvailable options are:\n\n";
    for my $ServiceType ( sort keys %ServiceType ) {
        print "\t'$ServiceType'\n";
    }
    exit 1;
}

# ---

# user id of the person adding the record
$Param{UserID} = '1';

# Validrecord
$Param{ValidID} = '1';
$Param{Name}    = $Opts{n} || '';
$Param{Comment} = $Opts{c};

if ( my $ID = $Kernel::OM->Get('Kernel::System::Service')->ServiceAdd(%Param) ) {
    print "Service '$ServiceName' added. ID is '$ID'\n";
}
else {
    print STDERR "ERROR: Can't add Service\n";
    exit 1;
}

exit(0);
