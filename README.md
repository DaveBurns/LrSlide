# LrSlide

LrSlide is a plugin for Adobe Lightroom that adds the ability to generate text slides.
I wrote LrSlide because I frequently make presentations using Lightroom and I was tired of
making text slides in PhotoShop.

**I consider this project to be 'beta' software until I hear more people have used it
without issues. If you find issues, the best way to help is to file a bug here or just
send an email to lrslide at dave burns photo dot com.**

## Features

With a simple dialog box, LrSlide lets you enter text, choose a font and size,
background and text colors, and do some simple aligning left, right, or center.
When you're done, LrSlide renders a JPEG version of your slide and adds it to your
Lightroom catalog. You can later edit that slide to make changes.

LrSlide lets you enter simple text with no markup. For more interesting text, LrSlide
supports a form of markup called Markdown. For advanced users, you can insert HTML
directly into your text.

## System Requirements

LrSlide renders slides as JPEGs using Google Chrome. **You must have Google Chrome installed
on your machine for LrSlide to work.**

I have tested this with Lightroom Classic CC on both Mac 10.13 (High Sierra) and Windows 10.

## How to Install

For now, because it's beta and because it's not clear how much interest there is,
LrSlide is not packaged. You'll need to download the code from GitHub. GitHub supplies
a convenient link to download the latest code in a ZIP file:
https://github.com/DaveBurns/LrSlide/archive/master.zip

## How to Use

LrSlide adds three menu options under **Library -> Plug-in Extras -> LrSlide**:

#### Add Slide...

This adds a new slide. Enter your text, choose your formatting options, and choose
**Add Slide**. You should see your slide inserted into your Lightroom catalog.

#### Edit Slide...

This edits an existing slide. Change the contents or formatting of your slide
and choose **Edit Slide**. Your selected slide will now reflect your changes
(but see Known Issues below for why this may not be immediate).

#### Re-render selected slides

If you present at different venues that have different projectors or screen
resolutions, you may want to rerender your slides to match so that there is no
pixelation in your text.
By default, LrSlide generates slides with pixel dimensions 1024 x 768.
Enter a new pixel size in Lightroom's Plug-in Manager and then choose this feature.
This regenerates all selected LrSlides.

It does not show a dialog box but does show a progress bar in the top left of Lightroom's window. 

#### Text Formatting

LrSlide offers three different ways to format the contents of your slide.
You can mix and match these in a single slide:

1. **Plain text.** This is the simplest but least powerful. Simply enter text
in the dialog box without any markup or annotation. All text will be the same
font size that you choose in the dialog's dropdown menu.

2. **Markdown.** This tries to strike a balance between simplicity and power.
You can use simple things like \*\*bold\*\* to make text **bold**. There are 
too many features to list here. See https://daringfireball.net/projects/markdown/syntax
for the official doc or https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet 
for a concise cheatsheet.

3. **HTML.** You can enter HTML directly if you know what you're doing. LrSlide
makes no effort to check that your HTML is correctly formed.

#### Plug-in Manager

You can set some global options for LrSlide using **File -> Plug-in Manager...**
then choosing **LrSlide** in the left panel.

There is an **Advanced Settings** section on the right.
If your version of Google Chrome is not installed in a standard location, you
can tell LrSlide where to find it here. Enter a path in the text field or use
the **Browse...** button to find it. Leave this field blank to have LrSlide look
for Chrome in standard install paths.

There is also a **Delete font cache** button. LrSlide rescans your system's fonts
once per week but you can force it to rescan immediately by using this button and
then choosing either Add or Edit.

There is a **Size of Slides** section on the right. Enter the width and height
in pixels that you would like your slides to be rendered in JPEGs. This size
does not affect existing slides - only newly created ones. To change the size
of existing slides, select them and use the **Re-render selected slides** feature.

## Known Issues

- Lightroom does not give plug-in authors a way to update images displayed in
Library mode. If you edit an existing slide, Lightroom does not show the changes
immediately. You need to "poke" Lightroom to get it to know there were changes.
Usually all that's needed is to select another image then select your slide
again - an easy left/right with the arrow keys for instance.

## Ideas for Future Enhancements
- Allow a background image with some alpha transparency.
- Allow the ability to insert images.
- Add the ability to choose different slide templates, including user-supplied HTML and/or CSS files.
