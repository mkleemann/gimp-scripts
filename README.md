# GIMP scripts

Here you can find my excursions into the world of Script-Fu (or GIMP Scheme). The repository may
or may not increase, but I'll show-off some of the stuff I did.

## Ingress Banner Slicer

Never heard of [Ingress](https://ingress.com)? This script may not for you. But who knows, it might
be of use for slicing images into rows of 6 tiles with or without gaps between. The intention is to
prepare images for [Ingress](https://ingress.com) mission banners, the favorite way to do missions,
to show in your agent profile within the scanner app. An overview of already created banners can be
found at [Bannergress](https://bannergress.com).

The script comes with (currently) 4 functions, located in __Tools/Ingress__.
* Banner Setup and Slicer
* Create Empty Image with Mask
* Set Banner Guides
* Slice Only

### Banner Setup and Slicer
This is the whole stuff, preparing the current image for slicing and doing the slice including storage
of the tiles as numbered files. The numbering follows the intended use during mission creation, so 1 is
the bottom right tile and the last one the top left one.

Since all other commands follow the same options, the overall description is this:

* Number of Rows
  * Specifies the number of rows the image gets. If you choose _crop_ option, this is ignored when exceeding image height.
* Tile Raster
  * Specifies the size of the tiles (both height and width)
* Gap Size
  * Size of the gaps between tiles (vertical and horizontal) in px, when choosing the _with gaps_ option.
* Scale image to fit raster
  * The image may to large/small to fit the choosen raster including possible gaps. It will be resized to match that with precedence on width. Aspect ratio will be preserved.
* Crop/Extend height to fit
  * Crops the height at the maximum number of complete rows or extends the image with partly filled and/or empty tiles on the bottom meeting the set number of rows.
* Create Banner Mask
  * Since the tiles are shown as round images in the scanner app, it provides a mask to show what it would look like in your profile.
* With gaps
  * Choose gaps between the tiles. The default of 28px meets the usually used value for the current scanner app.
* Slice basename
  * Name used for saving the tiles as file with the scheme _basename-#_.
* Save in...
  * The directory to store the tile files in.

### Create Empty Image With Mask
This simply creates an empty image, the size reflecting the setup in raster and gaps, and adds a banner mask
layer to it. This can be used to start work on your individual banner.

### Set Banner Guides
For slicing the image, guides are used in GIMP. This is to create them according to your setup, including
rescaling of your image, if chosen.

__ATTENTION__: Remove all guides set prior, if you want to slice using this script. An automatic removal is
not possible at this time, since the built-in functions of GIMP (2.10) mess with undo stack doing so. Especially
when using gaps you need to only use guides provided by this script.

### Slice Only
It slices the image using the guides set in _Set Banner Guides_ and stores the tiles into separate files
according to the naming scheme described above.

Have fun!
