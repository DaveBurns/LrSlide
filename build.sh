#!/usr/bin/env bash

BUILD_NUMBER='build-number'
BASEDIR='/Users/Dave/projects/LrSlide/'
SRC_DIR=$BASEDIR'LrSlide.lrdevplugin'
BUILD_DIR=$BASEDIR'/build/LrSlide.lrplugin'
LUAC='/usr/local/bin/luac'
ZIP='/usr/bin/zip'

cd $BASEDIR

mkdir -p $BUILD_DIR

rm -rf $BUILD_DIR/*

cp -r $SRC_DIR/* $BUILD_DIR
# Remove any files that shouldn't be distributed
rm -f $BUILD_DIR/fontCache.txt
rm -f $BUILD_DIR/debug.log
rm -f $BUILD_DIR/Lightroom\ Plugin.iml


version_raw=`cat $BUILD_NUMBER`
OIFS=$IFS
IFS='.'
version=($version_raw)
major=${version[0]}
minor=${version[1]}
revision=${version[2]}
IFS=$OIFS

if [[ $1 == "major" ]]; then
    major=`expr $major + 1`
    minor='0'
    revision='0'
elif [[ $1 == "minor" ]]; then
    minor=`expr $minor + 1`
    revision='0'
else
    revision=`expr $revision + 1`
fi

BUILDDATE=`date "+%Y-%m-%d"`
DISPLAYVERSION="\'$major.$minor.$revision.$BUILDDATE\'"
VERSIONLINE="VERSION = { major = $major, minor = $minor, revision = $revision, display = $DISPLAYVERSION },"
cat $SRC_DIR/Info.lua | sed -e "s/VERSION = .*$/$VERSIONLINE/" > $BUILD_DIR/Info.lua


cd $BUILD_DIR

# uncomment to compile and obfuscate Lua source code
#for file in *.lua
#do
#    $LUAC -o ${file}c $file
#    rm -f $file
#done

cd ..
zip -r "LrSlide_v$major.$minor.$revision.zip" LrSlide.lrplugin

cd ..
echo "$major.$minor.$revision" > $BUILD_NUMBER
