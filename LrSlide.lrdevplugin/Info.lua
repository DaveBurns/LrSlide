--[[----------------------------------------------------------------------------

MIT License

Copyright (c) 2017 David F. Burns

This file is part of LrSlide.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

------------------------------------------------------------------------------]]


return {
	LrSdkVersion = 6.0,
	LrSdkMinimumVersion = 6.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'com.daveburnsphoto.lightroom.LrSlide',
	LrPluginName = 'LrSlide',
	LrPluginInfoUrl = 'https://github.com/DaveBurns/LrSlide',

    VERSION = { major = 1, minor = 0, revision = 0, display = '1.0.0.20180101' },

    LrPluginInfoProvider = 'PluginInfoProvider.lua',

    LrMetadataProvider = 'LrSlideMetadataDefinitionFile.lua',

    LrLibraryMenuItems = {
        {
            title = 'Add Slide...',
            file = 'AddSlide.lua',
        },
        {
            title = 'Edit Slide...',
            file = 'EditSlide.lua',
            enabledWhen = 'photosSelected',
        },
        {
            title = 'Re-render selected slides',
            file = 'RerenderSlides.lua',
            enabledWhen = 'photosSelected',
        },
    },
}
