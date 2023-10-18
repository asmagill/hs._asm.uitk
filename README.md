hs._asm.uitk
=============

This module provides user interface elements for Hammerspoon including windows, buttons, menus, controls, and other views.

It is in very early stages and is currently undocumented. If you're familiar with its predecessor, `hs._asm.guitk` or want to take a gander at the Examples, feel free...

### Building

There are currently no pre-built releases. To build and install it, you must have XCode installed on your Mac. Then, clone this repository and do the following (the uninstall-everything is recommended, but not strictly required... some things are still being reorganized and uninstalling first will make sure your installation only contains the necessary files):

~~~sh
$ cd uitk
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make uninstall-everything
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make clean-everything install-everything
~~~

If your Hammerspoon application is found in your applications folder, you don't need to supply the `HS_APPLICATION` variable.

If your Hammerspoon configuration is found in the default location `~/.hammerspoon`, you don't need to supply the `PREFIX` variable.

So far this has only been tested on a Silicon based Macs, running the latest version of Hammerspoon, but it should work without change on Intel machines -- please let me know if you find out otherwise (I just haven't gotten around to trying yet).

### Usage Notes

Once you load `hs._asm.uitk`, it can lazily (and silently) load any submodule you require as you require it. As such, I haven't tested loading specific modules directly very much... I *think* they will properly load any prerequisites, but I strongly recommend the approach described here and taken in the example code. E.g.

~~~lua

local uitk      = require("hs._asm.uitk")
local element   = uitk.element
local container = uitk.element.container -- or just element.container, since we did that above
... etc ...

~~~
