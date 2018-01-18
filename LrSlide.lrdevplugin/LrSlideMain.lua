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

local LrApplication = import 'LrApplication'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrErrors = import 'LrErrors'

local Util = require 'Util'
require 'LrSlideDialog'
require 'LrSlideGenerate'

local mode


local function readMetadata( photo )
    --    Util.log( 0, 'before getting attributes' )
    local serializedTable = photo:getPropertyForPlugin( _PLUGIN, 'LrSlideAttributes' )
    --    Util.log( 0, 'raw metadata: ' .. serializedTable )
    return serializedTable
end


local function writeMetadata( catalog, photo, serializedTable, context )
    local result = catalog:withPrivateWriteAccessDo(
        function( context )
            --            Util.log( 0, 'before write internal: ' .. serializedTable )
            photo:setPropertyForPlugin( _PLUGIN, 'LrSlideAttributes', serializedTable )
            --            Util.log( 0, 'after write internal')
        end,
        {
            timeout = 0.1,
            callback = function()
                Util.log( 0, 'timed out. write access abandoned.' )
            end
        }
    )
    Util.log( 0, 'writeMetadata: result = ' .. result )
end


local function getActiveSource( catalog )
    local activeSources = catalog:getActiveSources()
    Util.logpp( 2, 'ACTIVE SOURCES:', activeSources )
    local activeSource = activeSources[ 1 ]
    local source_type = activeSource.type and activeSource:type()
    Util.log( 2, source_type )

    return activeSource, source_type
end


local function determinePathToNewSlide( catalog, source, source_type )
    -- first see if there is a selected photo and if so, return its path plus a new slide's file name
    local photo = catalog:getTargetPhoto()
    local path
    if photo then
        path = photo:getRawMetadata( 'path' )
        path = LrPathUtils.parent( path )
        path = LrPathUtils.child( path, 'LrSlide.jpg' )
        path = LrFileUtils.chooseUniqueFileName( path )
        Util.log( 0, 'Path based on existing selected photo: ' .. path )
        return path
    end

    -- if no selected photo, infer a path from the current source.
    if source_type == 'LrFolder' then
        path = source:getPath()
        path = LrPathUtils.child( path, 'LrSlide.jpg' )
        path = LrFileUtils.chooseUniqueFileName( path )
        Util.log( 0, 'Path based on source folder: ' .. path )
        return path
    elseif source_type == 'LrCollection' or source_type == 'LrPublishedCollection' then
        path = LrPathUtils.getStandardFilePath( 'pictures' )
        path = LrPathUtils.child( path, 'LrSlide.jpg' )
        path = LrFileUtils.chooseUniqueFileName( path )
        Util.log( 0, 'Path based on source ' .. source_type .. ': ' .. path )
        return path
    end

    LrErrors.throwUserError( "LrSlide can't determine where the new slide will go. To solve, either:\n1) Select an existing image and the slide will go in that path.\n2) Select a folder from the Folders panel on the left." )
end


local function readLrSlidePrefs()
    local prefs = LrPrefs.prefsForPlugin()
    Util.logpp( 2, prefs )

    local config = {}
    config.chromePath = prefs.chromePath or ''
    config.slideWidth = prefs.slideWidth or 1024
    config.slideHeight = prefs.slideHeight or 768

    Util.logpp( 0, config )
    return config
end


local function getListOfAllLrSlidesInSelection( catalog )
    local myPluginId = 'com.daveburnsphoto.lightroom.LrSlide'

    local allSlides = catalog:findPhotosWithProperty( myPluginId, 'LrSlideAttributes' )
    local selectedPhotos = catalog:getTargetPhotos()
    local slidesInSelection = {}

    Util.log( 0, 'Number of LrSlides in catalog: ' .. #allSlides )
    Util.log( 0, 'Number of selected photos: ' .. #selectedPhotos )

    for _, slide in ipairs( allSlides ) do
        for _, selectedSlide in ipairs( selectedPhotos ) do
            --            Util.log( 0, 'selectedSlide: ' .. selectedSlide.localIdentifier .. ', allSlides: ' .. slide.localIdentifier )
            if selectedSlide.localIdentifier == slide.localIdentifier then
                --                Util.log( 0, 'WE HAVE A MATCH, #slidesInSelection: ' .. #slidesInSelection )
                slidesInSelection[ #slidesInSelection + 1 ] = selectedSlide
            end
        end
    end

    Util.log( 0, 'Number of LrSlides in selection: ' .. #slidesInSelection )

    return slidesInSelection
end


local function getSlideProperties( mode, slide, context )
    if mode == 'add' then
        return LrBinding.makePropertyTable( context )
    end

    local serializedTable = readMetadata( slide )
    if serializedTable == nil then
        LrErrors.throwUserError( 'Current picture is not an LrSlide.' )
    end

    local properties = Util.stringToObservableTable( serializedTable, context )
    Util.log( 0, 'Properties: ' .. Util.tableToString( properties ) )

    return properties
end


local function renderSlide( config, properties, slide_path, width, height )
    local slideGenerator = newSlideGenerator( config )
    slideGenerator.setFont( properties.font )
    slideGenerator.setStyles( properties )
    slideGenerator.setSize( width, height )
    slideGenerator.setText( properties.text )
    slideGenerator.render( slide_path )
end


local function addNewSlideToCatalog( catalog, slide_path, source, source_type )
    local slide

    if not LrTasks.pcall( Debug.showErrors( function()
        catalog:withWriteAccessDo(
            'Add Slide', -- Text that appears in the Undo menu option
            function()
                slide = catalog:addPhoto( slide_path )

                -- If user is adding a slide while viewing a collection, assume that they want it added to the collection
                if source_type == 'LrCollection' or source_type == 'LrPublishedCollection' then
                    local photos = {}
                    table.insert( photos, slide )
                    source:addPhotos( photos )
                end
            end)
    end )
    ) then
        LrErrors.throwUserError( 'Could not add the new slide to the catalog.' )
    end

    return slide
end


local function updateCatalogWithNewProperties( catalog, slide, properties, context )
    Util.log( 2, 'before convert to string' )
    properties.text = properties.text:gsub( '\10', '\\n' ) -- persist linefeeds as \n's so Lua will interpret correctly when reading back in
    properties.text = properties.text:gsub( '"',   '\\"' ) -- escape double-quotes since these are part of serializing to a string
    local serializedTable = Util.LrObservableTableToString( properties, { [ 'mode' ] = mode } )
    writeMetadata( catalog, slide, serializedTable, context )
    Util.log( 0, 'Saved slide metadata: ', serializedTable )
    catalog:setSelectedPhotos( slide, {} )
end


------------------------------------------------------------------------------


local function addSlide( config, catalog, context )
    local source, source_type = getActiveSource( catalog )
    local slide_path = determinePathToNewSlide( catalog, source, source_type )
    local properties = getSlideProperties( mode, nil, context )
    if newSlideDialog().run( properties, 'add', context ) then
        renderSlide( config, properties, slide_path, config.slideWidth, config.slideHeight )
        local slide = addNewSlideToCatalog( catalog, slide_path, source, source_type )
        updateCatalogWithNewProperties( catalog, slide, properties, context )
    end

    return true
end


local function editSlide( config, catalog, context )
    -- if editing, make sure there's a selected photo to edit.
    local slide = catalog:getTargetPhoto()
    if slide == nil then
        LrErrors.throwUserError( 'No slide selected for editing.' )
    end

    local slide_path = slide:getRawMetadata( 'path' )
    local properties = getSlideProperties( mode, slide, context )
    if newSlideDialog().run( properties, 'edit', context ) then
        -- Both 'add' and 'rerender' use the width/height set in the plugin properties
        -- but here we want to preserve the slide's current size
        local width = slide:getRawMetadata( 'width' )
        local height = slide:getRawMetadata( 'height' )
        renderSlide( config, properties, slide_path, width, height )
        updateCatalogWithNewProperties( catalog, slide, properties, context )
    end

    return true
end


local function rerenderSlides( config, catalog, context )
    local slides = getListOfAllLrSlidesInSelection( catalog )
    local errors = {}

    for _, slide in ipairs( slides ) do
        local result, errorMessage = LrTasks.pcall( function()
            local slide_path = slide:getRawMetadata( 'path' )
            local properties = getSlideProperties( mode, slide, context )
            renderSlide( config, properties, slide_path, config.slideWidth, config.slideHeight )
            updateCatalogWithNewProperties( catalog, slide, properties, context )
        end )
        if not result then
            table.insert( errors, errorMessage )
        end
    end

    if #errors > 0 then
        LrErrors.throwUserError( Util.tableToString( errors, 'Errors' ) )
    end

    return true
end


local function LrSlideMain( context )
    Util.log( 0, '********* LrSlide MAIN. Mode: ' .. mode )

    Util.log( 2, 'Can I yield? ' .. tostring( LrTasks.canYield() ) )

    local config = readLrSlidePrefs()
    local catalog = LrApplication.activeCatalog()
    local actionFunction

    if mode == 'add' then
        actionFunction = addSlide
    elseif mode == 'edit' then
        actionFunction = editSlide
    elseif mode == 'rerender' then
        actionFunction = rerenderSlides
    else
        LrErrors.throwUserError( 'Internal error. Unknown mode: ' .. mode )
    end

    local result, errorMessage = actionFunction( config, catalog, context )
    if result then
        Util.log( 0, 'Completed with success:', mode, 'mode.' )
    else
        Util.log( 0, 'Completed with failure:', mode, 'mode. Error is: ', errorMessage )
        LrErrors.throwUserError( errorMessage )
    end
end


function LrSlideBootstrap( menu_mode )
    Util.log( 0, '********* LrSlide BOOTSTRAP ************' )
    mode = menu_mode
    LrFunctionContext.postAsyncTaskWithContext( 'LrSlideMain', Debug.showErrors ( LrSlideMain ) )
end
