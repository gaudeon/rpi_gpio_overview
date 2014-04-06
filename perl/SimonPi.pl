#!/usr/bin/env perl

use strict;
use warnings;

use Time::HiRes qw( sleep );
use Term::ReadKey;
use HiPi::Device::GPIO;
use HiPi::Interrupt; # 'use' this to avoid problems with HiPi::Interrupt::Handler...
use HiPi::Interrupt::Handler;
use HiPi::Constant qw( :raspberry );

# GLOBALS

# GPIO CHANNELS
use constant {
    RED_IN     => RPI_PAD1_PIN_12,
    RED_OUT    => RPI_PAD1_PIN_7,
    YELLOW_IN  => RPI_PAD1_PIN_16,
    YELLOW_OUT => RPI_PAD1_PIN_11,
    GREEN_IN   => RPI_PAD1_PIN_18,
    GREEN_OUT  => RPI_PAD1_PIN_13,
    BLUE_IN    => RPI_PAD1_PIN_22,
    BLUE_OUT   => RPI_PAD1_PIN_15
};

# Convert a color GPIO input channel to it's appropriate GPIO output channel
my %IN_TO_OUT = (
    RED_IN()    => RED_OUT,
    YELLOW_IN() => YELLOW_OUT,
    GREEN_IN()  => GREEN_OUT,
    BLUE_IN()   => BLUE_OUT
);

# Color State
use constant {
    RED    => RED_IN,
    YELLOW => YELLOW_IN,
    GREEN  => GREEN_IN,
    BLUE   => BLUE_IN
};

my @COLORS = (RED, YELLOW, GREEN, BLUE);

# Sleep Times
use constant {
    SLEEP_TIME_S  => .15,
    SLEEP_TIME_M  => .25,
    SLEEP_TIME_L  => .5,
    SLEEP_TIME_XL => 1
};

use constant BUTTON_INPUT_BOUNCE => 300;

# Game State
use constant {
    STATE_SHOW_PATTERN   => 1,
    STATE_WAIT_FOR_INPUT => 2,
    STATE_CHECKING_INPUT => 3,
    STATE_ROUND_COMPLETE => 4
};

# Game Round
my %ROUND = (
    pattern      => [],
    pattern_left => [],
    state        => STATE_SHOW_PATTERN,
);

# GPIO
my $GPIO;
my $GPIO_INT_HANDLER;

# GPIO PIN OBJECTS
my %PIN = (
    RED_IN()     => undef,
    RED_OUT()    => undef,
    YELLOW_IN()  => undef,
    YELLOW_OUT() => undef,
    GREEN_IN()   => undef,
    GREEN_OUT()  => undef,
    BLUE_IN()    => undef,
    BLUE_OUT()   => undef
);

# Keyboard Input
my $KEY_BUFFER;

# EXECUTION
run();

# SUBROUTINES

# run - game loop
sub run {
    init();

    print "Welcome to SimonPi. Enter \"quit\" to stop playing. Enter \"reset\" to start over. Thanks for playing!\n";
    print "--> ";

    next_round(continue_game => 0);

    show_pattern();

    # the loop, HiPi handles it so we are using loop_event to handle our command parsing
    $GPIO_INT_HANDLER->poll;
}

sub loop_event {
    my $command;

    if(my $key = ReadKey(-1)) {
        $KEY_BUFFER .= $key unless $key eq "\n";

        if($key eq "\n") {
           $command = $KEY_BUFFER;
           $KEY_BUFFER = '';
        }
    }

    if($command) {
        if($command eq 'reset') {
            # Reset the game
            next_round(continue_game => 0);

            show_pattern();
        }

        if($command eq 'quit') {
            # Cleanup your GPIO settings!
            print "Quitting...\n";

            ReadMode(0);

            # Remove pins from interrupt handler
            $GPIO_INT_HANDLER->remove_pin($PIN{RED_IN()});
            $GPIO_INT_HANDLER->remove_pin($PIN{YELLOW_IN()});
            $GPIO_INT_HANDLER->remove_pin($PIN{GREEN_IN()});
            $GPIO_INT_HANDLER->remove_pin($PIN{BLUE_IN()});

            # Stop interrupt handler
            $GPIO_INT_HANDLER->stop;

            # Unexport pins
            for my $pin (keys %PIN) {
                $GPIO->unexport_pin($pin);
            }
            exit;
        }

        print '--> ';
    }
}

# init - initialize the GPIO channels we are using and setup button listen events
sub init {
    # Init the interrupt handler first to reduce your memory footprint and avoid threading issues
    $GPIO_INT_HANDLER = HiPi::Interrupt::Handler->new;

    $GPIO_INT_HANDLER->set_valuetimeout(BUTTON_INPUT_BOUNCE);

    # register button_event as a callback for interrupt events
    $GPIO_INT_HANDLER->register_callback('interrupt', \&button_event);

    # continue is a hook we can use to do our own processing during the HiPi interrupt loop
    $GPIO_INT_HANDLER->register_callback('continue', \&loop_event);

    # GPIO
    $GPIO = HiPi::Device::GPIO->new;

    # Export the pins, so we can access them
    for my $pin (keys %PIN) {
        $PIN{ $pin } = $GPIO->export_pin($pin);
    }

    # red
    $PIN{RED_IN()}->mode( RPI_PINMODE_INPT );
    $PIN{RED_IN()}->interrupt( RPI_INT_BOTH );
    $GPIO_INT_HANDLER->add_pin($PIN{RED_IN()});

    $PIN{RED_OUT()}->mode( RPI_PINMODE_OUTP );
    $PIN{RED_OUT()}->value( RPI_HIGH );

    # yellow
    $PIN{YELLOW_IN()}->mode( RPI_PINMODE_INPT );
    $PIN{YELLOW_IN()}->interrupt( RPI_INT_BOTH );
    $GPIO_INT_HANDLER->add_pin($PIN{YELLOW_IN()});

    $PIN{YELLOW_OUT()}->mode( RPI_PINMODE_OUTP );
    $PIN{YELLOW_OUT()}->value( RPI_HIGH );

    # green 
    $PIN{GREEN_IN()}->mode( RPI_PINMODE_INPT );
    $PIN{GREEN_IN()}->interrupt( RPI_INT_BOTH );
    $GPIO_INT_HANDLER->add_pin($PIN{GREEN_IN()});

    $PIN{GREEN_OUT()}->mode( RPI_PINMODE_OUTP );
    $PIN{GREEN_OUT()}->value( RPI_HIGH );

    # blue 
    $PIN{BLUE_IN()}->mode( RPI_PINMODE_INPT );
    $PIN{BLUE_IN()}->interrupt( RPI_INT_BOTH );
    $GPIO_INT_HANDLER->add_pin($PIN{BLUE_IN()});

    $PIN{BLUE_OUT()}->mode( RPI_PINMODE_OUTP );
    $PIN{BLUE_OUT()}->value( RPI_HIGH );

    ReadMode(1);
}

# button_event - respond to GPIO button input
sub button_event {
    my ($self, $msg) = @_;

    return unless $ROUND{'state'} == STATE_WAIT_FOR_INPUT;

    $ROUND{'state'} = STATE_CHECKING_INPUT;

    my $button_is_up = $msg->value;
    my $pin          = $msg->pinid;

    if($button_is_up) {
        $PIN{ $IN_TO_OUT{ $pin } }->value( RPI_HIGH );

        $ROUND{'state'} = STATE_WAIT_FOR_INPUT;
    }
    else {
        light_up(color_list => [ $pin ], seconds => SLEEP_TIME_L);

        check_pattern( color => $pin );
    }
}

# next_round - start the next round of the game
sub next_round {
    my %args = @_;

    if($args{'continue_game'}) {
        push(@{$ROUND{'pattern'}}, random_color());
    }
    else {
        $ROUND{'pattern'} = [ random_color() ];
    }

    $ROUND{'pattern_left'} = [ @{$ROUND{'pattern'}} ];
    $ROUND{'state'}        = STATE_SHOW_PATTERN;

    turn_off_the_lights();
}

# random_color - return a random color
sub random_color {
    return $COLORS[ int(rand(scalar @COLORS)) ];
}

# show_pattern - show the player the current pattern then wait for their input
sub show_pattern {
    for my $color (@{ $ROUND{'pattern'} }) {
        sleep(SLEEP_TIME_XL);

        light_up(color_list => [$color]);
    }

    $ROUND{'state'} = STATE_WAIT_FOR_INPUT;
}

# check_pattern - check selected color against current pattern and respond accordingly
sub check_pattern {
    my %args = @_;

    die 'No color specified' unless $args{'color'};

    if($args{'color'} == shift @{ $ROUND{'pattern_left'} }) {
        # Color is correct and was already removed
        
        # If no more colors then Player wins this round
        if(! scalar @{ $ROUND{'pattern_left'} }) {
            $ROUND{'state'} = STATE_ROUND_COMPLETE;

            win_round();

            next_round(continue_game => 1);

            show_pattern();
        }
        else {
            $ROUND{'state'} = STATE_WAIT_FOR_INPUT;
        }
    }
    else {
        # Color is not correct, Player loses and reset the game
        $ROUND{'state'} = STATE_ROUND_COMPLETE;

        lose_round();

        next_round(continue_game => 0);

        show_pattern();
    }
}

# light_up - turn on the leds listed in color_list
sub light_up {
    my %args = @_;

    $args{'seconds'} ||= SLEEP_TIME_XL;

    die 'No color_list specified' unless ref($args{'color_list'}) eq 'ARRAY';

    for my $color (@{ $args{'color_list'} }) {
        $PIN{ $IN_TO_OUT{ $color } }->value( RPI_LOW );
    }

    sleep( $args{'seconds'} );

    for my $color (@{ $args{'color_list'} }) {
        $PIN{ $IN_TO_OUT{ $color } }->value( RPI_HIGH );
    }
}

# turn_off_the_lights - turn off all active lights
sub turn_off_the_lights {
    $PIN{ $IN_TO_OUT{ $_ } }->value( RPI_HIGH ) for @COLORS;
}

# win_round - show the player that they were correct for the current round
sub win_round {
    turn_off_the_lights();

    sleep(SLEEP_TIME_S);
    light_up(color_list => [ RED ]   , seconds => SLEEP_TIME_M);
    light_up(color_list => [ YELLOW ], seconds => SLEEP_TIME_M);
    light_up(color_list => [ GREEN ] , seconds => SLEEP_TIME_M);
    light_up(color_list => [ BLUE ]  , seconds => SLEEP_TIME_M);
    sleep(SLEEP_TIME_S);
}

# lose_round - show the player that they were incorrect for the current round
sub lose_round {
    turn_off_the_lights();

    light_up(color_list => [ RED, YELLOW, GREEN, BLUE ], seconds => SLEEP_TIME_M);
    sleep(SLEEP_TIME_M);

    light_up(color_list => [ RED, YELLOW, GREEN, BLUE ], seconds => SLEEP_TIME_M);
    sleep(SLEEP_TIME_M);

    light_up(color_list => [ RED, YELLOW, GREEN, BLUE ], seconds => SLEEP_TIME_M);
}
