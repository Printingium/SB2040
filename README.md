# SB2040

## Steps to switching to can bus with umbilical:

- Print your strain relief

- Rip out your old cable x/y chains, they're ugly anyway.

- Remove your xy endstop (you can relocate them or go sensorless)

- Terminate your probe, e-motor, thermistor, and heater cartridge (and x end stop if you're using one)

- Solder your fans and LED's to the face plate board.

- If you are using the Omron probe, plug it in before screwing the board to the tool head. It's an impossible fit otherwise.
	(Note: you may want to use the LDO kit toolhead board prints as they set the board back a bit which can make this a little easier)

## Now onto the fun stuff:


```
Step 1:
Remote (ssh) into your pi and lets get it ready

Prep:
		sudo apt update
		sudo apt upgrade
		sudo apt install python3 python3-pip python3-can
		sudo pip3 install pyserial
		sudo su pi
		cd ~
		git clone https://github.com/Arksine/CanBoot


Create can network:
	sudo nano /etc/network/interfaces.d/can0
    	file contents:
        	allow-hotplug can0
        	iface can0 can static
            	bitrate 1000000
            	up ifconfig $IFACE txqueuelen 1024

Now it's time to flash your octopus 1.1 board (assuming you have the 446 model). During this phase, don't hook up your SB2040.

Octopus canboot flash:
    Canboot config:
        cd ~/CanBoot
        make menuconfig
        STM32
        F446
        Do not build
        12MHz crystal
        USB (PA11/12)
        32kib offset
        *support bootloader entry on rapid doubleclick
        escape, Y
		(if it's not mentioned, leave default settings)

    Compile and move:
        make
        mkdir ~/firmware
        mv ~/CanBoot/out/canboot.bin ~/firmware/octopus_1.1_canboot.bin
           
        
    Put octopus in DFU mode: jumper, power on, press button
    Check lsusb to ensure typical command will work: 
        lsusb
        dfu-util -l
            verify: Internal Flash => 0x08000000
            verify: usb device => 0483:df11
    Flash Canboot:
        Run this command, replacing with noted values if different:
            sudo dfu-util -a 0 -D ~/firmware/octopus_1.1_canboot.bin --dfuse-address 0x08000000:force:mass-erase:leave -d 0483:df11
        
        [normal errors, just dismiss these]
            Normal errors:
            dfu-util: Invalid DFU suffix signature
            dfu-util: A valid DFU suffix will be required in a future dfu-util release!!!
            dfu-util: Error during download get_status
        
    Now take octopus out of DFU mode:  
        power off, remove jumper, power back on

    Flash klipper:
        cd ~/klipper
        make clean
        make menuconfig
            options: 
                STM32
                F446
                32kib
                12MHz
                USB to CAN bridge (USB on PA11/12)
                Can bus on PD0/PD1
                1000000
                () gpio pins
        make
        mv ~/klipper/out/klipper.bin ~/firmware/octopus_1.1_klipper.bin
        copy the serial: ls -al /dev/serial/by-id/
        cd ~/CanBoot/scripts
        pip3 install pyserial
        python3 flash_can.py -f ~/firmware/octopus_1.1_klipper.bin -d /dev/serial/by-id/usb-CanBoot_stm32f446xx_170038000650314D35323820-if00
        
    Verify success and note UUID for octopus board:
        python3 flash_can.py -i can0 -q
The following errors means something went wrong flashing, reflash canboot in dfu and try again:
                    {ERRORS: ERROR:root:Can Flash Error
                    Traceback (most recent call last):
                        File "flash_can.py", line 491, in run_query
                           self.cansock.bind((intf,))
                    OSError: [Errno 19] No such device

                    During handling of the above exception, another exception occurred:

                    Traceback (most recent call last):
                        File "flash_can.py", line 619, in main
                            loop.run_until_complete(sock.run_query(intf))
                        File "/usr/lib/python3.7/asyncio/base_events.py", line 584, in run_until_complete
                            return future.result()
                        File "flash_can.py", line 493, in run_query
                            raise FlashCanError("Unable to bind socket to can0")
                    FlashCanError: Unable to bind socket to can0}


Hooray! Octopus is now flashed and ready, let's move on to the SB2040

Flash canboot to SB2040 -
    Set your sb2040 board to DFU mode. To do that, remove any power to the board, press the boot button while connecting the board to Pi via USB. The board should now be in DFU.
    Confirm its in DFU mode with lsusb (should see pi2040 on one of the ports, make note of ID [normally 2e8a:0003])

    Compile:
        cd ~/CanBoot
        make menuconfig
            options:
                RP2040
                CLKDIV 2
                Do not build
                CAN bus
                (4)
                (5)
                (1000000)
                (gpio24)
                *support bootloader entry....
                save and quit

        make -j 4
        sudo make flash FLASH_DEVICE=2e8a:0003

Hook up data lines (plug into octopus board and plug into sb2040) then power to SB2040 and get ready to flash klipper:
    Compile:
        cd ~/klipper
        make menuconfig
               options:
                RP2040
                16kib bootloader
                Can bus
                (4)
                (5)
                (1000000)
                (gpio24)
                save and quit

        make
        mv ~/klipper/out/klipper.bin ~/firmware/sb2040_1.0_klipper.bin

    Flash:
        cd ~/CanBoot/scripts
        python3 flash_can.py -i can0 -q         (copy serial id to a notepad for future use and use in command below)
        python3 flash_can.py -i can0 -u INSERT_SERIAL_UUID -f ~/firmware/sb2040_1.0_klipper.bin

HOORAY! NOW VERIFY INSTALLATION WITH THIS: python3 flash_can.py -i can0 -q
        You should see two UUID's Now you can copy them to your printer config as follows:
```

## PRINTER.CFG CHANGES

 [mcu]
 
canbus_uuid: Octopus ID from above 

[mcu sb2040]

canbus_uuid: SB2040 ID from above 

...

[temperature_fan exhaust_fan]
...
sensor_pin: sb2040:gpio26


[temperature_sensor toolhead]
sensor_type: temperature_mcu
sensor_mcu: sb2040
min_temp: 0
max_temp: 100       



# Pin changes:

### Extruder
Extruder temperature: sb2040:gpio27
Extruder heater: sb2040:gpio6

### Extruder Stepper motor
Stepping motor drive part
E motor
Function	pin number
EN		gpio7
STEP		gpio9
DIR		gpio10
UART		gpio8

### Fans
Fan0: sb2040:gpio13
    PWM: sb2040:gpio16
Fan1: sb2040:gpio14
    PWM: sb2040:gpio17
Fan2: sb2040:gpio15

### SBLEDS
SBLEDS: sb2040:gpio12

### Probe
Endstop TAP: sb2040:gpio29
Endstop Induction: sb2040:gpio28

### Accelerometer
If you use a separate file, put this there
[adxl345.cfg]
[adxl345]
cs_pin: sb2040:gpio1
spi_software_sclk_pin: sb2040:gpio0
spi_software_mosi_pin: sb2040:gpio3
spi_software_miso_pin: sb2040:gpio2


[resonance_tester]
accel_chip: adxl345
probe_points:
    100, 100, 20



#### Tip

If you get a timing too close error during ADXL calibration and your settings are 1,000,000 with a txquelen of 1024: change your x and y steppers from 32 microsteps to 16 for the ADXL test. You can switch back to 32 when it's done. Makes no difference since ADXL tuning is a physical measurement.


