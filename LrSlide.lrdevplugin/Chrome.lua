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

local LrErrors = import 'LrErrors'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'

local Util = require 'Util'


function newChrome( path )
    local self = {
        binPath = nil,
        version = nil,
    }


    self.findInstallPath = function()
        local possiblePaths

        if WIN_ENV then
            possiblePaths = {
                [[C:\Program Files (x86)\Google\Chrome\Application\chrome.exe]],
                [[C:\Program Files (x86)\Google\Application\chrome.exe]],
            }
        else
            possiblePaths = {
                [[/Applications/Google Chrome.app/Contents/MacOS/Google Chrome]],
            }
        end

        for _, path in ipairs( possiblePaths ) do
            if LrFileUtils.exists( path ) == 'file' then
                return path
            end
        end

        return nil
    end


    self.getVersion = function()
        -- TODO: Chrome's --version option doesn't seem to work on Windows so punt for now.
        -- Two possibilities in the future:
        -- 1) Use WMI to extract the version resource from the binary like so:
        --    wmic datafile where name="c:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe" get version /value
        -- 2) Or, the Chrome install seems to have a directory next to chrome.exe
        --    that is named for the version. So, find the binary then list the peer
        --    directories looking for #.#.#.#. Seems more fragile than the first option.
        if WIN_ENV then
            return self.version
        end

        if not self.version then
            local versionString = '0.0.0.0'

            local versionGrepper = function()
                return function( line )
                    if line:match( 'Google Chrome' ) then
                        versionString = line
                    end
                    return false
                end
            end

            local args = {}
            table.insert( args, '--version' )
            local result, errorMessage = self.run( args, { stdoutFilter = versionGrepper() } )

            local o1, o2, o3, o4 = versionString:match( '(%d+)%.(%d+)%.(%d+)%.(%d+)' )
            local versionTable = {}
            versionTable.major = tonumber( o1 )
            versionTable.minor = tonumber( o2 )
            versionTable.build = tonumber( o3 )
            versionTable.patch = tonumber( o4 )
            versionTable.asString = versionString
            Util.log( 2, versionString )
            Util.logpp( 2, versionTable )

            self.version = versionTable
        end

        return self.version
    end


    self.renderHTMLtoFile = function( html, width, height, outputFilename )
    return LrFunctionContext.callWithContext( '', function( context )
        local htmlFile

        context:addCleanupHandler( function()
            -- delete the temp HTML file
            if htmlFile then LrFileUtils.deleteFile( htmlFile ) end
        end )

        Util.logpp( 2, 'Value of self: ', self )

        local args = {}
        table.insert( args, '--headless' )
        table.insert( args, '--disable-gpu' )
        table.insert( args, '--hide-scrollbars' )
        table.insert( args, '--crash-dumps-dir=/tmp' )  -- BUG WORKAROUND: https://bugs.chromium.org/p/chromium/issues/detail?id=772920
        table.insert( args, '--screenshot=' .. outputFilename )
        table.insert( args, '--window-size=' .. width .. ',' .. height )

        -- write HTML to temp file because there's no way to pipe a string directly to Chrome

        local stdTempPath = LrPathUtils.getStandardFilePath( 'temp' )
        htmlFile = LrPathUtils.child( stdTempPath, 'LrSlide-tempHTML.html' )
        htmlFile = LrFileUtils.chooseUniqueFileName( htmlFile )
        Util.log( 2, "htmlFile: " .. htmlFile );
        if Util.writeStringToFile( html, htmlFile ) == nil then
            LrErrors.throwUserError( 'Could not write HTML to temp file: ' .. htmlFile )
        end

        table.insert( args, 'file://' .. htmlFile )

        Util.log( 2, 'Launching Chrome to render...' )
        Util.log( 2, 'HTML: ', html )

        local JSConsoleOut = {}
        local result, msg = self.run( args, {
            -- Collect any JS console output
            --captureJSConsole = function( l ) table.insert( JSConsoleOut, l ) end,
            --  Filter out useless info line written to stderr
            stderrFilter = function( l ) return Util.grepv( l, 'Written to file' ) end
        } )
        Util.logpp( 2, 'JAVASCRIPT OUTPUT:', JSConsoleOut )

        if result ~= 0 then
            LrErrors.throwUserError( msg )
        end

    end )
    end


    self.run = function( args, options )
        if not self.binPath then
            return 1, 'Could not find where Chrome is installed.'
        end

        if options.captureJSConsole then
            table.insert( args, '--enable-logging' )  -- must enable this and user-data-dir to see JavaScript console in stderr
            table.insert( args, '--user-data-dir=foo' )
        end

        Util.log( 0, 'Running Chrome', self.toString() )
        Util.logpp( 0, args )

        local execResult, stdoutTable, stderrTable = Util.execAndCaptureWithArgs( self.binPath, args, options )
        local errorMessage

        Util.log( 2, 'The result is: ' .. execResult )
        if execResult ~= 0 then
            Util.log( 0, 'ERROR. Failed to run Chrome. Result code: ' .. execResult )
        end
        if #stdoutTable > 0 then
            Util.logpp( 0, 'STDOUT:', stdoutTable )
        end
        if #stderrTable > 0 then
            Util.logpp( 0, 'STDERR:', stderrTable )

            -- Chrome outputs a success message to stderr so only save the message if the result code indicates error
            if not execResult == 0 then
                errorMessage = stderrTable[ 1 ]
            end

            if options.captureJSConsole then
                for _, line in ipairs( stderrTable ) do
                    -- an example of what we need to match and extract from:
                    -- [1219/163812.580191:INFO:CONSOLE(46)] \"HELLO\", source: file:///var/folders/cz/1nn7x9_11n3025158fkjfm_h0000gn/T/LrSlide-tempHTML.html (46)
                    local out = line:match( [["(.*)"]] )
                    if out then
                        options.captureJSConsole( out )
                    end
                end
            end
        end

        return execResult, errorMessage
    end


    self.toString = function()
        return ( self.version and self.version[ 'asString' ] or 'Unknown version ' ) ..
               ( self.binPath and self.binPath or 'Unknown path' )
    end


    -- constructor:
    self.binPath = ( type( path ) == 'string' and string.len( path) > 0 ) and path or self.findInstallPath()
    self.version = self.getVersion()

    return {
        getVersion = self.getVersion,
        renderHTMLtoFile = self.renderHTMLtoFile,
        run = self.run,
    }
end
