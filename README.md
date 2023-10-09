hs._asm.uitk
=============

This module provides user interface elements for Hammerspoon including panels (windows), buttons, menus, controls, and other views.

It is in very early stages and is currently undocumented. If you're familiar with its predecessor, `hs._asm.guitk` or want to take a gander at the Examples, feel free...

### Building

There are currently no pre-built releases. To build and install it, you must have XCode installed on your Mac. Then, clone this repository and do the following:

~~~sh
$ cd uitk
$ [HS_APPLICATION=/Applications] [PREFIX=~/.hammerspoon] make clean-everything install-everything
~~~

If your Hammerspoon application is found in your applications folder, you don't need to supply the `HS_APPLICATION` variable.

If your Hammerspoon configuration is found in the default location `~/.hammerspoon`, you don't need to supply the `PREFIX` variable.

So far this has only been tested on a Silicon based Macs, running the latest version of Hammerspoon, but it should work without change on Intel machines -- please let me know if you find out otherwise (I just haven't gotten around to trying yet).
