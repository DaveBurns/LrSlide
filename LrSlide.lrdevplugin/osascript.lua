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


function newOSAScript()
    local self = {
        stdoutTable = nil
    }


    self.getStdout = function()
        return self.stdoutTable
    end


    self.run = function( args, execOptions )
        Util.log( 0, "Running OSA script" )
        Util.logpp( 0, args )

        execOptions = execOptions or {}

        local execResult, stdoutTable, stderrTable = Util.execAndCaptureWithArgs( 'osascript', args, execOptions )

        -- osascript doesn't return known exit status so don't use execResult to check for failure.
        -- The only known way to check for failure is to see if anything was written to stderr
        Util.log( 0, "The exit status is: " .. tostring( execResult ) );
        if not execResult then
            -- in case of failure, the 2nd return is a string error message
            Util.log( 0, 'ERROR: ' .. stdoutTable )
            return
        end

        if ( #stdoutTable > 0 ) then
            --            Util.log( 0, 'STDOUT: ')
            --            Util.logpp( 0, stdoutTable )
        end
        if ( #stderrTable > 0 ) then
            Util.log( 0, 'STDERR: ')
            Util.logpp( 0, stderrTable )
            Util.log( 0, 'ERROR. Failed to run osascript.' )
            return execResult
        end

        self.stdoutTable = stdoutTable
        return execResult
    end


    -- constructor:
    return {
        getStdout = self.getStdout,
        run = self.run,
    }
end
