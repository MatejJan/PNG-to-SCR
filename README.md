## PNG to SCR online converter

PNG to SCR is a tool for artists that create ZX Spectrum artworks in the usual (pixel art) graphics software such as Photoshop, GIMP, Aseprite, Pixaki etc. 

It allows you to take the exported PNG file and convert it into a SCR (video memory dump) or TAP that you can load into a real (or emulated) machine with `LOAD "" $SCREEN`.

Online build: [www.retronator.com/png-to-scr](http://www.retronator.com/png-to-scr)

Main user interface:

![](http://i.imgur.com/miTt1MJ.png)

Every spectrum image has multiple alternatives in which ink/color choices to make, so the tool has options on the strategy to use.

Match mode (pictured above) tries to create something close to what an artist would manually choose (preserving same-colored shapes as much as possible).

Bigger area + Paper for single blocks (or Smaller area + Ink) gives you something that looks like lineart (tries to use minimum pixels covered with ink):

![](http://i.imgur.com/PMGYfYA.png)

When you manually try to conform to attribute clash, it's hard to catch everything, so the tool gives you error detection:

![](http://i.imgur.com/WzmaoJo.gif)

As you can see above it supports images of non-screen dimensions. However, the conversion will happen only on a screen-sized region:

![](http://i.imgur.com/YOLv9uk.png)

When I get some more time (and need) I will add the user interface to select a custom cropped area.

It's also missing support for non-screen images that don't have the attribute grid aligned to 0,0.

The online version doesn't have the "Preview TAP" feature yet even though you can see it in these screenshots (from development build).

The images in the screenshots are [my works](http://retronator.deviantart.com/gallery/36226378/Pixel-Art).
