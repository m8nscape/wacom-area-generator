#!/bin/bash

echo "xsetwacom list devices returns:"
xsetwacom list devices
echo
read -p "Choose Device Id: " ID
echo

if [ -z $ID ]; then
    exit 1
fi

# Get current rotate state
# This is used to pre-process Area
ROTATE=`xsetwacom get $ID rotate`

# Multi-sampling should be disabled for the game osu!
xsetwacom set $ID RawSample 1
xsetwacom set $ID Suppress 1

# Get Raw Area
AREA=`xsetwacom get $ID Area`
MIN_X=`echo $AREA | cut -d' ' -f1`
MIN_Y=`echo $AREA | cut -d' ' -f2`
MAX_X=`echo $AREA | cut -d' ' -f3`
MAX_Y=`echo $AREA | cut -d' ' -f4`

# Reset Area to get Full Area
xsetwacom set $ID ResetArea
BORDER=`xsetwacom get $ID Area`
BORDER_X=`echo $BORDER | cut -d' ' -f3`
BORDER_Y=`echo $BORDER | cut -d' ' -f4`

# Restore Area to prevent Interrupts-caused data lose
xsetwacom set $ID Area $AREA

# Calculate current Area Size
AREA_W=$(($MAX_X - $MIN_X))
AREA_H=$(($MAX_Y - $MIN_Y))

# Show Old Area
if [ $ROTATE = "half" ]; then

    # Reverse Area Point
    MAX_X_REV=$(($BORDER_X - $MIN_X))
    MAX_Y_REV=$(($BORDER_Y - $MIN_Y))
    MIN_X_REV=$(($BORDER_X - $MAX_X))
    MIN_Y_REV=$(($BORDER_Y - $MAX_Y))

    OLD_SCALE=`echo 2k $AREA_W $AREA_H /p | dc`
    echo "Current Area (Rotated):"
    echo "    Size:  $AREA_W x $AREA_H"
    echo "    Scale: $OLD_SCALE"
    echo "    Axis:  ($MIN_X_REV, $MIN_Y_REV) ~ ($MAX_X_REV, $MAX_Y_REV)"
    echo
    
    MIN_X=$MIN_X_REV
    MIN_Y=$MIN_Y_REV
    
    read -p "Rotate Tablet (Left-handed Mapping)? [Y/n] " ROTATE_IN
    case $ROTATE_IN in
    [nN][oO]|[nN])
        ROTATE_NEW=no
        ;;
    *)
        ROTATE_NEW=yes
        ;;
    esac

elif [ $ROTATE = "none" ]; then
    
    OLD_SCALE=`echo 2k $AREA_W $AREA_H /p | dc`
    echo "Current Area:"
    echo "    Size:  $AREA_W x $AREA_H"
    echo "    Scale: $OLD_SCALE"
    echo "    Axis:  ($MIN_X, $MIN_Y) ~ ($MAX_X, $MAX_Y)"
    echo

    read -p "Rotate Tablet (Left-handed Mapping)? [y/N] " ROTATE_IN
    case $ROTATE_IN in
    [yY][eE][sS]|[yY])
        ROTATE_NEW=yes
        ;;
    *)
        ROTATE_NEW=no
        ;;
    esac
fi

# Input New Area
read -p "Input New Left-Top Point (Default $MIN_X, $MIN_Y): " NEW_X NEW_Y
if [ -z $NEW_X ]; then NEW_X=$MIN_X; fi
if [ -z $NEW_Y ]; then NEW_Y=$MIN_Y; fi

read -p "Force proportion? (x/y) (Default $OLD_SCALE, 0 for not forcing) " SCALE
if [ -z $SCALE ]; then SCALE=$OLD_SCALE; fi

# Force Propotion
if [ $SCALE != 0 ]; then

    # base X
    read -p "Input New Area Size X (Default $AREA_W, ENTER for base Y): " NEW_W
    if ! [ -z $NEW_W ]; then 
        NEW_H=`echo 0k $NEW_W $SCALE /p | dc`
        
    # base Y
    else
        read -p "Input New Area Size Y (Default $AREA_H): " NEW_H
        if [ -z $NEW_H ]; then NEW_H=$AREA_H; fi
        NEW_W=`printf '%.*f\n' 0 $(echo $NEW_H\*$SCALE | bc)`
        
    fi

# Not force propotion
else
    read -p "Input New Area Size (Default $AREA_W $AREA_H): " NEW_W NEW_H
    if [ -z $NEW_W ]; then NEW_W=$AREA_W; fi
    if [ -z $NEW_H ]; then NEW_H=$AREA_H; fi
    
fi
    
#Rotating
case $ROTATE_NEW in
yes)
    # Return New Area
    echo
    echo "New Area (Rotated): "
    echo "    Size:  ($NEW_W x $NEW_H)"
    echo "    Scale: `echo 2k $NEW_W $NEW_H /p | dc`"
    echo "    Axis:  ($NEW_X, $NEW_Y) ~ ($(($NEW_X + $NEW_W)), $(($NEW_Y + $NEW_H)))"
    
    # Set Area
    NEW_MAX_X_REV=$(($BORDER_X - $NEW_X))
    NEW_MAX_Y_REV=$(($BORDER_Y - $NEW_Y))
    NEW_MIN_X_REV=$(($BORDER_X - $(($NEW_X + $NEW_W))))
    NEW_MIN_Y_REV=$(($BORDER_Y - $(($NEW_Y + $NEW_H))))
    
    xsetwacom set $ID Area $NEW_MIN_X_REV $NEW_MIN_Y_REV $NEW_MAX_X_REV $NEW_MAX_Y_REV
    xsetwacom set $ID Rotate half
    ;;
    
no)
    # Return New Area
    echo
    echo "New Area: "
    echo "    Size:  ($NEW_W x $NEW_H)"
    echo "    Scale: `echo 2k $NEW_W $NEW_H /p | dc`"
    echo "    Axis:  ($NEW_X, $NEW_Y) ~ ($(($NEW_X + $NEW_W)), $(($NEW_Y + $NEW_H)))"
    
    xsetwacom set $ID Area $NEW_X $NEW_Y $(($NEW_X + $NEW_W)) $(($NEW_Y + $NEW_H))
    xsetwacom set $ID Rotate none
    ;;
    
esac

echo
