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


function newReg()
    local self = {
        stdoutTable = nil
    }


--[[
-- parseRegOutput: an internal utility function that parses the output of reg.exe into a table.
--
-- Input expected to be reg.exe's stdout in a table of lines.
-- It expects the output to be in the form:
--
--  HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts
--      Arial (TrueType)    REG_SZ    arial.ttf
--      <repeat the above line 0..n times>
 ]]
    self.parseRegOutput = function( regOutput )
        local results = {}
        local pair = {}

        for _, line in ipairs( regOutput ) do
            line = Util.trim( line )
--          Util.log( 0, 'LINE', line )
            if line ~= '' and not Util.stringStarts( line, 'HKEY' ) then
                pair = Util.splitString( "%s*REG_SZ%s*" , line )
                if #pair > 2 then
                    Util.log( 0, 'ERROR: reg output not understood:', line )
                else
--                  Util.log( 0, pair[ 1 ], pair[ 2 ] )
                    results[ pair[ 1 ] ] = pair[ 2 ]
                end
            end
        end

        return results
    end
    

--[[
-- queryValue: returns the data for a given registry value. Nil if it doesn't exist.
--
-- executes the following: reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -v SystemRoot
 ]]
    self.queryValue = function( key, name )
        local args = {}
        
        table.insert( args, 'query' )
        table.insert( args, '"' .. key .. '"' )
        table.insert( args, '-v' )
        table.insert( args, name )

        local result = self.run( args )
        if result ~= 0 then
            return nil
        end
        
        local resultsTable = self.parseRegOutput( self.stdoutTable )
        return resultsTable[ name ]
    end


--[[
-- queryKey: returns all name/value pairs under a registry key in a Lua table.
--
-- executes the following: reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
 ]]
    self.queryKey = function( key )
        local args = {}
        
        table.insert( args, 'query' )
        table.insert( args, '"' .. key .. '"' )

        local result = self.run( args )
        if result ~= 0 then
            return nil
        end

        return self.parseRegOutput( self.stdoutTable )
    end


--[[
-- run: a raw wrapper around the reg.exe utility.
 ]]
    self.run = function( args, execOptions )
        Util.log( 0, "Running reg.exe" )
        Util.logpp( 0, args )

        execOptions = execOptions or {}

        local execResult, stdoutTable, stderrTable = Util.execAndCaptureWithArgs( 'reg', args, execOptions )

        Util.log( 2, "The exit status is: " .. tostring( execResult ) );
        if execResult ~= 0 then
            Util.log( 0, 'ERROR. Failed to run reg.exe. Result code: ' .. execResult )
        end
        if #stdoutTable > 0 then
--            Util.log( 0, 'STDOUT: ')
--            Util.logpp( 0, stdoutTable )
        end
        if #stderrTable > 0 then
            Util.log( 0, 'STDERR: ')
            Util.logpp( 0, stderrTable )
        end

        self.stdoutTable = stdoutTable
        return execResult
    end


    -- constructor:
    return {
        run = self.run,
        queryValue = self.queryValue,
        queryKey = self.queryKey,
    }
end
