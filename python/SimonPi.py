#!/usr/bin/env python

from time import sleep
import RPi.GPIO as GPIO
import sys
from random import sample

# GLOBALS

# GPIO Channels
RED_IN   , RED_OUT    = 12, 7
YELLOW_IN, YELLOW_OUT = 16, 11
GREEN_IN , GREEN_OUT  = 18, 13
BLUE_IN  , BLUE_OUT   = 22, 15

# Convert a color GPIO input channel to it's appropriate GPIO output channel
IN_TO_OUT = {
	RED_IN   : RED_OUT,
	YELLOW_IN: YELLOW_OUT,
	GREEN_IN : GREEN_OUT,
	BLUE_IN  : BLUE_OUT,
}

# Color State
RED, YELLOW, GREEN, BLUE = RED_IN, YELLOW_IN, GREEN_IN, BLUE_IN

# Sleep Times
SLEEP_TIME_S, SLEEP_TIME_M, SLEEP_TIME_L, SLEEP_TIME_XL = .15, .25, .5, 1

# Button Input Bounce
BUTTON_INPUT_BOUNCE = 300

# Game State
STATE_SHOW_PATTERN, STATE_WAIT_FOR_INPUT, STATE_CHECKING_INPUT, STATE_ROUND_COMPLETE = 1, 2, 3, 4

# Game Round
ROUND = {
	'pattern'      : [],
	'pattern_left' : [],
	'state'        : STATE_SHOW_PATTERN,
}

# DEFINITIONS

# run - game loop
def run():
	init()

	print 'Welcome to SimonPi. Enter "quit" to stop playing. Enter "reset" to start over. Thanks for playing!\n'

	next_round(False)

	show_pattern()

    # the loop
	loop = True

	while loop:
		key_in = raw_input('--> ')

		if key_in == 'reset':
			# Reset the game
			next_round(False)

			show_pattern()

		if key_in == 'quit':
			# Cleanup your GPIO settings!
			print 'Quitting...\n'
			GPIO.cleanup()
			exit()

# init - initialize the GPIO channels we are using and setup button input listen events
def init():
	# GPIO
	GPIO.setwarnings(False) 
	GPIO.setmode(GPIO.BOARD) 

	# red
	GPIO.setup(RED_IN , GPIO.IN)
	GPIO.setup(RED_OUT, GPIO.OUT, initial=GPIO.HIGH)

	GPIO.add_event_detect(RED_IN, GPIO.BOTH, callback = button_event, bouncetime = BUTTON_INPUT_BOUNCE)

	# yellow
	GPIO.setup(YELLOW_IN , GPIO.IN)
	GPIO.setup(YELLOW_OUT, GPIO.OUT, initial=GPIO.HIGH)

	GPIO.add_event_detect(YELLOW_IN, GPIO.BOTH, callback = button_event, bouncetime = BUTTON_INPUT_BOUNCE)

	# green 
	GPIO.setup(GREEN_IN , GPIO.IN)
	GPIO.setup(GREEN_OUT, GPIO.OUT, initial=GPIO.HIGH)

	GPIO.add_event_detect(GREEN_IN, GPIO.BOTH, callback = button_event, bouncetime = BUTTON_INPUT_BOUNCE)

	# blue 
	GPIO.setup(BLUE_IN , GPIO.IN)
	GPIO.setup(BLUE_OUT, GPIO.OUT, initial=GPIO.HIGH)

	GPIO.add_event_detect(BLUE_IN, GPIO.BOTH, callback = button_event, bouncetime = BUTTON_INPUT_BOUNCE)

# button_event - respond to GPIO button input
def button_event(channel):
	global ROUND

	if ROUND['state'] != STATE_WAIT_FOR_INPUT:
		return

	ROUND['state'] = STATE_CHECKING_INPUT

	button_is_up = GPIO.input(channel)

	if button_is_up:

		GPIO.output(IN_TO_OUT[ channel ], GPIO.HIGH)

		ROUND['state'] = STATE_WAIT_FOR_INPUT
	else:
		light_up([ channel ], SLEEP_TIME_L)

		check_pattern(channel)

# next_round - start the next round of the game
def next_round(continue_game):
	global ROUND

	if continue_game:
		# Keep the pattern
		ROUND['pattern'].append(random_color())
	else:
		# Reset pattern
		ROUND['pattern'] = [random_color()]

	ROUND['pattern_left'] = ROUND['pattern'][0:]
	ROUND['state']        = STATE_SHOW_PATTERN

	turn_off_the_lights()

# random_color - return a random color
def random_color():
	return sample([RED,YELLOW,GREEN,BLUE], 1).pop()

# show_pattern - show the player the current pattern then wait for their input
def show_pattern():
	global ROUND

	for color in ROUND['pattern']:
		sleep(SLEEP_TIME_XL)

		light_up([color])

	ROUND['state'] = STATE_WAIT_FOR_INPUT 

# check_pattern - check selected color against current pattern and respond accordingly
def check_pattern(color):
	global ROUND

	if color == ROUND['pattern_left'][0]:
		# Color is correct, remove it
		ROUND['pattern_left'].pop(0)

		# If no more colors then Player wins this round
		if(len(ROUND['pattern_left']) == 0):
			ROUND['state'] = STATE_ROUND_COMPLETE

			win_round()

			next_round(True)

			show_pattern()
		else:
			ROUND['state'] = STATE_WAIT_FOR_INPUT
	else:
		# Color is not correct, Player loses and reset the game
		ROUND['state'] = STATE_ROUND_COMPLETE

		lose_round()

		next_round(False)

		show_pattern()

# light_up - turn on the leds listed in color_list
def light_up(color_list, seconds = None):
	if seconds is None:
		seconds = SLEEP_TIME_XL

	for color in color_list:
		GPIO.output(IN_TO_OUT[ color ], GPIO.LOW)

	sleep(seconds)

	for color in color_list:
		GPIO.output(IN_TO_OUT[ color ], GPIO.HIGH)

# turn_off_the_lights - turn off all active lights
def turn_off_the_lights():
	# Reset lights
	for color in [RED, YELLOW, GREEN, BLUE]:
		GPIO.output(IN_TO_OUT[ color ], GPIO.HIGH)

# win_round - show the player that they were correct for the current round
def win_round():
	turn_off_the_lights()

	sleep(SLEEP_TIME_S)
	light_up([RED]   , SLEEP_TIME_M)
	light_up([YELLOW], SLEEP_TIME_M)
	light_up([GREEN] , SLEEP_TIME_M)
	light_up([BLUE]  , SLEEP_TIME_M)
	sleep(SLEEP_TIME_S)

# lose_round - show the player that they were incorrect for the current round
def lose_round():
	turn_off_the_lights()
	
	light_up([RED,YELLOW,GREEN,BLUE], SLEEP_TIME_M)
	sleep(SLEEP_TIME_M)

	light_up([RED,YELLOW,GREEN,BLUE], SLEEP_TIME_M)
	sleep(SLEEP_TIME_M)

	light_up([RED,YELLOW,GREEN,BLUE], SLEEP_TIME_M)

# EXECUTION

run()
