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

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrColor = import 'LrColor'
local LrTasks = import 'LrTasks'

local Util = require 'Util'
require 'FontFinder'


function newSlideDialog()
    local self = {
        fontFinder = newFontFinder(),
        closeFmtHelpFuncs = nil,
        fmtHelpIsShowing = false,
    }

    local setDefaults = function( properties )
        properties.text = properties.text or ''
        properties.backgroundColor = properties.backgroundColor or LrColor( 'black' )
        properties.textColor = properties.textColor or LrColor( 'white' )
        properties.textSize = properties.textSize or 72
        properties.justification = properties.justification or 'Center'
        properties.font = properties.font or self.fontFinder.getDefaultFont()
        properties.verticalCenter = properties.verticalCenter or false
    end


    local lrsFormattingHelpContents = function()
        local f = LrView.osFactory() -- obtain a view factory

        local contents = f:column {
            spacing = f:control_spacing(),
            margin = 18,

            f:row {
                spacing = f:label_spacing(),

                f:static_text {
                    selectable = true,
                    title = 'Simple instructions first\n\nThen Markdown for intermediate use..\n\nThen HTML for advanced use.',
--                    size = 'small',
                    height_in_lines = -1,
                    width = 550,
                }
            },
            --f:row {
            --    spacing = f:label_spacing(),
            --
            --    f:push_button {
            --        place_horizontal = 1,
            --        title = 'Close',
            --        action = Debug.showErrors( function( _ )
            --            Util.log( 0, 'Closing fmt help window' )
            --            self.closeFmtHelpFuncs[ 'close' ]()
            --        end )
            --    }
            --},
        }

        return contents
    end


    local lrsDialogContents = function( properties, fontList )
        local f = LrView.osFactory() -- obtain a view factory

        local contents = f:column {
            bind_to_object = properties, -- default bound table is the one we made
            spacing = f:control_spacing(),

            f:row {
                spacing = f:label_spacing(),

                f:edit_field {
                    fill_horizontal = 1,
                    height_in_lines = 10,
                    width_in_chars = 40,
                    allow_newlines = true,
                    value = LrView.bind( 'text' ), -- edit field shows settings value
                },
            },
            f:row {
                f:push_button {
                    place_horizontal = 1,
                    size = 'small',
                    title = 'Show formatting help...',
                    action = Debug.showErrors( function( _ )
                        if self.fmtHelpIsShowing then
                            self.closeFmtHelpFuncs[ 'toFront' ]()
                        else
                            self.fmtHelpIsShowing = true
                            LrDialogs.presentFloatingDialog(
                            _PLUGIN,
                            {
                                title = 'Slide Formatting Help',
                                contents = lrsFormattingHelpContents(),
                                save_frame = 'lrsFmtHelpWinPos',
                                onShow = function( funcs )
                                    self.closeFmtHelpFuncs = funcs
                                end,
                                windowWillClose = function()
                                    self.fmtHelpIsShowing = false
                                end,
                            }
                            )
                        end
                    end ),
                },

            },
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = "Background color",
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },

                f:color_well {
                    value = LrView.bind( 'backgroundColor' )
                },
            },
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = "Text color",
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },

                f:color_well {
                    value = LrView.bind( 'textColor' )
                },
            },
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = "Text size",
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },

                f:combo_box {
                    value = LrView.bind( 'textSize' ),
                    width_in_digits = 3,
                    min = 1,
                    max = 999,
                    precision = 0,
                    items = { 12, 16, 20, 24, 30, 36, 48, 72, 96 },
                },
            },
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = "Justification",
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },

                f:popup_menu {
                    value = LrView.bind( 'justification' ),
                    width_in_chars = 5,
                    items = {
                        'Center',
                        'Right',
                        'Left',
                    },
                },
            },
            f:row {
                f:static_text {
                    title = 'Vertically Centered',
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },
                f:checkbox {
                    title = '',
                    value = LrView.bind( 'verticalCenter' ),
                },
            },
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = "Font",
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },

                f:popup_menu {
                    fill_horizontal = 1,
                    value = LrView.bind( 'font' ),
                    items = fontList,
                    value_equal = function( value1, value2 )
                        return value1.name == value2.name
                    end,
                },
            },
        }

        return contents
    end



    local run = function( properties, mode, context )
        self.fontFinder.findFonts()
        local fontMenu = self.fontFinder.buildFontNamesMenuForLightroom()

        setDefaults( properties )

        local dialogTitle = mode == 'add' and 'Add Slide' or 'Edit Slide'

        local result = LrDialogs.presentModalDialog( -- invoke a dialog box
            {
                title = dialogTitle,
                contents = lrsDialogContents( properties, fontMenu ), -- with the UI elements
                actionVerb = dialogTitle, -- label for the action button
            }
        )

        if self.fmtHelpIsShowing then
            self.closeFmtHelpFuncs[ 'close' ]()
        end

        Util.log( 0, 'dialog results: ' .. result )
        --    Util.log( 0, 'The text entered was: ', properties.text )

        return result == 'ok'
    end


    -- constructor:
    return {
        run = run,
    }
end
