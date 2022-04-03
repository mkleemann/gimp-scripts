; Ingress banner slicer w/o gaps between slices for creating banner tiles. It uses the current image
; and, depending on the user settings, resizing it to fit the given raster. The width takes precedence
; since the banners are all 6 tiles wide. If it isn't resized, the image width is used to determine the
; raster used (width/6). The height gets cropped or extended to fit the raster depending on the given rows.

; ================= The function bodies - it's where the work is done ================

; creates a mask to show the content of the single badges when shown in the scanner application.
(define (script-fu-ingress-banner-mask inImg inRows inRaster)
  (let* (
        (bannerRows inRows)
        (theRaster inRaster)
        (cntCols 6)
        (imgHeight (car (gimp-image-height inImg)))
        (imgWidth (car (gimp-image-width inImg)))
        (maskLayer (car (gimp-layer-new inImg imgWidth imgHeight RGBA-IMAGE "Banner Mask" 95 LAYER-MODE-NORMAL)))
        )
    ; set defaults for context
    (gimp-context-push)
    (gimp-context-set-defaults)
    (gimp-image-undo-group-start inImg)
    (gimp-selection-none inImg) ; remove any selections

    (gimp-image-insert-layer inImg maskLayer 0 0)       ; insert layer above all
    (gimp-layer-add-alpha maskLayer)                    ; it already should have alpha, but...
    (gimp-drawable-fill maskLayer FILL-FOREGROUND)      ; fill with default foreground (black)

    ; select cut-out
    (while (> bannerRows 0)
      (begin
        (set! bannerRows (- bannerRows 1))
        (while (> cntCols 0)
          (begin
            (set! cntCols (- cntCols 1))
            (gimp-image-select-ellipse
              inImg
              CHANNEL-OP-ADD
              (* cntCols theRaster)
              (* bannerRows theRaster)
              theRaster
              theRaster)
          )
        )
        (set! cntCols 6)                                ; start over columns
      )
    )
    ; cut out the selection
    (gimp-edit-cut maskLayer)
    (gimp-selection-none inImg) ; remove any selections

    ; cleanup
    (gimp-image-undo-group-end inImg)
    (gimp-displays-flush)
    (gimp-context-pop)
  )
)

; sets the guides for slicing (Note: It does not remove any previously set guides, so be careful)
(define (script-fu-ingress-banner-set-guides inImg inRows inRaster inResizeImage inCropOrExtend inMask)
  (let* (
        (bannerRows inRows)
        (theRaster inRaster)
        (resizeToFit inResizeImage)
        (cropImg inCropOrExtend)
        (createMask inMask)
        (imgHeight (car (gimp-image-height inImg)))
        (imgWidth (car (gimp-image-width inImg)))
        (rasterWidth (* theRaster 6))
        (rasterHeight (* theRaster bannerRows))
        (resizeRatio (/ rasterWidth imgWidth))
        (cntGuides 5)
        (cntRows bannerRows)
        )

    ; set defaults for context
    (gimp-context-push)
    (gimp-context-set-defaults)
    (gimp-image-undo-group-start inImg)
    (gimp-selection-none inImg) ; remove any selections
    ; setup for scaling
    (gimp-context-set-transform-direction TRANSFORM-FORWARD)
    (gimp-context-set-interpolation INTERPOLATION-CUBIC)
    (gimp-context-set-transform-resize TRANSFORM-RESIZE-ADJUST)
    ;(script-fu-guides-remove RUN-NONINTERACTIVE inImg 0) ; remove any old guides - has issues with closeall!

    ; check image height/width if it fits to the given raster
    ; the width takes precedence, because it's always 6x raster
    ; crop/extend the bottom of the image, if it doesn't fit the raster

    ; use raster to adjust image based on width
    (if (= resizeToFit TRUE)
      (begin
        ; resize needed
        (if (or
            (< imgWidth rasterWidth)
            (> imgWidth rasterWidth))
          (begin
            ; resizing image to fit 6x raster
            (set! imgWidth rasterWidth)
            (set! imgHeight (* resizeRatio imgHeight))
            (gimp-image-scale inImg imgWidth imgHeight)
            (gimp-displays-flush)
          )
        )
      )
      (begin
        ; adjust raster to fit width (ignore set raster)
        (if (< imgWidth rasterWidth)
          (begin
            ; use image width to determine new raster size
            (set! theRaster (/ imgWidth 6))
            (set! rasterWidth (* theRaster 6))
            (set! rasterHeight (* theRaster bannerRows))
          )
        )
        ; use the raster as set and add a vertical guide (image larger than 6x raster width)
        (if (> imgWidth rasterWidth)
          (begin
            (set! cntGuides (+ cntGuides 1))
            (set! imgWidth rasterWidth)
          )
        )
      )
    )
    ; check if height fits and crop/extend is need
    (if (< imgHeight rasterHeight)
      ; image needs extension or cropped to one row less
      (begin
        (if (= cropImg TRUE)
          ; crop
          (begin
            ; determine how many tiles fit into height
            (while (> cntRows 0)
              (begin
                (if (> (* cntRows theRaster) imgHeight)
                  (begin
                    (set! cntRows (- cntRows 1))
                  )
                  (begin
                    (set! bannerRows cntRows)
                    (set! cntRows 0)
                  )
                )
              )
            )
            ; now crop
            (set! imgHeight (* theRaster bannerRows))
          )
          ; extend
          (begin
            (set! imgHeight rasterHeight)
          )
        )
      )
    )
    (if (> imgHeight rasterHeight)
      ; image needs cropping, regardless of user choice
      (begin
        (set! imgHeight rasterHeight)
      )
    )
    (gimp-image-resize inImg imgWidth imgHeight 0 0)

    ; now create a mask, if necessary
    (if (= createMask TRUE)
      (begin
        (script-fu-ingress-banner-mask inImg bannerRows theRaster)
      )
    )

    ; set vertical guides
    (while (> cntGuides 0)
       (gimp-image-add-vguide inImg (* theRaster cntGuides))
       (set! cntGuides (- cntGuides 1))
    )
    ; set horizontal guides
    (while (> bannerRows 0)
       (set! bannerRows (- bannerRows 1)) ; intended to be here!
       (if (> bannerRows 0)               ; we don't need a guide at 0
         (begin
           (gimp-image-add-hguide inImg (* theRaster bannerRows))
         )
       )
    )

    ; cleanup
    (gimp-image-undo-group-end inImg)
    (gimp-displays-flush)
    (gimp-context-pop)
  )
)

; the actual slicing and saving of the slices as png files
(define (script-fu-ingress-slicer inImg inBName inDir)
  (let*
    (
    (slices (cadr (plug-in-guillotine RUN-NONINTERACTIVE inImg 0))) ; list of created slices
    (curSlice 0)
    (curIdx 0)
    (numOfSlices (vector-length slices))
    (fileName inBName)
    )
    ; slice is done, now create files
    (while (> numOfSlices curIdx)
      (set! curSlice (vector-ref slices curIdx))
      (set! fileName (string-append inDir "/" inBName "-" (number->string (- numOfSlices curIdx)) ".png"))
      (gimp-image-flatten curSlice)
      (file-png-save-defaults RUN-NONINTERACTIVE curSlice (car (gimp-image-get-active-drawable curSlice)) fileName fileName)
      (gimp-image-delete curSlice)
      (set! curIdx (+ curIdx 1))
    )
  )
)

; calls the functions to set guides and to slice in one command
(define (script-fu-ingress-banner-slice inImg inRows inRaster inResize inCrop inMask inBName inDir)
  (let*
    (
    )
    ; prepare for slicing
    (script-fu-ingress-banner-set-guides inImg inRows inRaster inResize inCrop inMask)
    ; slice!
    (script-fu-ingress-slicer inImg inBName inDir)
  )
)

; creates an new (empty) image the size, depending on raster and rows, and provides a fitting banner mask to work with.
(define (script-fu-ingress-empty-image-with-mask inRows inRaster)
  (let*
    (
    (theImageWidth (* inRaster 6))
    (theImageHeight (* inRows inRaster))
    (theImage (car (gimp-image-new theImageWidth theImageHeight RGB)))
    )
    ; now show the empty image with no layers
    (gimp-display-new theImage)
    ; create banner mask
    (script-fu-ingress-banner-mask theImage inRows inRaster)
  )
)

; ============== registration of functions =================

; register function with GIMP
(script-fu-register
  "script-fu-ingress-empty-image-with-mask"                    ; function name
  "Create Empty Image with Mask"                               ; menu label
  "Creates an empty image with a banner mask to be filled\
   with the content of choice."                                ; description
  "999up"                                                      ; author
  "copyright 2022, 999up <dev@layer128.net>"                   ; copyright notice
  "31.03.2022"                                                 ; creation date
  ""                                                           ; image type the script works on
  SF-ADJUSTMENT   "Number of Rows"  '(1 1 100 1 10 0 1)        ; number selection for # of rows
  SF-ADJUSTMENT   "Tile Raster"     '(512 500 1024 1 12 0 1)   ; the raster, default 512x512px
)

(script-fu-register
  "script-fu-ingress-banner-mask"                              ; function name
  "Create Banner Mask"                                         ; menu label
  "Creates guides to the Ingress banner base image.\
   If necessary it crops or extends the image to\
   fit the raster, depending on user settings."                ; description
  "999up"                                                      ; author
  "copyright 2022, 999up <dev@layer128.net>"                   ; copyright notice
  "31.03.2022"                                                 ; creation date
  "RGB*"                                                       ; image type the script works on
  SF-IMAGE        "Current Image"   0                          ; the source image
  SF-ADJUSTMENT   "Number of Rows"  '(1 1 100 1 10 0 1)        ; number selection for # of rows
  SF-ADJUSTMENT   "Tile Raster"     '(512 500 1024 1 12 0 1)   ; the raster, default 512x512px
)

(script-fu-register
  "script-fu-ingress-banner-set-guides"                        ; function name
  "Set Banner Guides"                                          ; menu label
  "Creates guides to the Ingress banner base image.\
   If necessary it crops or extends the image to\
   fit the raster, depending on user settings."                ; description
  "999up"                                                      ; author
  "copyright 2022, 999up <dev@layer128.net>"                   ; copyright notice
  "31.03.2022"                                                 ; creation date
  "RGB*"                                                       ; image type the script works on
  SF-IMAGE        "Current Image"   0                          ; the source image
  SF-ADJUSTMENT   "Number of Rows"  '(1 1 100 1 10 0 1)        ; number selection for # of rows
  SF-ADJUSTMENT   "Tile Raster"     '(512 500 1024 1 12 0 1)   ; the raster, default 512x512px
  SF-TOGGLE       "Scale image to fit raster"  FALSE           ; scale image if it doesn't fit
  SF-TOGGLE       "[x] Crop/[ ] Extend height to fit"  FALSE   ; crop or extend image at the bottom
  SF-TOGGLE       "Create Banner Mask" FALSE                   ; creates a banner mask
)

(script-fu-register
  "script-fu-ingress-slicer"                                   ; function name
  "Ingress Slicer"                                             ; menu label
  "Slices an image with guides and saves the slices."          ; description
  "999up"                                                      ; author
  "copyright 2022, 999up <dev@layer128.net>"                   ; copyright notice
  "30.03.2022"                                                 ; creation date
  "RGB*"                                                       ; image type the script works on
  SF-IMAGE        "Current Image"   0                          ; the source image
  SF-STRING       "Slice basename"  "bannername"               ; basename for slice files
  SF-DIRNAME      "Save in..."      gimp-data-directory        ; storage directory
)

(script-fu-register
  "script-fu-ingress-banner-slice"                             ; function name
  "Banner Slicer"                                              ; menu label
  "Creates guides, slices an image and saves\
   the slices using the given name and a counter.\
   If necessary it crops or extends the image to\
   fit the raster, depending on user settings."                ; description
  "999up"                                                      ; author
  "copyright 2022, 999up <dev@layer128.net>"                   ; copyright notice
  "30.03.2022"                                                 ; creation date
  "RGB*"                                                       ; image type the script works on
  SF-IMAGE        "Current Image"   0                          ; the source image
  SF-ADJUSTMENT   "Number of Rows"  '(1 1 100 1 10 0 1)        ; number selection for # of rows
  SF-ADJUSTMENT   "Tile Raster"     '(512 500 1024 1 12 0 1)   ; the raster, default 512x512px
  SF-TOGGLE       "Scale image to fit raster"  FALSE           ; scale image if it doesn't fit
  SF-TOGGLE       "[x] Crop/[ ] Extend height to fit"  FALSE   ; crop or extend image at the bottom
  SF-TOGGLE       "Create Banner Mask" FALSE                   ; creates a banner mask
  SF-STRING       "Slice basename"  "bannername"               ; basename for slice files
  SF-DIRNAME      "Save in..."      gimp-data-directory        ; storage directory
)

; ================ What and where to show in the GIMP menus ==============

; register at Tools/Ingress menu
(script-fu-menu-register "script-fu-ingress-banner-set-guides" "<Image>/Tools/Ingress")
(script-fu-menu-register "script-fu-ingress-empty-image-with-mask" "<Image>/Tools/Ingress")
(script-fu-menu-register "script-fu-ingress-banner-slice" "<Image>/Tools/Ingress")

; ---- Test only ----
;(script-fu-menu-register "script-fu-ingress-banner-mask" "<Image>/Tools/Ingress")
;(script-fu-menu-register "script-fu-ingress-slicer" "<Image>/Tools/Ingress")
