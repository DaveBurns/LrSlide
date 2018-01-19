--[[----------------------------------------------------------------------------

MIT License

Copyright (c) 2018 David F. Burns

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

require 'strict'
local Debug = require 'Debug'.init()

local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrFunctionContext = import 'LrFunctionContext'
local LrFileUtils = import 'LrFileUtils'
local LrColor = import 'LrColor'
local LrHttp = import 'LrHttp'
local LrPrefs = import 'LrPrefs'

local Util = require 'Util'
require 'FontFinder'


local function showTextInADialog( title, text )

    LrFunctionContext.callWithContext( "showTextInADialog", Debug.showErrors( function( _ )
        local f = LrView.osFactory()
        local _, numLines = text:gsub( '\n', '\n' )
        local c
        local thresholdForScrollable = 30

        -- Create the contents for the dialog.
        -- if it's a short license, just show a static control. Else, put the static control in a scrollable view.
        if numLines <= thresholdForScrollable then
            c = f:row {
                f:static_text {
                    selectable = true,
                    title = text,
                    size = 'small',
                    height_in_lines = -1,
                    width = 550,
                }
            }
        else
            c = f:row {
                f:scrolled_view {
                    horizontal_scroller = false,
                    width = 600,
                    height = thresholdForScrollable * 14,
                    f:static_text {
                        selectable = true,
                        title = text,
                        size = 'small',
                        height_in_lines = -1,
                        width = 550,
                    }
                }
            }
        end

        LrDialogs.presentModalDialog {
            title = title,
            contents = c,
            cancelVerb = '< exclude >',
        }


    end ) )

end


local function startDialog( propertyTable )
    local prefs = LrPrefs.prefsForPlugin()

    Util.log( 0, 'PLUGIN MANAGER: startDialog' )
    Util.logpp( 0, prefs )

    propertyTable.chromePath = prefs.chromePath or ''
    propertyTable.slideWidth = prefs.slideWidth or 1024
    propertyTable.slideHeight = prefs.slideHeight or 768
end


local function endDialog( propertyTable )
    local prefs = LrPrefs.prefsForPlugin()

    Util.log( 0, 'PLUGIN MANAGER: endDialog' )

    prefs.chromePath = propertyTable.chromePath
    prefs.slideWidth = propertyTable.slideWidth
    prefs.slideHeight = propertyTable.slideHeight

    Util.logpp( 0, prefs )
end


local function validateChromeExecutable( _, path )
    local exists, errorMessage

    path = Util.trim( path )

    -- special case: valid if the path is empty
    if #path == 0 then
        return true, path
    end

    exists = LrFileUtils.exists( path )
    if exists and exists == 'file' then
        return true, path
    end

    errorMessage = 'Could not find Chrome at the path given:\n\n' .. path .. '\n\nPlease provide a correct path or leave the path blank.'
    Util.log( 0, errorMessage )
    return false, '', errorMessage
end


-- Section for the top of the dialog.
local function sectionsForTopOfDialog( f, propertyTable )
    local bind = LrView.bind
    local share = LrView.share

    local ChromeMessage
    local test, _, msg = validateChromeExecutable( nil, propertyTable.chromePath )
    if not test then ChromeMessage = msg end

    Util.log( 0, 'PLUGIN MANAGER: sectionsForTopOfDialog' )
--    Util.logpp( 0, propertyTable )

    return {
        {
            title = 'License Info',
            synopsis = 'Expand for license info',

            f:row {
                f:push_button {
                    title = "Show license...",
                    action = Debug.showErrors(function( _ )
                        showTextInADialog(
                            'License for LrSlide',
                            Util.readFileIntoString( _PLUGIN.path .. '/licenses/LICENSE' )
                        ) end ),
                },
            },

            f:row {
                f:separator {
                    fill_horizontal = 1,
                },
            },

            f:row {
                f:static_text {
                    title = 'This plugin makes use of code from 3rd parties:',
                },
            },

            f:row {
                f:static_text {
                    title = 'markdown.lua',
                    text_color = LrColor( 'blue' ),
                    mouse_down = function() LrHttp.openUrlInBrowser( 'https://github.com/mpeterv/markdown' ) end
                },

                f:push_button {
                    title = "Show license...",
                    action = Debug.showErrors( function( _ )
                        showTextInADialog(
                            'License for markdown.lua',
                            Util.readFileIntoString( _PLUGIN.path .. '/licenses/LICENSE.markdown' )
                        ) end ),
                },
            },

            f:row {
                f:static_text {
                    title = 'UTF 8 Lua Library',
                },

                f:push_button {
                    title = "Show license...",
                    action = Debug.showErrors( function( _ )
                        showTextInADialog(
                            'License for Lua UTF-8 Library',
                            Util.readFileIntoString( _PLUGIN.path .. '/licenses/LICENSE.utf8' )
                        ) end ),
                },
            },

            f:row {
                f:static_text {
                    title = 'Simple JSON Encode/Decode from Jeffrey Friedl',
                    text_color = LrColor( 'blue' ),
                    mouse_down = function() LrHttp.openUrlInBrowser( 'http://regex.info/blog/lua/json' ) end
                },

                f:push_button {
                    title = "Show license...",
                    action = function() LrHttp.openUrlInBrowser( 'https://creativecommons.org/licenses/by/3.0/legalcode' ) end,
                },
            },

        },

        {
            title = 'Advanced Settings',
            synopsis = function()
                local s = ''

                if #propertyTable.chromePath > 0 then
                    s = s .. 'Custom Chrome'
                else
                    s = s .. 'Default Chrome'
                end

                return s
            end,


            f:row {
                f:column {
                    spacing = f:control_spacing(),
                    fill = 1,

                    f:static_text {
                        title = "By default, LrSlide will automatically find Chrome. If for some reason it can't, or if you need to override this, you can enter the location here. Most users will leave this blank.",
                        fill_horizontal = 1,
                        width_in_chars = 55,
                        height_in_lines = 2,
                        size = 'small',
                    },

                    ChromeMessage and f:static_text {
                        title = ChromeMessage,
                        fill_horizontal = 1,
                        width_in_chars = 55,
                        height_in_lines = 5,
                        size = 'small',
                        text_color = import 'LrColor'( 1, 0, 0 ),
                    } or 'skipped item',

                    f:row {
                        spacing = f:label_spacing(),

                        f:static_text {
                            title="Path to Chrome:",
                            alignment = 'right',
                            width = share 'title_width',
                        },
                        f:edit_field {
                            value = bind { key = 'chromePath', object = propertyTable },
                            fill_horizontal = 1,
                            width_in_chars = 25,
                            validate = validateChromeExecutable,
                        },
                        f:push_button {
                            title = "Browse...",
                            action = Debug.showErrors( function( _ )
                                local options =
                                {
                                    title = 'Find the Chrome program:',
                                    prompt = 'Select',
                                    canChooseFiles = true,
                                    canChooseDirectories = false,
                                    canCreateDirectories = false,
                                    allowsMultipleSelection = false,
                                }
                                if ( WIN_ENV == true ) then
                                    options.fileTypes = 'exe'
                                else
                                    options.fileTypes = ''
                                end
                                local result
                                result = LrDialogs.runOpenPanel( options )
                                if ( result ) then
                                    propertyTable.chromePath = Util.trim( result[ 1 ] )
                                end
                            end )
                        },
                    },
                },
            },

            f:separator {
                fill_horizontal = 1,
            },

            f:row {
                f:column {
                    spacing = f:control_spacing(),
                    fill = 1,

                    f:static_text {
                        title = "For performance reasons, LrSlide only scans for your system's fonts once per week. If you need to force it to rescan now, click the button below.",
                        fill_horizontal = 1,
                        width_in_chars = 55,
                        height_in_lines = 3,
                        size = 'small',
                    },

                    f:row {
                        spacing = f:label_spacing(),

                        f:push_button {
                            title = "Delete font cache",
                            action = Debug.showErrors( function( _ )
                                local fontFinder = newFontFinder()
                                fontFinder.deleteFontCache()
                                LrDialogs.message( 'The font cache was deleted.' )
                                end ),
                        },
                    },
                },
            },
        },

        {
            title = 'Size of Slides',
            synopsis = function()
                return propertyTable.slideWidth .. ' x ' .. propertyTable.slideHeight .. ' pixels'
            end,

            f:column {
                spacing = f:control_spacing(),
                fill = 1,

                f:static_text {
                    title = 'Set the size for new slides here. If you want to change the size of existing slides, set the size here, press Done, then select the slides and choose Library -> Plug-in Extras -> LrSlide -> Re-render selected slides.',
                    fill_horizontal = 1,
                    width_in_chars = 55,
                    height_in_lines = 2,
                    size = 'small',
                },

                f:row {
                    spacing = f:label_spacing(),

                    f:static_text {
                        title = 'Width:',
                        alignment = 'right',
                    },
                    f:edit_field {
                        value = bind { key = 'slideWidth', object = propertyTable },
                        width_in_chars = 10,
                        validate = function( _, value )
                            local number = tonumber( Util.trim( value ) )

                            if not number then
                                return false, '', "The slide width must be made of only digits."
                            end

                            local int = math.floor( number )

                            if int < 1 or int > 5000 then
                                return false, '', "The slide width must be between 1 and 5000."
                            end

                            return true, value
                        end
                    },

                    f:static_text {
                        title = 'Height:',
                        alignment = 'right',
                    },
                    f:edit_field {
                        value = bind { key = 'slideHeight', object = propertyTable },
                        width_in_chars = 10,
                        validate = function( _, value )
                            local number = tonumber( Util.trim( value ) )

                            if not number then
                                return false, '', 'The slide height must be made of only digits.'
                            end

                            local int = math.floor( number )

                            if int < 1 or int > 5000 then
                                return false, '', 'The slide width must be between 1 and 5000.'
                            end

                            return true, value
                        end
                    },
                },
            },
        }
    }
end


return {
    sectionsForTopOfDialog = sectionsForTopOfDialog,
    startDialog = startDialog,
    endDialog = endDialog,
}
