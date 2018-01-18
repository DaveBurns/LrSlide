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

require 'strict'
local Debug = require 'Debug'.init()

local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrFunctionContext = import 'LrFunctionContext'

local Util = require 'Util'
require 'StringCache'
local JSON = require 'JSON'

if WIN_ENV then
    require 'WinReg'
else
    require 'osascript'
end


-- Custom error handler for JSON decoder so that it doesn't call assert().
-- For the font cache, a failed decode is non-fatal.
-- The 'text' parameter may contain the entire JSON text which could be very large.
function JSON:onDecodeError( message, text, location, etc )
    if text then
        if location then
            message = string.format( '%s at byte %d of: %s', message, location, text)
        else
            message = string.format( '%s: %s', message, text)
        end
    end

    -- delete broken cache file since decode failed. The 'etc' param is the StringCache object.
    etc.delete()

    Util.log( 0, 'Cache contains invalid JSON data: ', message )
end


function newFontFinder()
    local self = {
        fonts = {},
        cache = newStringCache( 'fontCache.txt', 168 ),  -- 168 hours = 1 week
    }


    self.tryToLoadCachedFontList = function()
        local cachedList = self.cache.get()

        if cachedList then
            -- pass the cache in to the etc argument so it can be used in the error handler if necessary
            self.fonts = JSON:decode( cachedList, self.cache ) or {}
        end
    end


    self.saveFontListToCache = function()
        local listAsString = JSON:encode_pretty( self.fonts )

        self.cache.put( listAsString )
    end


    self.deleteFontCache = function()
        return self.cache.delete()
    end


    self.find_fonts_windows = function( progress )
        Util.log( 0, 'Finding fonts on Windows' )
        local registry = newReg()

        progress:setPortionComplete( .25 )

        local winSystemRoot = registry.queryValue( [[HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion]], 'SystemRoot' )
        Util.log( 0, 'SystemRoot:', winSystemRoot )
        local fontList = registry.queryKey( [[HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts]] )
        Util.logpp( 2, 'fontList', fontList )

        progress:setPortionComplete( .50 )

        -- prepend windows font directory to font filenames
        local function fixWindowsFontPath( path )
            local new_path = winSystemRoot .. '/Fonts/' .. path
            return new_path
        end

        local function cleanFontDisplayName( name )
            name = Util.trim( name )
            name = name:gsub( ' %(OpenType%)$', '' )
            name = name:gsub( ' %(TrueType%)$', '' )
--            Util.log( 1, 'new name: ', name )

            return name
        end

        local name_list = {}
        local file_list = {}

        for name, data in pairs( fontList ) do
            table.insert( file_list, fixWindowsFontPath( data ) )
            table.insert( name_list, cleanFontDisplayName( name ) )
        end

        progress:setPortionComplete( .75 )

        return name_list, file_list
    end


    self.find_fonts_osx = function( progress )
        Util.log( 0, 'Finding fonts on OSX' )
        local osaScript = newOSAScript()

        progress:setPortionComplete( .25 )

        local osaArgs = {}
        table.insert( osaArgs, '-e' )
        table.insert( osaArgs, [['tell application "Font Book" to {name, files} of typefaces']] )
        local result = osaScript.run( osaArgs )
        if not result then
            return
        end

        local function cleanOSXFontPath( path )
            -- convert things like 'file Macintosh HD:Library:Fonts:Wingdings 2.ttf' to '/Library/Fonts/Wingdings 2.ttf'
            local new_path = path:gsub( ':', '/' )
            new_path = new_path:gsub( '^.-/', '/' )
--            Util.log( 0, 'cleaned: ', path, new_path )
            return new_path
        end

        local function cleanFontDisplayName( name )
            name = Util.trim( name )
            name = name:gsub( 'MT$', '' )
            name = name:gsub( 'ITC$', '' )
            name = name:gsub( ' MT ', ' ' )
            return name
        end

        progress:setPortionComplete( .5 )

        local name_list = {}
        local file_list = {}

--        Util.log( 0, 'size of stdoutTable: ' .. #stdoutTable )
--        Util.log( 0, 'type of first element: ' .. type( stdoutTable[ 1 ] ) )
        local tokenList = Util.splitString( ', ', osaScript.getStdout()[ 1 ] )
        Util.log( 0, '# of tokens: ' .. #tokenList )
        for _, token in ipairs( tokenList ) do
--            Util.log( 0, token )
            if Util.stringStarts( token, 'file' ) then
                table.insert( file_list, cleanOSXFontPath( token ) )
            else
                table.insert( name_list, cleanFontDisplayName( token ) )
            end
        end

        progress:setPortionComplete( .75 )

        -- Close Font Book app

        Util.log( 0, 'Closing Font Book' )

        local osaArgs = {}
        table.insert( osaArgs, '-e' )
        table.insert( osaArgs, [['tell application "Font Book" to quit']] )
        result = osaScript.run( osaArgs )
        if not result then
            Util.log( 0, 'NON FATAL ERROR: could not close Font Book' )
        end

        return name_list, file_list
    end


    self.findFonts = function()
        return LrFunctionContext.callWithContext( '', self.find_fonts_internal )
    end


    self.find_fonts_internal = function( function_context )
        self.tryToLoadCachedFontList()
        if not Util.isTableEmpty( self.fonts ) then return end

        local progress = LrDialogs.showModalProgressDialog( {
            title = 'Finding fonts',
            cannotCancel = true,
            functionContext = function_context,
        } )

        local name_list, file_list
        if WIN_ENV then
            name_list, file_list = self.find_fonts_windows( progress )
        else
            name_list, file_list = self.find_fonts_osx( progress )
        end


        if #name_list ~= #file_list then
            LrErrors.throwUserError( 'LrSlide: Internal error when retrieving fonts. name and file lists are not equal: '
                                     .. #name_list .. ' ' .. #file_list )
        end

        local supportedFontFileTypes = { ttf = true, otf = true }

        Util.log( 0, 'size of name_list: ' .. #name_list )
        for i = 1, #name_list do
            local fileType = string.lower( LrPathUtils.extension( file_list[ i ] ) )
            if supportedFontFileTypes[ fileType ] then
                local new_font = {}
                new_font[ 'name' ] = name_list[ i ]
                new_font[ 'file' ] = file_list[ i ]
                new_font[ 'format' ] = fileType == 'ttf' and 'truetype' or 'opentype'
                table.insert( self.fonts, new_font )
            end
        end

        table.sort( self.fonts, function( a, b ) return a.name < b.name end )
        
        self.saveFontListToCache()

        progress:setPortionComplete( 1 )
        progress:done()
    end


    self.getFonts = function() return self.fonts end


    self.getNumFonts = function() return #self.fonts end


    self.buildFontNamesMenuForLightroom = function()
        local menu = {}

        for i = 1, #self.fonts do
            local menu_entry = {} -- must make a new one each time or builds a table of identical entries (insert by ref?)
            menu_entry[ 'title' ] = self.fonts[ i ].name
            menu_entry[ 'value' ] = self.fonts[ i ]
            table.insert( menu, menu_entry )
        end

        return menu
    end


    -- use some heuristics to supply a default font
    self.getDefaultFont = function()
        if Util.isTableEmpty( self.fonts ) then
            return {}
        end

        -- sort the list of font names so we can ref them by index
        table.sort( self.fonts, function( a, b ) return a.name < b.name end )

        -- Try to find a font that looks like Arial and if that fails, like Times Roman.
        local fontNameContainsSub = function( font, sub ) return font.name:lower():find( sub ) end
        local fontNumber = Util.tableFindValue( self.fonts, 'arial', fontNameContainsSub )
        if not fontNumber then
            fontNumber = Util.tableFindValue( self.fonts, 'times', fontNameContainsSub )
        end

        -- if all else fails, just default to the first one in the list
        if not fontNumber then
            fontNumber = 1
        end

        return self.fonts[ fontNumber ]
    end


    return {
        deleteFontCache = self.deleteFontCache,
        getFonts = self.getFonts,
        getNumFonts = self.getNumFonts,
        findFonts = self.findFonts,
        buildFontNamesMenuForLightroom = self.buildFontNamesMenuForLightroom,
        getDefaultFont = self.getDefaultFont,
    }
end

--local LrFunctionContext = import 'LrFunctionContext'
--LrFunctionContext.postAsyncTaskWithContext( 'fontTest', Debug.showErrors ( function()
--    local ff = newFontFinder()
--    ff.findFonts()
--    Util.logpp( 0, ff.getFonts() )
--    Util.logpp( 0, 'There are ' .. ff.getNumFonts() .. ' fonts.' )
--end )
--);
