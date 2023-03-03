#!/bin/bash

# GNU GENERAL PUBLIC LICENSE
# Version 3
#
# Copyright (C) [2023] [Devin C.]
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# The GNU General Public License can be accessed here: http://www.gnu.org/licenses/


###########################  DEBUGGING SECTION  #########################################################################

#set -o xtrace
#exec &> >(tee -a "$logdir/$(date '+%Y-%m-%d_%H:%M:%S')_logfile.txt")
#set -e
#set -x

###########################  END DEBUGGING SECTION  #####################################################################



###########################  SOME VARIABLES WE NEED  ####################################################################

declare -i INITIAL_INSTALL=0
SCRIPT=$(readlink -f "$0")
ORIGINAL_SCRIPT=$(readlink -f "$0")
LOCATION_FILE=$(dirname "$SCRIPT")/.octocanflashlocation

###########################  END VARIABLES SECTION  #####################################################################



###########################  BEGIN FUNCTIONS SECTION  ###################################################################
# Function to remove all files created by the script

#self explanatory
function uninstall() {
    if [ -f "$USER_DIR/.octocanflashlocation" ]; then
        type_text "Removing $USER_DIR/.octocanflashlocation"
        rm "$USER_DIR/.octocanflashlocation"
    fi

    if [ -f "$USER_DIR/.uuids.txt" ]; then
        type_text "Removing $USER_DIR/.uuids.txt"
        rm "$USER_DIR/.uuids.txt"
    fi

    if [ -d "$USER_DIR/CanConfigs" ]; then
        type_text "Removing $USER_DIR/CanConfigs"
        rm -rf "$USER_DIR/CanConfigs"
    fi

    if [ -f "$SCRIPT" ]; then
        type_text "Removing $SCRIPT"
        rm "$SCRIPT"
    fi

    type_text "Uninstall complete."
    type_text "OctoCanFlash has been removed"
    exit 0
}

#handles reset of program files
function reset() {
    if [[ "$1" == "-config" ]]; then
        type_text "Removing config files..."
        USER_DIR=$(cat "$LOCATION_FILE")
        rm -f ~/klipper/config.*
        rm -f "$USER_DIR/CanConfigs/config.octopus.klipper"
        rm -f "$USER_DIR/CanConfigs/config.SB2040.klipper"
    elif [[ "$1" == "-uuid" ]]; then
        type_text "Removing .uuids.txt file..."
        USER_DIR=$(cat "$LOCATION_FILE")
        rm -f "$USER_DIR/.uuids.txt"
    elif [[ ! -z "$1" ]]; then
        type_text "Invalid flag provided. The following modifiers are supported:"
        type_text "-config  : Remove stored configs"
        type_text "-uuid    : Remove stored uuid's"
        type_text "no flags : Remove all stored configs and uuids"
        exit 1
    else
        type_text "Removing .uuids.txt and config files..."
        USER_DIR=$(cat "$LOCATION_FILE")
        rm -f ~/klipper/config.*
        rm -f "$USER_DIR/.uuids.txt"
        rm -f "$USER_DIR/CanConfigs/config.octopus.klipper"
        rm -f "$USER_DIR/CanConfigs/config.SB2040.klipper"
    fi
    type_text "OctoCanFlash has been reset. To flash, run the script normally."
    exit 0
}

#make it pretty to read
function type_text() {
  local text="$1"
  local delay="${2:-0.015}"
  local i=0
  local len="${#text}"
  while [ $i -lt $len ]; do
    local char="${text:$i:1}"
    if [ "$char" = "\\" ] && [ "${text:$i+1:1}" = "n" ]; then
      echo ""
      i=$(($i+2))
    else
      echo -n "$char"
      if [ "$char" = "." ]; then
        sleep 0.75
      else
        sleep $delay
      fi
      i=$(($i+1))
    fi
  done
  echo ""
}

#a number word countdown timer just because
function countdown() {
  local count=5
  while [ $count -ge 0 ]; do
    printf "\r%s..." "$(number_word $count)"
    read -t 1 -n 1 -s -r -p "Press any key to quit"
    if [ $? = 0 ]; then
      read -n 1 -r -p $'\nAre you sure you want to quit? (y/n) ' input
      if [[ $input =~ ^[Yy]$ ]]; then
        printf "\nExiting...\n"
        exit 0
      elif [[ $input =~ ^[Nn]$ ]]; then
        printf "\r                    \r" # clear the previous line
      fi
    fi
    count=$((count-1))
  done
  printf "\n%s\n" "Continuing"
}

function number_word() {
  case $1 in
    0) echo "zero...." ;;
    1) echo "one....." ;;
    2) echo "two....." ;;
    3) echo "three..." ;;
    4) echo "four...." ;;
    5) echo "five...." ;;
  esac
}

#get the serial id of our octopus board
function get_octopus_serial() {
  local octopus_devices=$(ls /dev/serial/by-id | grep "CanBoot")
  local num_devices=$(echo "${octopus_devices}" | wc -l)
  local octopus_serial=""

  if [[ "${num_devices}" -eq 1 && "${octopus_devices}" == *"CanBoot"* ]]; then
    octopus_serial=$(echo "${octopus_devices}" | awk '{print $NF}')
  else
    type_text "Please select the correct Octopus serial device:"
    type_text "${octopus_devices}" | awk '{print NR") "$NF}'
    read -p "> " selection

    octopus_serial=$(type_text "${octopus_devices}" | sed "${selection}q;d" | awk '{print $NF}')
  fi

  type_text "$octopus_serial"
}

#handles processing of the UUID's needed
function read_uuids() {
    UUID_USER_DIR=$1
    seconds=5
    while true; do
        if [ -s .uuids.txt ]
        then
            type_text "Your UUIDs have been previously entered:"
            read Octuuid SBuuid < $USER_DIR/.uuids.txt
            type_text "Octopus UUID = $Octuuid"
            type_text "SB2040 UUID = $SBuuid"
        else
            type_text "Looks like I don't have your UUID's yet, lets' grab those."
            type_text "Enter Octopus UUID:"
            read Octuuid
            type_text "Enter SB2040 UUID:"
            read SBuuid
            echo "# Octopus UUID" > $USER_DIR/.uuids.txt
            echo "Octuuid=$Octuuid" >> $USER_DIR/.uuids.txt
            echo "# SB2040 UUID" >> $USER_DIR/.uuids.txt
            echo "SBuuid=$SBuuid" >> $USER_DIR/.uuids.txt
            read -p "Doublecheck, Are these values correct? [y/n] " yn
            case $yn in
                [Yy]* ) type_text "$Octuuid $SBuuid" > $USER_DIR/.uuids.txt; break;;
                [Nn]* ) continue;;
                * ) type_text "Please answer yes or no.";;
            esac
        fi
        type_text "If your UUID's are WRONG, press any key to interrupt."
        printf "\rContinuing in %s seconds..." "$((seconds-i-1))"
        interrupted=0
        i=0
        while [ $i -lt $seconds ]; do
            read -t 1 -n 1 && interrupted=1 && break
            printf "\rContinuing in %s seconds..." "$((seconds-i-1))"
            i=$((i+1))
        done

        if [ $interrupted -eq 1 ]; then
            type_text "Let's try again."
            rm .uuids.txt
            continue
        else
            printf "\r%s\n" "Continuing in "
            break
        fi
    done
}

#handles the processing of config files
function handle_configs() {
    BOARD_NAME="$1"
    USER_DIR2="${2:-$USER_DIR}"
    CONFIG_DIR="$USER_DIR/CanConfigs"
    CONFIG_PATH="$CONFIG_DIR/config.$BOARD_NAME.klipper"
    KLIPPER_DIR="$HOME/klipper"
    SB_CONFIG_PATH="$KLIPPER_DIR/config.$BOARD_NAME"
    type_text "attempting to import $BOARD_NAME config"
        
    if [ -d "$CONFIG_DIR" ]; then
        type_text "Directory Exists! Checking for files."
        if [ -e "$CONFIG_PATH" ]; then
            type_text "$BOARD_NAME make config exists! Importing..."
            cp "$CONFIG_PATH" "$SB_CONFIG_PATH"
            cd "$KLIPPER_DIR" && make clean KCONFIG_CONFIG=config.$BOARD_NAME
        else
            type_text "No $BOARD_NAME config exists, hang on, we'll fix that"
            sleep 3s
            cd "$KLIPPER_DIR" && make clean KCONFIG_CONFIG=config.$BOARD_NAME
            type_text "Make a $BOARD_NAME Config, press ENTER"
            read dummy_variable
            cd "$KLIPPER_DIR" && make menuconfig KCONFIG_CONFIG=config.$BOARD_NAME
            cp "$SB_CONFIG_PATH" "$CONFIG_PATH"
            cp "$SB_CONFIG_PATH" "$SB_CONFIG_PATH.old"
        fi
    else
        type_text "***uh-oh, you don't have configs, I'll help you get that fixed***"
        sleep 1s 
        
        if [ ! -d "$CONFIG_DIR" ]; then
            type_text "Creating directory to store your config files in"
            mkdir "$CONFIG_DIR"
        fi
        
        type_text "No $BOARD_NAME config exists, hang on, we'll fix that"
        cd "$KLIPPER_DIR" && make clean KCONFIG_CONFIG=config.$BOARD_NAME
        type_text "Make a $BOARD_NAME Config, press ENTER"
        read dummy_variable
        cd "$KLIPPER_DIR" && make menuconfig KCONFIG_CONFIG=config.$BOARD_NAME
        cp "$KLIPPER_DIR/.config" "$CONFIG_PATH"
        cp "$SB_CONFIG_PATH" "$SB_CONFIG_PATH.old"
    fi
}

function troubleshooting_tips {
    type_text "Press the 'T' key to display our troublehsooting guide, otherwise continuing in $1"
    remaining=$1
    while [ $remaining -gt -1 ]; do
        read -t 1 -n 1 -s key
        if [[ $key = t ]]; then
            type_text "Displaying troubleshooting tips..."
            while true; do
                PS3="Which error do you need tips for? "
                select choice in "Error 19" "SB MCU" "Other"; do
                    case $REPLY in
                        1 ) type_text "[Errno 19] No such device:"
                            type_text "You have likely flashed the wrong klipper data to your octopus board."
                            type_text "You will need to manually put your octopus board into canboot"
                            type_text "by double-tapping the reset button, that's the one below the knob on the 12864 screen."
                            type_text "once done, run ls /dev/serial/by-id to ensure your octopus serial is there."
                            type_text "You'll use this in a moment"
                            type_text "You may now run this program again to flash, but first run it with a reset flag."
                            type_text "do this by running ./OCF.sh -reset"  
                            type_text "this will start the program fresh so you can fix your octopus firmware options" ; break;;
                        2 ) type_text "Klipper unable to connect to SB MCU"
                            type_text "this error is caused by either the wrong configuration being flashed,"
                            type_text "or a communication error during flashing."
                            type_text "Sometimes this can be fixed by hard rebooting your printer (power off for 30 seconds)."
                            type_text "If that doesn't work you will need to put your SB2040 board into DFU, and  reflash CanBoot."
                            type_text "To enter DFU, remove power from your SB2040, hold the reset button, and"
                            type_text "plug a USB-C cable into your SB2040, connected on the other end to your pi"
                            type_text "Verify you are able to see it with lsusb (should be device 2e8a:0003)"
                            type_text "Once you can see it, cd into your Canboot directory (typically ~/CanBoot)"
                            type_text "run the following commands:"
                            type_text "make clean"
                            type_text "make menuconfig"
                            type_text "your options should go like this: "
                            type_text "RP2040 \n CLKDIV 2 \n Do not build \n CAN bus \n (4) \n (5) \n (1000000) \n (gpio24) \n *support bootloader entry"
                            type_text "now run: \n make -j 4"
                            type_text "Once complete, run this command: \n 'sudo make flash FLASH_DEVICE=2e8a:0003" ; break;;
                        3 ) echo "We don't have any other tips for now. Please submit your error and we will add it."; break;;
                        * ) echo "Please enter a valid option.";;
                    esac
                done
                PS3="Please choose an option"
                select choice in "Continue" "View other tips" "Exit"; do
                    case $REPLY in
                        1 ) return;;
                        2 ) break;;
                        3 ) exit;;
                        * ) echo "Please enter a valid option.";;
                    esac
                done
            done
        else
            echo -n "$remaining "
            ((remaining--))   
        fi
    done
}

#############################  END FUNCTIONS SECTION  #################################################################



#############################  BEGIN SCRIPT  ##########################################################################

# Check for flags
if [ "$1" == "-reset" ]; then
  type_text "Resetting the application..."
  reset "$2"
elif [ "$1" == "-uninstall" ]; then
  type_text "Uninstalling the application..."
  uninstall
  exit 0
elif [ -z "$1" ]; then
  # No flag provided, continue with rest of code
  echo ""
else
  # Invalid flag provided
  type_text "Invalid option. -reset or -uninstall are the only valid options."
  exit 0
fi

clear

echo -e "\033[35m#############################################################\033[0m"
echo -e "\033[35m#\033[0m                                                           \033[35m#\033[0m"
echo -e "\033[35m#\033[0m   WARNING: Use this program at your own risk.             \033[35m#\033[0m"
echo -e "\033[35m#\033[0m            This program may damage your hardware.         \033[35m#\033[0m"
echo -e "\033[35m#\033[0m            The author is not responsible for any damage.  \033[35m#\033[0m"
echo -e "\033[35m#\033[0m            By continuing you accept liability for any     \033[35m#\033[0m"
echo -e "\033[35m#\033[0m            damage that may occur.                         \033[35m#\033[0m"
echo -e "\033[35m#\033[0m                                                           \033[35m#\033[0m"
echo -e "\033[35m#############################################################\033[0m"
read -p "Press Enter to continue or ctrl + c to exit..." dummy_variable



# Read the user directory path from the location file, if it exists
if [ -f "$LOCATION_FILE" ]; then
    USER_DIR=$(cat "$LOCATION_FILE")
    ((INITIAL_INSTALL++))
    if [ "$INITIAL_INSTALL" -eq 1 ] 
    then
        type_text "Welcome Back!"
    else
        type_text "Looks like we got disconnected, let's pick up where we left off"
    fi
else
    # Get the default directory path
    DEFAULT_DIR=~/OctoCanFlash

    # Ask the user to enter a custom directory path
    type_text  "Looks like this is your first time running OctoCanFlash. \npress ENTER to install at the default location \n--OR--\ntell me where you want to install OctoCanFlash \nDefault path: $DEFAULT_DIR (Leave Blank to use)"
    type_text "Enter Full Path, No Squigly Please:"
    read -p ""
    # Use the default directory if the user didn't enter a custom one
    if [ -z "$REPLY" ]; then
        USER_DIR=$DEFAULT_DIR
    else
        USER_DIR=$REPLY
    fi
    
    # Create the directory if it doesn't exist
    mkdir -p "$USER_DIR"

    # Move the script to the chosen or default directory
    if [ "$(dirname "$SCRIPT")" != "$USER_DIR" ]; then
        cp "$SCRIPT" "$USER_DIR"
        SCRIPT="$USER_DIR/$(basename "$SCRIPT")"
    fi

    # Log the user directory path to a location file
    type_text "$USER_DIR" > "$USER_DIR/.octocanflashlocation"

    type_text "Location file created: $USER_DIR.octocanflashlocation"
    type_text "Initial install: $INITIAL_INSTALL"
    cd "$(dirname "$(realpath "$0")")"
fi

# Create the CanConfigs directory if it doesn't exist
if [ ! -d $USER_DIR/CanConfigs ]; 
then
    mkdir $USER_DIR/CanConfigs
fi

# verify UUID's are available
read_uuids $USER_DIR

#Kill Klipper
type_text "Root privileges required to stop klipper"
sudo service klipper stop


###########################  BEGIN OCTOPUS FLASHING SECTION  ##########################################################

#create configs for octopus
handle_configs "octopus"
make clean KCONFIG_CONFIG=config.octopus
make KCONFIG_CONFIG=config.octopus

#Ensure compile completed before continuing
if [ ! -e ~/klipper/out/klipper.bin ]
then
    if [ $sbretry -lt 3 ]
    then
        type_text "compile failed, this usually means there's a problem with your config file, let's make it again."
        rm ~/klipper/config.octopus
        rm ~/OctoCanFlash/CanConfigs/config.octopus.klipper
        ((sbretry++))
        handle_configs "octopus"
    else
        type_text "too many retries, something is wrong"
    fi
fi

#flash octopus
type_text "rebooting octopus"
~/CanBoot/scripts/flash_can.py -u $Octuuid -r
type_text "Hang on, this thing is slow at rebooting....."
octopus_serial=$(get_octopus_serial)
type_text "$octopus_serial"
type_text "if the above serial looks wrong please interrupt"
countdown
make flash FLASH_DEVICE=/dev/serial/by-id/$octopus_serial
type_text "Octopus section complete! if you had error's please see the troubleshooting guide offered at the end of this script"
type_text "On to your SB2040 board!"
sleep 1

###########################  END OCTOPUS FLASHING SECTION  ############################################################



###########################  BEGIN SB2040 FLASHING SECTION  ###########################################################

#create configs for SB2040
type_text "attempting to copy from configs directory"
handle_configs "SB2040"
make clean KCONFIG_CONFIG=config.SB2040
make KCONFIG_CONFIG=config.SB2040
sbretry=0

#Ensure compile completed before continuing
if [ ! -e ~/klipper/out/klipper.bin ]
then
    if [ $sbretry -lt 3 ]
    then
        type_text "compile failed, this usually means there's a problem with your config file, let's make it again."
        rm ~/klipper/config.SB2040
        rm ~/OctoCanFlash/CanConfigs/config.SB2040.klipper
        ((sbretry++))
        handle_configs "SB2040"
    else
        type_text "too many retries, something is wrong"
    fi
fi

#flash SB2040
type_text "Ready to flash SB2040, press ENTER to continue or ctrl+c to exit"
read dummy_variable
python3 ~/CanBoot/scripts/flash_can.py -u $SBuuid
type_text "SB2040 section complete! If you had error's please see the troubleshooting guide offered at the end of this script"

###########################  END SB2040 FLASHING SECTION  #############################################################

type_text "Restarting klipper"
sudo service klipper start

if [ "$INITIAL_INSTALL" -eq 0 ]
then
    type_text "You have installed OctoCanFlash and flashed your system! OctoCanFlash is now installed in $USER_DIR. The original script has been removed and you will need to now run your script from $USER_DIR."
    troubleshooting_tips 5
    #type_text "original script location is $SCRIPT, new directory location is $USER_DIR"   
    type_text "\nJust a little clean up, bear with me....."
    rm "$ORIGINAL_SCRIPT"
    exit 0
else
    troubleshooting_tips 5
    type_text "Thank you for using OctoCanFlash!"
    type_text "Bye!"
    exit 0
fi

###########################  END SCRIPT  ##############################################################################