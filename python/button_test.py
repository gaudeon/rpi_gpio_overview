#!/usr/bin/python
import time
import RPi.GPIO as GPIO
GPIO.setmode(GPIO.BOARD)
GPIO.setup(12, GPIO.IN)

while True:
	mybutton = GPIO.input(12)
	if mybutton == False:
		print "Pressed"
		time.sleep(.2)
