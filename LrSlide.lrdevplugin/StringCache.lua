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

local LrFileUtils = import 'LrFileUtils'
local LrDate = import 'LrDate'
local Util = require 'Util'



function newStringCache( fileName, ttlInHours )
    local self = {
        cacheFileName = fileName,
        ttlInSeconds = ( ttlInHours or 24 ) * 60 * 60,
        cacheFilePath = _PLUGIN.path .. '/' .. fileName
    }


    self.put = function( str )
        Util.log( 0, 'Putting string to cache file: ', self.cacheFileName )

        -- Test if the cache file exists
        if ( LrFileUtils.exists( self.cacheFilePath ) ) then
            Util.log( 0, 'StringCache: file exists: ' .. self.cacheFilePath )

            -- yes so delete it. Failure is fatal
            local result, message = LrFileUtils.delete( self.cacheFilePath )
            if not result then
                Util.log( 0, 'ERROR: could not delete cache file: ', self.cacheFilePath, message )
                return nil
            end
        end

        -- write the file
        local file, msg, errno, result

        file, msg, errno = io.open( self.cacheFilePath, 'w' )
        if not file then
            Util.log( 0, 'ERROR: could not open cache file for writing.', msg, errno )
            return nil
        end

        result, msg, errno = file:write( str )
        if not result then
            Util.log( 0, 'ERROR: could not write to cache file.', msg, errno )
            return nil
        end

        file:close()

        return true
    end


    self.get = function()
        Util.log( 0, 'Getting string from cache file: ', self.cacheFileName )

        -- Test that the cache file exists
        local exists = LrFileUtils.exists( self.cacheFilePath )
        if ( not exists ) then
            Util.log( 0, 'StringCache: file does not exist: ' .. self.cacheFilePath )
            return nil
        end

        -- Test that the cache file has not expired. If it has, delete it.
        local currentTime = LrDate.currentTime()
        local attr = LrFileUtils.fileAttributes( self.cacheFilePath )
        -- are we expired?
        if currentTime - attr.fileModificationDate > self.ttlInSeconds then
            Util.log( 0, 'StringCache: ' .. self.cacheFileName .. ' expired so deleting.' )
            self.delete( self.cacheFilePath )
            return nil
        end

        -- read the file
        return LrFileUtils.readFile( self.cacheFilePath )
    end


    self.delete = function()
        Util.log( 0, 'Deleting cache file: ', self.cacheFileName )

        -- failure is non-fatal
        local result, message = LrFileUtils.delete( self.cacheFilePath )
        if not result then
            Util.log( 0, 'ERROR: could not delete cache file: ', self.cacheFilePath, message )
        end
    end


    return {
        put = self.put,
        get = self.get,
        delete = self.delete,
    }
end
