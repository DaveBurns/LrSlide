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

--local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
--local LrErrors = import 'LrErrors'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
--local LrColor = import 'LrColor'

local utf8 = require 'utf8'

local Util = {}


function Util.isTableEmpty( t )
    return next( t ) == nil
end


-- Must declare this global to make 'strict' happy
_G.LrSlideLogLevel = 1


--[[
-- Log a list of arguments but only if the level is below the threshold.
--
-- By convention:
-- 0: always log
-- 1: debug info
-- 2: detailed tracing info
--]]

function Util.log( level, ... )
    local maxlevel = rawget( _G, 'LrSlideLogLevel' ) or 1
    if level > maxlevel then return end

    Debug.logn( unpack( arg ) )

end


function Util.logpp( level, ... )
    local maxlevel = rawget( _G, 'LrSlideLogLevel' ) or 1
    if level > maxlevel then return end

    Debug.lognpp( unpack( arg ) )

end


function Util.logStringToHex( level, buf )
    local maxlevel = rawget( _G, 'LrSlideLogLevel' ) or 1
    if level > maxlevel then return end

    local result = ''

    local function concat( s )
        result = result .. s
    end

    for i = 1, math.ceil( #buf / 16 ) * 16 do
        if ( i - 1 ) % 16 == 0 then concat( string.format( '%08X  ', i - 1 ) ) end
        concat( i > #buf and '   ' or string.format( '%02X ', buf:byte( i ) ) )
        if i %  8 == 0 then concat( ' ' ) end
        if i % 16 == 0 then
            concat( buf:sub( i - 16 + 1, i ):gsub( '%c', '.' ), '\n' )
            Debug.log:trace( result )
            result = ''
        end
    end
end



--[[---------------------------------------------------------
    Name: tableHasValue
    Desc: Returns whether the value is in given table
-----------------------------------------------------------]]
function Util.tableFindValue( t, val, f )
    local test = f or function( v, val ) return v == val end

    for k, v in pairs( t ) do
--        Util.log( 2, 'LOOP: ', k, v )
        if test( v, val ) then return k end
    end

    return nil
end


function Util.isLrObservableTable( t )
    return type( t ) == 'table' and type( t[ '< contents >' ] ) ~= 'nil'
end


function Util.LrObservableTableToString( t, keysToSkip )
--    Util.log( 2, 'LrObservableTableToString: ', Util.tableToString( t ) )

    local function table_r( t, name, indent )
        local out = {}  -- result
        local tag = ''

        if keysToSkip and type( keysToSkip ) == 'table' then
            if keysToSkip[ name ] then
                return '\n'
            end
        end

        if name then
            tag = indent .. name .. ' = '
        end

        if type( t ) == 'table' then
            table.insert( out, tag .. '{' )

            -- if is SDK object then we must be logging the observable table at the top level
            if Util.isLrObservableTable( t ) then
                for key, value in t:pairs() do
                    table.insert( out, table_r( value, key, indent .. '\t' ) )
                end
                table.insert( out, indent .. '}' ) -- tricky: if LrObservableTable, it's top level so don't add a comma
            else
                for key, value in pairs( t ) do
                    table.insert( out, table_r( value, key, indent .. '\t' ) )
                end
                table.insert( out, indent .. '},' ) -- tricky: if a plain Lua table, add a comma because it's not at the top level
            end
        else
            local val

            if type( t ) == 'number' or type( t ) == 'boolean' then
                val = tostring( t )
            else
                val = '"' .. tostring( t ) .. '"'
            end
            table.insert( out, tag .. val .. ',' )
        end

        return table.concat( out, '\n' )
    end

    local result = table_r( t, nil, '' )

    Util.log( 2, 'LrObservableTableToString result: ' .. result )

    return result
end


function Util.convertLrColorToCSSColor( c )
--    Util.log( 2, 'HERE ZZ', type( c ), tostring( c ) )
--    Util.log( 2, 'HERE ZZ: ', c:type() )
--    if not c:type() == 'LrColor' then error( 'Expected an LrColor but got: ' .. c:type() ) end

    local function LrChannelToRGBChannel( x ) return math.floor( x * 255 ) end

    return 'rgb( '
            .. LrChannelToRGBChannel( c:red() )
            .. ', '
            .. LrChannelToRGBChannel( c:green() )
            .. ', '
            .. LrChannelToRGBChannel( c:blue() )
            .. ' )'
end


-- Currently only converts AgColor/LrColor objects
function Util.maybeConvertToNativeLrObject( s )
    if type( s ) == 'string' then
        if s:find( '^AgColor' ) then
            local constructor = s:gsub( 'AgColor', 'LrColor' )
            return loadstring( 'local LrColor = import "LrColor"; return ' .. constructor )()
        end
    end

    return s
end


function Util.stringToObservableTable( s, context )
    Util.log( 2, 'stringToObservableTable: ', s )
--    Debug.logStringToHex( s )

    local t = loadstring( 'return ' .. s )()

    local properties = LrBinding.makePropertyTable( context ) -- make a table

    for k, v in pairs( t ) do
        v = Util.maybeConvertToNativeLrObject( v )
        properties[ k ] = v
    end

    --Util.logpp( 0, 'LrObservableTableToString: ', Util.tableToString( properties ) )

    return properties
end


-- Split text into a list consisting of the strings in text,
-- separated by strings matching delimiter (which may be a pattern). 
-- example: strsplit(",%s*", "Anna, Bob, Charlie,Dolores")
--
-- from: http://lua-users.org/wiki/SplitJoin
function Util.splitString( delimiter, text )
    local list = {}

    Util.splitStringCallback( delimiter, text, function( str )
        table.insert( list, str )
    end )

    return list
end


-- Version of Util.splitString that calls a callback instead of assuming a table insert
function Util.splitStringCallback( delimiter, text, callback )
    local pos = 1

    if string.find( '', delimiter, 1 ) then -- this would result in endless loops
        Util.log( 2, 'delimiter matches empty string!' )
        return
    end

    while 1 do
        local first, last = string.find( text, delimiter, pos )
        if first then
            callback( string.sub( text, pos, first - 1 ) )
            pos = last + 1
        else
            callback( string.sub( text, pos ) )
            break
        end
    end
end


function Util.stringStarts( s, start )
    return string.sub( s, 1, string.len( start )) == start
end


function Util.stringEnds( s, suffix )
    return suffix == '' or string.sub( s, -string.len( suffix ) ) == suffix
end


-- From: http://www.hpelbers.org/lua/print_r
-- Copyright 2009: hans@hpelbers.org
-- This is freeware
function Util.tableToString( t, name, indent )
    local tableList = {}

    local function table_r (t, name, indent, full)
        local id = not full and name
            or type(name) ~= "number" and tostring(name) or '['..name..']'
        local tag = indent .. id .. ' = '
        local out = {}  -- result
        
        if type(t) == "table" then
            if tableList[t] ~= nil then table.insert(out, tag .. '{} -- ' .. tableList[t] .. ' (self reference)')
            else
                tableList[t]= full and (full .. '.' .. id) or id
            if next(t) then -- Table not empty
                table.insert(out, tag .. '{')
                for key,value in pairs(t) do 
                    table.insert(out,table_r(value,key,indent .. '|  ',tableList[t]))
                end
                table.insert(out,indent .. '}')
            else table.insert(out,tag .. '{}') end
            end
        else 
            local val = type(t)~="number" and type(t)~="boolean" and '"'..tostring(t)..'"' or tostring(t)
            table.insert(out, tag .. val)
        end

        return table.concat(out, "\n")
    end

    return table_r(t,name or 'Value',indent or '')
end


function Util.replaceTokens( tokenTable, str, delimiterOverrides )
    local numSubs, oldStr
    local delimiters = delimiterOverrides or { '{', '}' }

    if type( delimiters ) ~= 'table' then
        delimiters = { delimiterOverrides, delimiterOverrides }
    end

    repeat
        Util.log( 2, 'str: ', str )
        oldStr = str
        str, numSubs = str:gsub( delimiters[ 1 ] .. '(.-)' .. delimiters[ 2 ], function( token )
            Util.log( 2, 'TOKEN: ', token )
            if tokenTable[ token ] then
                return tostring( tokenTable[ token ] )
            else
                return nil -- this case allows for things wrapped in {}'s that are not meant to be tokens
            end
        end )
    until oldStr == str

    return str
end


-- This is function trim6() from http://lua-users.org/wiki/StringTrim
function Util.trim( str )
    return str:match'^()%s*$' and '' or str:match'^%s*(.*%S)'
end


function Util.quoteIfNecessary( s )
    if not s then return '' end

    if s:find ' ' and not Util.stringStarts( s, '"' ) and not Util.stringEnds( s, '"' ) then
        s = '"' .. s .. '"'
    end

    return s
end


function Util.readFileIntoString( fileName )
    local lines = Util.readFileIntoTable( fileName ) or {}

    return table.concat( lines, '\n' )
end


function Util.writeStringToFile( s, fileName )
    local result, errMsg, errNum = io.open( fileName, 'w' )
    if result == nil then
        Util.log( 0, 'ERROR: Could not open file: ' .. fileName )
        return nil, errMsg, errNum
    end

    local f = result

    result, errMsg, errNum = f:write( s )
    if result == nil then
        Util.log( 0, 'ERROR: Could not write to file: ' .. fileName )
        return nil, errMsg, errNum
    end
    result, errMsg, errNum = f:close()
    if result == nil then
        Util.log( 0, 'ERROR: Could not close file: ' .. fileName )
        return nil, errMsg, errNum
    end

    return true
end


function Util.deleteFile( path, deleteDirectory )
    -- default values
    deleteDirectory = deleteDirectory or false -- default is to not allow deleting directories (Lr allows one to delete a dir even if it has files in it)

    Util.log( 2, 'Deleting path: ' .. path )

    local result, message

    -- check for existence
    result = LrFileUtils.exists( path )
    if not result then
        return result, 'Path does not exist'
    end

    -- if exists and is directory
    if result == 'directory' then
        --  if deleteDirectory is false then fail
        if not deleteDirectory then
            return false, 'Path is a directory but the deleteDirectory option is false'
        end
    end

    -- delete path and fail if returns false
    result, message = LrFileUtils.delete( path )
    if not result then
        return result, 'ERROR: could not delete path: ' .. message
    end

    -- check for existence again and fail if it exists
    if LrFileUtils.exists( path ) then
        return false, 'ERROR: delete function succeeded but ' .. path .. ' still exists'
    end
end


function Util.createDirectory( path, failIfExists )
    -- default values
    failIfExists = failIfExists or false -- default is do not fail if it already exists. Just quietly return success.

    Util.log( 0, 'Creating directory: ' .. path )

    local result, message

    -- check for existence
    result = LrFileUtils.exists( path )
    if result then
        if result == 'file' then
            Util.log( 0, 'Already exists as a file' )
            return false, 'File already exists'
        elseif result == 'directory' then
            if failIfExists then
                Util.log( 'Already exists as a directory' )
                return false, 'Directory already exists'
            end
            -- directory exists already so just return now
            return true
        end
    end

    -- create the directory
    result, message = LrFileUtils.createAllDirectories( path )
    if result then
        Util.log( 2, 'INFO: had to create one or more parent directories' )
    end

    -- check for existence again since results of createAllDirectories is not clear
    result = LrFileUtils.exists( path )
    if not result then
        Util.log( 0, 'Failed' )
        return false, 'ERROR: could not create directory'
    end

    Util.log( 1, 'Success' )
    return true
end


function Util.splitPath( path )
    local path_table = {};

    path_table.filename = LrPathUtils.leafName( path )
    path_table.extension = LrPathUtils.extension( path )
    path_table.basename = LrPathUtils.removeExtension( path_table.filename )
    path_table.path = LrPathUtils.parent( path )

    --   return table containing volume, directories, basename, extension, list of dirs one by one?
    return path_table
end


-- At this time, destPath must be a full path with filename
function Util.copyFile( sourcePath, destPath, overwrite, createDestPath )
    -- default values
    overwrite = overwrite or false -- default is to fail if destPath already exists
    createDestPath = createDestPath or false -- default is to fail if destPath's dir does not exist

    Util.log( 0, 'Copy file from source: ' .. sourcePath )
    Util.log( 0, 'to dest: ' .. destPath )

    local result, message

    -- check that the source exists
    result = LrFileUtils.exists( sourcePath )
    if not result then
        Util.log( 0, 'ERROR: source path does not exist' )
        return false, 'Source path does not exist'
    elseif result == 'directory' then
        Util.log( 0, 'ERROR: source path is a directory, not a file' )
        return false, 'Source path is a directory, not a file'
    end

    -- check that the dest file does not exist
    result = LrFileUtils.exists( destPath )
    if result then
        if result == 'directory' then
            Util.log( 0, 'ERROR: destPath is a directory. It must have a filename as well.' )
            return false, 'destPath is a directory. It must have a filename as well.'
        elseif result == 'file' then
            if not overwrite then
                Util.log( 0, 'ERROR: dest file already exists' )
                return false, 'dest file already exists'
            end
            result, message = LrFileUtils.moveToTrash( destPath )
            if not result then
                Util.log( 0, 'ERROR: could not move existing dest file to trash' )
                return false, message
            end
        end
    end

    -- check that the dest path exists
    result = LrFileUtils.exists( LrPathUtils.parent( destPath ) )
    if not result then
        if not createDestPath then
            Util.log( 0, 'ERROR: destination directory does not exist' )
            return false, 'Destination directory does not exist'
        end
        result, message = Util.createDirectory( LrPathUtils.parent( destPath ) )
        if not result then
            Util.log( 0, 'ERROR: could not create destination directory' )
            return result, message
        end
    end

    -- copy the file
    result = LrFileUtils.copy( sourcePath, destPath )
    -- It's not clear whether the copy function will actually return nil upon failure
    if not result then
        Util.log( 0, 'ERROR: the file copy failed' )
        return false, 'copy failed'
    end

    -- check that dest exists
    result = LrFileUtils.exists( destPath )
    if not result then
        Util.log( 0, 'ERROR: Copy failed' )
        return false, 'Error when copying file'
    end

    Util.log( 1, 'success' )
    return true
end


-- Replaces html entities on the selected text
-- From: http://lua-users.org/files/wiki_insecure/users/WalterCruz/htmlentities.lua
-- if I ever need to encode these entries in decimal myself, this site has all the codes:
-- http://www.utf8-chartable.de/unicode-utf8-table.pl?utf8=dec&unicodeinhtml=dec&htmlent=1
function Util.encodeHTMLEntities( str )
    local entities = {
--        [' '] = '&nbsp;' ,
        ['¡'] = '&iexcl;' ,
        ['¢'] = '&cent;' ,
        ['£'] = '&pound;' ,
        ['¤'] = '&curren;' ,
        ['¥'] = '&yen;' ,
        ['¦'] = '&brvbar;' ,
        ['§'] = '&sect;' ,
        ['¨'] = '&uml;' ,
--        ['\194\169'] = '&copy;' ,
        ['©'] = '&copy;' ,
        ['ª'] = '&ordf;' ,
        ['«'] = '&laquo;' ,
        ['¬'] = '&not;' ,
        ['­'] = '&shy;' ,
        ['®'] = '&reg;' ,
        ['¯'] = '&macr;' ,
        ['°'] = '&deg;' ,
        ['±'] = '&plusmn;' ,
        ['²'] = '&sup2;' ,
        ['³'] = '&sup3;' ,
        ['´'] = '&acute;' ,
        ['µ'] = '&micro;' ,
        ['¶'] = '&para;' ,
        ['·'] = '&middot;' ,
        ['¸'] = '&cedil;' ,
        ['¹'] = '&sup1;' ,
        ['º'] = '&ordm;' ,
        ['»'] = '&raquo;' ,
        ['¼'] = '&frac14;' ,
        ['½'] = '&frac12;' ,
        ['¾'] = '&frac34;' ,
        ['¿'] = '&iquest;' ,
        ['À'] = '&Agrave;' ,
        ['Á'] = '&Aacute;' ,
        ['Â'] = '&Acirc;' ,
        ['Ã'] = '&Atilde;' ,
        ['Ä'] = '&Auml;' ,
        ['Å'] = '&Aring;' ,
        ['Æ'] = '&AElig;' ,
        ['Ç'] = '&Ccedil;' ,
        ['È'] = '&Egrave;' ,
        ['É'] = '&Eacute;' ,
        ['Ê'] = '&Ecirc;' ,
        ['Ë'] = '&Euml;' ,
        ['Ì'] = '&Igrave;' ,
        ['Í'] = '&Iacute;' ,
        ['Î'] = '&Icirc;' ,
        ['Ï'] = '&Iuml;' ,
        ['Ð'] = '&ETH;' ,
        ['Ñ'] = '&Ntilde;' ,
        ['Ò'] = '&Ograve;' ,
        ['Ó'] = '&Oacute;' ,
        ['Ô'] = '&Ocirc;' ,
        ['Õ'] = '&Otilde;' ,
        ['Ö'] = '&Ouml;' ,
        ['×'] = '&times;' ,
        ['Ø'] = '&Oslash;' ,
        ['Ù'] = '&Ugrave;' ,
        ['Ú'] = '&Uacute;' ,
        ['Û'] = '&Ucirc;' ,
        ['Ü'] = '&Uuml;' ,
        ['Ý'] = '&Yacute;' ,
        ['Þ'] = '&THORN;' ,
        ['ß'] = '&szlig;' ,
        ['à'] = '&agrave;' ,
        ['á'] = '&aacute;' ,
        ['â'] = '&acirc;' ,
        ['ã'] = '&atilde;' ,
        ['ä'] = '&auml;' ,
        ['å'] = '&aring;' ,
        ['æ'] = '&aelig;' ,
        ['ç'] = '&ccedil;' ,
        ['è'] = '&egrave;' ,
        ['é'] = '&eacute;' ,
        ['ê'] = '&ecirc;' ,
        ['ë'] = '&euml;' ,
        ['ì'] = '&igrave;' ,
        ['í'] = '&iacute;' ,
        ['î'] = '&icirc;' ,
        ['ï'] = '&iuml;' ,
        ['ð'] = '&eth;' ,
        ['ñ'] = '&ntilde;' ,
        ['ò'] = '&ograve;' ,
        ['ó'] = '&oacute;' ,
        ['ô'] = '&ocirc;' ,
        ['õ'] = '&otilde;' ,
        ['ö'] = '&ouml;' ,
        ['÷'] = '&divide;' ,
        ['ø'] = '&oslash;' ,
        ['ù'] = '&ugrave;' ,
        ['ú'] = '&uacute;' ,
        ['û'] = '&ucirc;' ,
        ['ü'] = '&uuml;' ,
        ['ý'] = '&yacute;' ,
        ['þ'] = '&thorn;' ,
        ['ÿ'] = '&yuml;' ,
        ['"'] = '&quot;' ,
        ["'"] = '&#39;' ,
        ['<'] = '&lt;' ,
        ['>'] = '&gt;' ,
        ['&'] = '&amp;'
    }

    return utf8.replace( str, entities )
end

--    -- Here we search for non standard characters and replace them if
--    -- we have a translation. The regexp could be changed to include an
--    -- exact list with the above characters [áéíó...] and then remove
--    -- the 'if' below, but it's easier to maintain like this...
--    return string.gsub( str, "[^a-zA-Z0-9 _]",
--        function (v)
--            if entities[v] then return entities[v] else return v end
--        end)
--end


-- From: http://lua-users.org/files/wiki_insecure/users/WalterCruz/htmlunentities.lua
function Util.decodeHTMLEntities( str )
    local entities = {
        nbsp = ' ' ,
        iexcl = '¡' ,
        cent = '¢' ,
        pound = '£' ,
        curren = '¤' ,
        yen = '¥' ,
        brvbar = '¦' ,
        sect = '§' ,
        uml = '¨' ,
        copy = '©' ,
        ordf = 'ª' ,
        laquo = '«' ,
        ['not'] = '¬' ,
        shy = '­' ,
        reg = '®' ,
        macr = '¯' ,
        ['deg'] = '°' ,
        plusmn = '±' ,
        sup2 = '²' ,
        sup3 = '³' ,
        acute = '´' ,
        micro = 'µ' ,
        para = '¶' ,
        middot = '·' ,
        cedil = '¸' ,
        sup1 = '¹' ,
        ordm = 'º' ,
        raquo = '»' ,
        frac14 = '¼' ,
        frac12 = '½' ,
        frac34 = '¾' ,
        iquest = '¿' ,
        Agrave = 'À' ,
        Aacute = 'Á' ,
        Acirc = 'Â' ,
        Atilde = 'Ã' ,
        Auml = 'Ä' ,
        Aring = 'Å' ,
        AElig = 'Æ' ,
        Ccedil = 'Ç' ,
        Egrave = 'È' ,
        Eacute = 'É' ,
        Ecirc = 'Ê' ,
        Euml = 'Ë' ,
        Igrave = 'Ì' ,
        Iacute = 'Í' ,
        Icirc = 'Î' ,
        Iuml = 'Ï' ,
        ETH = 'Ð' ,
        Ntilde = 'Ñ' ,
        Ograve = 'Ò' ,
        Oacute = 'Ó' ,
        Ocirc = 'Ô' ,
        Otilde = 'Õ' ,
        Ouml = 'Ö' ,
        times = '×' ,
        Oslash = 'Ø' ,
        Ugrave = 'Ù' ,
        Uacute = 'Ú' ,
        Ucirc = 'Û' ,
        Uuml = 'Ü' ,
        Yacute = 'Ý' ,
        THORN = 'Þ' ,
        szlig = 'ß' ,
        agrave = 'à' ,
        aacute = 'á' ,
        acirc = 'â' ,
        atilde = 'ã' ,
        auml = 'ä' ,
        aring = 'å' ,
        aelig = 'æ' ,
        ccedil = 'ç' ,
        egrave = 'è' ,
        eacute = 'é' ,
        ecirc = 'ê' ,
        euml = 'ë' ,
        igrave = 'ì' ,
        iacute = 'í' ,
        icirc = 'î' ,
        iuml = 'ï' ,
        eth = 'ð' ,
        ntilde = 'ñ' ,
        ograve = 'ò' ,
        oacute = 'ó' ,
        ocirc = 'ô' ,
        otilde = 'õ' ,
        ouml = 'ö' ,
        divide = '÷' ,
        oslash = 'ø' ,
        ugrave = 'ù' ,
        uacute = 'ú' ,
        ucirc = 'û' ,
        uuml = 'ü' ,
        yacute = 'ý' ,
        thorn = 'þ' ,
        yuml = 'ÿ' ,
        quot = '"' ,
        lt = '<' ,
        gt = '>' ,
        amp = ''
    }

    return string.gsub( str, "&%a+;",
        function ( entity )
            return entities[string.sub(entity, 2, -2)] or entity
        end)
end


function Util.grep( line, regexp )
    if string.match( line, regexp ) then return line else return nil end
end


function Util.grepv( line, regexp )
    if string.match( line, regexp ) then return nil else return line end
end


function Util.readFileIntoTable( fileName, filter )
    if not LrFileUtils.exists( fileName ) then
        Util.log( 2, 'File does not exist:', fileName )
        return nil
    end

    filter = filter or function( l ) return true end

    local t = {}
    for line in io.lines( fileName ) do
        if filter( line ) then
            table.insert( t, line )
        end
    end
    return t
end


function Util.execAndCaptureWithArgs( executable, arguments, options )
    return Util.execAndCapture( Util.quoteIfNecessary( executable ) .. ' ' .. table.concat( arguments, ' ' ), options )
end


function Util.execAndCaptureWithArgsAsync( executable, arguments, options )
    LrTasks.startAsyncTask( function()
        Util.execAndCaptureWithArgs( executable, arguments, options )
    end )
end


-- input:
--      executable: string. path/name of executable
--      arguments: table. cmd line arguments
--      options. table.
--          debug: string. if false then no debug
--          stdoutFilter: string. regex to filter out output lines
--          stderrFilter: string. regex to filter out output lines
--          stderrToStdoutFile: if true then collect stderr same file/table as stdout
--
-- output:
--      status of execute
--      table of stdout and maybe stderr lines
--      table of stderr lines depending on options

function Util.execAndCapture( cmdLine, options )
return LrFunctionContext.callWithContext( '', function( context )
    local stdoutFile, stderrFile, result

    context:addCleanupHandler( function()
        -- delete the temp output file(s)
        if stdoutFile then LrFileUtils.deleteFile( stdoutFile ) end
        if stderrFile then LrFileUtils.deleteFile( stderrFile ) end
    end )

    -- default options
    options = options or {}
    options.stderrToStdoutFile = options.stderrToStdoutFile or nil

    Util.log( 2, "Appending shell redirections" )

    local stdTempPath = LrPathUtils.getStandardFilePath( 'temp' )

    stdoutFile = LrPathUtils.child( stdTempPath, 'stdoutTemp.txt' )
    stdoutFile = LrFileUtils.chooseUniqueFileName( stdoutFile )
    cmdLine = cmdLine .. ' > ' .. stdoutFile

    if options.stderrToStdoutFile then
        cmdLine = cmdLine .. '2>&1'
    else
        stderrFile = LrPathUtils.child( stdTempPath, 'stderrTemp.txt' )
        stderrFile = LrFileUtils.chooseUniqueFileName( stderrFile )
        cmdLine = cmdLine .. ' 2> ' .. stderrFile
    end

    result = Util.exec( cmdLine )

    -- parse the output file(s)
    Util.log( 2, 'Reading output file(s)' )

    local stdoutTable = Util.readFileIntoTable( stdoutFile, options.stdoutFilter )
    local stderrTable
    if not options.stderrToStdoutFile then
        stderrTable = Util.readFileIntoTable( stderrFile, options.stderrFilter )
    end

    return result, stdoutTable, stderrTable
end )
end


function Util.exec( cmdLine )
    if not LrTasks.canYield() then
        Util.log( 0, 'Can\'t yield. Util.exec must be called within a task.' )
        return -1
    end

    if WIN_ENV then
        cmdLine = Util.quoteIfNecessary( cmdLine )
    end

    Util.log( 0, 'command line:', cmdLine )

    local result = LrTasks.execute( cmdLine )

    if result ~= 0 then
        Util.log( 0, 'result:', result )
    end

    return result
end


function Util.retryUntil( testFunc, numRetries, intervalCallback, interval )
    interval = interval or 1

    while numRetries > 0 do
        if testFunc() then
            return true
        end

        if type ( intervalCallback ) == 'function' then intervalCallback( numRetries ) end
        LrTasks.sleep( interval )
        numRetries = numRetries - 1
    end

    return false
end


return Util
