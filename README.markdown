Adium Campfire
==============

AdiumCampfire adds support for [37signals' Campfire](http://campfirenow.com/) to [Adium](http://adium.im/) instant messaging application.

This is a pre-beta version of software that should be treated like a working prototype. There is no support for files and transcripts and the plugin is still leaking memory. As it shouldn't be used by normal people, the only way to get a working plugin, is to compile it oneself from the code in the repository.

Installation
------------
1. Checkout the [AdiumCampfire repository](https://github.com/zuber/AdiumCampfire) to a local directory.
2. Checkout the [Adium 1.4 repository](http://trac.adium.im/wiki/GettingNewestAdiumSource) to a local directory.
3. Open the project in XCode, go to project build settings and change the `ADIUM` variable to point to the directory containing a checkout of Adium 1.4 source code.
4. Build the project.
5. Double-click on `build/Debug/AdiumCampfire.AdiumPlugin` to install it.

Usage
-----
1. Change the Campfire domain in the source code (Yes! There is no other way to change the domain currently).
2. Start Adium.
3. Navigate to `File->Add Account` in the menu and choose `Campfire` in the dropdown list.
4. Put your Campfire username as username and your [API authentication token](https://setjam.campfirenow.com/member/edit) as password.
5. All the Campfire rooms in the domain should be now available under the *Campfire* group.

License
-------
The MIT License

Copyright (c) 2010 Marek Stępniowski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


