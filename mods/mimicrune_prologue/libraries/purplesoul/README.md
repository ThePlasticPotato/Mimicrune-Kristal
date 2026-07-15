# Skerch's Purple Soul V2!

My second purple soul library for the DELTARUNE Fangame engine [Kristal](https://kristal.cc/), this time with a lot more customizeablility, moving strings should be a struggle of the past.

# Features

## Strings
Strings are now objects! You can move them around and rotate them and they work (hopefully) without any issues!
The string's constructor is:

PurpleString(x, y, lay, l, r)

x - The string's center's X position(stored as the PurpleString.x variable)

y - The string's center's Y position(stored as the PurpleString.y variable)

lay - The string's layer(stored as the PurpleString.layer variable)

l - The string's length(going through the center, each side is half of the length, stored as the PurpleString.len variable)

r - The string's rotation(in radians, 0 is a regular horizontal string, stored as the PurpleString.rot variable)

The strings also have some extra variables and functions that would be nice to know for anyone wanting to make advanced things with the strings:

PurpleString.leftBound - A table of the x and y values of the string's "left most point"(this is relative to the rotation, so if the rotation is pi this would actually be the right bound)

PurpleString.rightBound - A table of the x and y values of the string's "right most point"(this is also relative)

PurpleString:getPositionBetweenBounds(progress) - This gets a location between the left bound and right bound, the "progress" argument is a range from 0-1(0 is the left bound 1 is the right bound), for example PurpleString:getPositionBetweenBounds(0.5) would give you the midpoint of the left and right bounds.

## Config
There are several options in the library's config(found in lib.json) that change certain things to your desired purple soul type, I recommend you play around with these until you find what you feel like you want for your use:

visuallyRotateSoul - When the soul goes on a string if this is on it will visually rotate to match the string's rotation, if not on it will stay in the upright rotation.

correctControlsForRotation - When the soul moves on a string its percentage on the string changes, this can look as if the controls are inverted when the string is upside down or in other rotations so this config option localizes the controls to match the soul's rotation, so if the soul is upside down the right equivalent input will be left.

diagonalControls - This modifies the previous option to also include diagonal inputs, so if the string is rotated diagonally right downwards then the input to go right will be down+right

directionalJumps - This makes it so the soul goes between strings in the direction of the string, so if the string is rotated 90 degrees(converted to radians of course) the soul's "jumps"(moving between strings) will go left and right instead of up and down.

stringWidth - The width of the strings.

stringColor - The color of the strings.

## Examples
The library comes with some example waves to show some things it can do and to let you play around with the config.
