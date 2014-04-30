#!/usr/bin/perl

use strict;
use warnings;

use Time::HiRes qw(sleep);
use HiPi::Device::GPIO;
use HiPi::Constant qw( :raspberry );

my $dev = HiPi::Device::GPIO->new();
my $pin = $dev->export_pin( RPI_PAD1_PIN_12 );
$pin->mode( RPI_PINMODE_INPT );

while(1) {
	unless($pin->value) {
		print "Pressed\n";
		sleep .2;
	}
}
