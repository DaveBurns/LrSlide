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

local Util = require 'Util'

require 'Chrome'
local markdown = require 'markdown'


function newSlideGenerator( config )
    local self = {
        chrome = newChrome( config.chromePath );
        width = config.slideWidth or 1024,
        height = config.slideHeight or 768,
        text = '',
        html = '',
        styles = '',
        font = {},
        stylesheetPath = config.stylesheetPath or ( _PLUGIN.path .. '/defaults/styles.css' )
    }


    self.setSize = function( width, height )
        self.width = width
        self.height = height
    end


    self.setText = function( text )
        Util.log( 2, 'setText\n', text )
        Util.logStringToHex( 2, text )

        self.text = text
    end


    self.setStyles = function( properties )
        local s = '\n\nbody {\n';

        if properties.backgroundColor then
            s = s .. '\tbackground-color: ' .. Util.convertLrColorToCSSColor( properties.backgroundColor ) .. ';\n'
        end

        if properties.textColor then
            s = s .. '\tcolor: ' .. Util.convertLrColorToCSSColor( properties.textColor ) .. ';\n'
        end

        if properties.textSize then
            s = s .. '\tfont-size: ' .. properties.textSize .. 'px;\n'
        end

        if properties.justification then
            s = s .. '\ttext-align: ' .. string.lower( properties.justification ) .. ';\n'
        end

        s = s .. '\t}\n'

        -- Add style to make <hr> match text color
        if properties.textColor then
            s = s ..
            'hr {\n' ..
            '\tborder-color: ' .. Util.convertLrColorToCSSColor( properties.textColor ) .. ';\n' ..
            '\t}\n'
        end

        if properties.verticalCenter then
            s = s .. [[ div#inner { vertical-align: middle; } ]] .. '\n'
        end

        self.styles = s
    end


    self.setFont = function( font )
        self.font = font
    end


    self.render = function( outputPath )
        Util.log( 0, 'Rendering slide in ' .. outputPath )

        -- 1) Do some pre-processing on the raw text

        -- Lightroom's GUI uses the UTF8 line separator when a user enters Enter within a text box.
        -- Translate these to <br/>. This is a break from standard Markdown which requires two or more spaces at the end of a line
        -- to force a <br/>. We'll see if this breaks something.
        local UTF8LineSeparator = [[\xE2\x80\xA8]]
        UTF8LineSeparator = UTF8LineSeparator:gsub( '\\x(%x%x)', function ( x ) return string.char( tonumber( x, 16 ) ) end )

        self.text = self.text:gsub( UTF8LineSeparator, '  \n' )
        self.text = self.text:gsub( '\10', '  \n' )

        Util.log( 2, 'AFTER FILTERING LINE BREAKS\n', self.text )
        Util.logStringToHex( 2, self.text )

        -- 2) Apply the markdown filter

        local markdown_text = markdown( self.text )

        -- markdown replaces two or more spaces with ' <br/>' but that extra space makes
        -- right-justified lines not line up so remove it.
        markdown_text = markdown_text:gsub( ' <br/>', '<br/>' )

        Util.log( 2, 'AFTER MARKDOWN\n', markdown_text )
        Util.logStringToHex( 2, markdown_text )


        -- 3) Read the HTML template, merge in the CSS, replace any tokens

        local template = Util.readFileIntoString( _PLUGIN.path .. '/defaults/slide.html' )
        local defaultStylesheet = Util.readFileIntoString( self.stylesheetPath )
        local css = defaultStylesheet .. self.styles
        local tokenTable = {
            BODY = markdown_text,
            CSS = css,
            FONTFILENAME = self.font[ 'file' ],
            FONTFORMAT = self.font[ 'format' ],
        }

        Util.logpp( 2, 'self.font: ', self.font )
        Util.logpp( 2, 'tokenTable: ', tokenTable )

        self.html = Util.replaceTokens( tokenTable, template, '|' )

        Util.log( 2, 'self.html', self.html )

        self.chrome.renderHTMLtoFile( self.html, self.width, self.height, outputPath )
    end


    -- constructor:
    return {
        setSize = self.setSize,
        setText = self.setText,
        setStyles = self.setStyles,
        setFont = self.setFont,
        render = self.render,
    }
end
