#!/usr/bin/perl

use strict;
use warnings;

use Time::HiRes qw(sleep);
use HiPi::Device::GPIO;
use HiPi::Constant qw( :raspberry );

my $dev = HiPi::Device::GPIO->new();
my $pin = $dev->export_pin( RPI_PAD1_PIN_7 );
$pin->mode( RPI_PINMODE_OUTP );

$pin->value(0);
sleep 3;
$pin->value(1);
