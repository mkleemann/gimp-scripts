; Ingress banner slicer w/o gaps between slices for creating banner tiles. It uses the current image
; and, depending on the user settings, resizing it to fit the given raster. The width takes precedence
; since the banners are all 6 tiles wide. If it isn't resized, the image width is used to determine the
; raster used (width/6). The height gets cropped or extended to fit the raster depending on the given rows.

; ================= The function bodies - it's where the work is done ================

; creates a mask to show the content of the single badges when shown in the scanner application.
(define (script-fu-ingress-banner-mask inImg inRows inRaster inGapSize inGaps inRingVisible)
  (let* (
        (bannerRows inRows)
        (theRaster inRaster)
        (cntCols 6)
        (imgHeight (car (gimp-image-height inImg)))
        (imgWidth (car (gimp-image-width inImg)))
        (maskLayer 0)
        (ringLayer 0)
        )

    ; set defaults for context
    (gimp-context-push)
    (gimp-context-set-defaults)
    (gimp-image-undo-group-start inImg)
    (gimp-selection-none inImg)                         ; remove any selections
    (gimp-image-convert-rgb inImg)                      ; convert image to RGB for next oprations
    (set! maskLayer (car (gimp-layer-new inImg imgWidth imgHeight RGBA-IMAGE "Banner Mask" 95 LAYER-MODE-NORMAL)))
    (set! ringLayer (car (gimp-layer-new inImg imgWidth imgHeight RGBA-IMAGE "Ring Mask" 100 LAYER-MODE-NORMAL)))

    (gimp-image-insert-layer inImg maskLayer 0 0)       ; insert layer above all
    (gimp-layer-add-alpha maskLayer)                    ; it already should have alpha, but...
    (gimp-layer-add-alpha ringLayer)                    ; it already should have alpha, but...
    (gimp-drawable-fill maskLayer FILL-FOREGROUND)      ; fill with default foreground (black)

    ; select cut-out
    (while (> bannerRows 0)
      (begin
        (set! bannerRows (- bannerRows 1))
        (while (> cntCols 0)
          (begin
            (set! cntCols (- cntCols 1))
            (if (= inGaps TRUE)
              (begin
                (gimp-image-select-ellipse
                   inImg
                   CHANNEL-OP-ADD
                   (+ (* cntCols theRaster) (* inGapSize cntCols))
                   (+ (* bannerRows theRaster) (* inGapSize bannerRows))
                   theRaster
                   theRaster)
              )
              (begin
                (gimp-image-select-ellipse
                   inImg
                   CHANNEL-OP-ADD
                   (* cntCols theRaster)
                   (* bannerRows theRaster)
                   theRaster
                   theRaster)
              )
            )
          )
        )
        (set! cntCols 6)                                ; start over columns
      )
    )
    ; cut out the selection to create the basic mask
    (gimp-edit-cut maskLayer)

    ; now create the rings (separate layer for switching them off or on)
    (gimp-image-insert-layer inImg ringLayer 0 0)       ; insert layer above all
    (gimp-context-set-foreground '(245 167 64))         ; "golden" #F5A740
    (gimp-edit-bucket-fill ringLayer
                           BUCKET-FILL-FG
                           LAYER-MODE-NORMAL
                           100
                           0
                           FALSE
                           0
                           0)                           ; fill selection with foreground (golden)
    (gimp-selection-shrink inImg 
                           (* 8 (/ theRaster 512)))     ; shrink layer 8px@512px raster (depending on aspect ratio)
    (gimp-edit-cut ringLayer)                           ; cut inner selection of ring
    (gimp-drawable-set-visible ringLayer inRingVisible) ; set ring layer visible or not, depending on input

    (gimp-selection-none inImg)                         ; remove any selections

    ; cleanup
    (gimp-image-undo-group-end inImg)
    (gimp-displays-flush)
    (gimp-context-pop)
  )
)

; sets the guides for slicing (Note: It does not remove any previously set guides, so be careful)
(define (script-fu-ingress-banner-set-guides inImg inRows inRaster inGapSize inResizeImage inCropOrExtend inMask inGaps)
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
; **** guide functions have issues with undo stack after closing first or all images prior ****
;    ; check for already set guides and remove them
;    (if (= (car (gimp-image-find-next-guide inImg 0)) 0)
;      (begin
;        (script-fu-guides-remove RUN-NONINTERACTIVE inImg 0)
;      )
;    )
; *********************************************************************************************

    ; check image height/width if it fits to the given raster
    ; the width takes precedence, because it's always 6x raster
    ; crop/extend the bottom of the image, if it doesn't fit the raster
    (if (= inGaps TRUE)
      (begin
        (set! rasterWidth (+ rasterWidth (* inGapSize 5)))
        (set! rasterHeight (+ rasterHeight (* inGapSize (- bannerRows 1))))
        (set! resizeRatio (/ rasterWidth imgWidth))
      )
    )

    ; use raster to adjust image based on width
    (if (= resizeToFit TRUE)
      (begin
        ; resize needed
        (if (or
            (< imgWidth rasterWidth)
            (> imgWidth rasterWidth))
          (begin
            ; resizing image to fit 6x raster w/ or w/o gaps
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
            (if (= inGaps TRUE)
              (begin
                (set! theRaster (/ (- imgWidth (* inGapSize 5)) 6))
                (set! rasterWidth (+ (* inGapSize 5) (* theRaster 6)))
                (set! rasterHeight (+ (* bannerRows theRaster) (* inGapSize (- bannerRows 1))))
              )
              (begin
                (set! theRaster (/ imgWidth 6))
                (set! rasterWidth (* theRaster 6))
                (set! rasterHeight (* theRaster bannerRows))
              )
            )
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
            (if (= inGaps TRUE)
              ; w/ gaps
              (begin
                (while (> cntRows 0)
                  (if (> (+ (* cntRows theRaster) (* inGapSize (- cntRows 1))) imgHeight)
                    (begin
                      (set! cntRows (- cntRows 1))
                    )
                    (begin
                      (set! bannerRows cntRows)
                      (set! cntRows 0)
                    )
                  )
                )
                (set! imgHeight (+ (* theRaster bannerRows) (* inGapSize (- bannerRows 1))))
              )
              ; w/o gaps
              (begin
                (while (> cntRows 0)
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
                ; now crop
                (set! imgHeight (* theRaster bannerRows))
              )
            )
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
;    (gimp-message (string-append "Width: " (number->string imgWidth) " Height: " (number->string imgHeight)))

    (gimp-image-resize inImg imgWidth imgHeight 0 0)

;    (gimp-message "Resize done!")

    ; now create a mask, if necessary
    (if (= createMask TRUE)
      (begin
        (script-fu-ingress-banner-mask inImg bannerRows theRaster inGapSize inGaps FALSE)
      )
    )

    ; set guides
    (if (= inGaps TRUE)
      (begin
        ; set vertical guides
        (while (> cntGuides 0)
          (if (< cntGuides 6)
            (begin
              (gimp-image-add-vguide inImg (+ (* theRaster cntGuides) (* inGapSize cntGuides)))
            )
          )
          (gimp-image-add-vguide inImg (+ (* theRaster cntGuides) (* inGapSize (- cntGuides 1))))
          (set! cntGuides (- cntGuides 1))
        )
        ; set horizontal guides
        (while (> bannerRows 0)
          (set! bannerRows (- bannerRows 1)) ; intended to be here!
          (if (> bannerRows 0)               ; we don't need a guide at 0
            (begin
              (gimp-image-add-hguide inImg (+ (* theRaster bannerRows) (* inGapSize (- bannerRows 1))))
              (gimp-image-add-hguide inImg (+ (* theRaster bannerRows) (* inGapSize bannerRows)))
            )
          )
        )
      )
      (begin
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
      )
    )

    ; cleanup
    (gimp-image-undo-group-end inImg)
    (gimp-displays-flush)
    (gimp-context-pop)
  )
)

; the actual slicing and saving of the slices as png files
(define (script-fu-ingress-slicer inImg inBName inDir inGaps)
  (let*
    (
    (slices (cadr (plug-in-guillotine RUN-NONINTERACTIVE inImg 0))) ; list of created slices
    (curSlice 0)
    (curIdx 0)
    (numOfSlices (vector-length slices))
    (rows (/ numOfSlices 11))
    (imgIdx 0)
    (rowIdx 0)
    (numOfImg numOfSlices)
    (fileName inBName)
    (padding "")
    (numOfDigits 0)
    (curImgNum 0)
    (padIdx 0)
    )
    ; get the number of images we want to keep, if gaps are present
    (if (= inGaps TRUE)
      (begin
        (set! numOfImg (* (/ (+ rows 1) 2) 6))
      )
    )

    ; slice is done, now create files
    (while (> numOfSlices curIdx)
      (set! curSlice (vector-ref slices curIdx))
      (if (= inGaps TRUE)
        (begin
          (if (and (even? curIdx) (even? rowIdx))
            (begin
              (set! curImgNum (- numOfImg imgIdx))                            ; the current number of the image
              (set! numOfDigits (string-length (number->string curImgNum)))   ; the current number of digits the image number has
              (set! padding "")                                               ; set it to default again
              ; add padding acc. to the max and current digits
              (set! padIdx (- (string-length (number->string numOfImg)) numOfDigits))

              (while (> padIdx 0)                                             ; add padding as far as needed
                (set! padding (string-append "0" padding))
                (set! padIdx (- padIdx 1))
              )

              (set! fileName (string-append inDir "/" inBName "-" padding (number->string curImgNum) ".png"))
              (gimp-image-flatten curSlice)
              (file-png-save-defaults RUN-NONINTERACTIVE curSlice (car (gimp-image-get-active-drawable curSlice)) fileName fileName)
              (set! imgIdx (+ imgIdx 1))
            )
          )
          (set! curIdx (+ curIdx 1))
          (if (= (modulo curIdx 11) 0)
            (begin
              (set! rowIdx (+ rowIdx 1)) ; next row
            )
          )
        )
        (begin
          (set! curImgNum (- numOfSlices curIdx))                             ; the current number of the image
          (set! numOfDigits (string-length (number->string curImgNum)))       ; the current number of digits the image number has
          (set! padding "")                                                   ; set it to default again
          ; add padding acc. to the max and current digits
          (set! padIdx (- (string-length (number->string numOfImg)) numOfDigits))

          (while (> padIdx 0)                                                 ; add padding as far as needed
            (set! padding (string-append "0" padding))
            (set! padIdx (- padIdx 1))
          )

          (set! fileName (string-append inDir "/" inBName "-" padding (number->string curImgNum) ".png"))
          (gimp-image-flatten curSlice)
          (file-png-save-defaults RUN-NONINTERACTIVE curSlice (car (gimp-image-get-active-drawable curSlice)) fileName fileName)
          (set! curIdx (+ curIdx 1))
        )
      )
      (gimp-image-delete curSlice)
    )
  )
)

; calls the functions to set guides and to slice in one command
(define (script-fu-ingress-banner-slice inImg inRows inRaster inGapSize inResize inCrop inMask inGaps inBName inDir)
  (let*
    (
    )
    ; prepare for slicing
    (script-fu-ingress-banner-set-guides inImg inRows inRaster inGapSize inResize inCrop inMask inGaps)
    ; slice!
    (script-fu-ingress-slicer inImg inBName inDir inGaps)
  )
)

; creates an new (empty) image the size, depending on raster and rows, and provides a fitting banner mask to work with.
(define (script-fu-ingress-empty-image-with-mask inRows inRaster inGapSize inGaps inRingVisible)
  (let*
    (
    (theImageWidth (* inRaster 6))
    (theImageHeight (* inRows inRaster))
    (theImage 0)
    )
    (if (= inGaps TRUE)
      (begin
        (set! theImageWidth (+ theImageWidth (* inGapSize 5)))
        (set! theImageHeight (+ theImageHeight (* inGapSize (- inRows 1))))
      )
    )
    (set! theImage (car (gimp-image-new theImageWidth theImageHeight RGB)))
    ; now show the empty image with no layers
    (gimp-display-new theImage)
    ; create banner mask
    (script-fu-ingress-banner-mask theImage inRows inRaster inGapSize inGaps inRingVisible)
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
  SF-ADJUSTMENT   "Gap size"        '(32 1 100 1 5 0 1)        ; the gap size, default 32 (new scanner)
  SF-TOGGLE       "With gaps"       TRUE                       ; creates gaps between slices
  SF-TOGGLE       "Rings visible"   FALSE                      ; select visibility of ring layer
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
  "RGB* GRAY* INDEXED*"                                        ; image type the script works on
  SF-IMAGE        "Current Image"   0                          ; the source image
  SF-ADJUSTMENT   "Number of Rows"  '(1 1 100 1 10 0 1)        ; number selection for # of rows
  SF-ADJUSTMENT   "Tile Raster"     '(512 500 1024 1 12 0 1)   ; the raster, default 512x512px
  SF-ADJUSTMENT   "Gap size"        '(32 1 100 1 5 0 1)        ; the gap size, default 32 (new scanner)
  SF-TOGGLE       "With gaps"       FALSE                      ; creates gaps between slices
  SF-TOGGLE       "Rings visible"   FALSE                      ; select visibility of ring layer
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
  "RGB* GRAY* INDEXED*"                                        ; image type the script works on
  SF-IMAGE        "Current Image"   0                          ; the source image
  SF-ADJUSTMENT   "Number of Rows"  '(1 1 100 1 10 0 1)        ; number selection for # of rows
  SF-ADJUSTMENT   "Tile Raster"     '(512 500 1024 1 12 0 1)   ; the raster, default 512x512px
  SF-ADJUSTMENT   "Gap size"        '(32 1 100 1 5 0 1)        ; the gap size, default 32 (new scanner)
  SF-TOGGLE       "Scale image to fit raster"  FALSE           ; scale image if it doesn't fit
  SF-TOGGLE       "[x] Crop/[ ] Extend height to fit"  FALSE   ; crop or extend image at the bottom
  SF-TOGGLE       "Create Banner Mask" FALSE                   ; creates a banner mask
  SF-TOGGLE       "With gaps"       FALSE                      ; creates gaps between slices
)

(script-fu-register
  "script-fu-ingress-slicer"                                   ; function name
  "Slice Only"                                                 ; menu label
  "Slices an image with guides and saves the slices."          ; description
  "999up"                                                      ; author
  "copyright 2022, 999up <dev@layer128.net>"                   ; copyright notice
  "30.03.2022"                                                 ; creation date
  "RGB* GRAY* INDEXED*"                                        ; image type the script works on
  SF-IMAGE        "Current Image"   0                          ; the source image
  SF-STRING       "Slice basename"  "bannername"               ; basename for slice files
  SF-DIRNAME      "Save in..."      gimp-data-directory        ; storage directory
  SF-TOGGLE       "With gaps"       FALSE                      ; creates gaps between slices
)

(script-fu-register
  "script-fu-ingress-banner-slice"                             ; function name
  "Banner Setup and Slicer"                                    ; menu label
  "Creates guides, slices an image and saves\
   the slices using the given name and a counter.\
   If necessary it crops or extends the image to\
   fit the raster, depending on user settings."                ; description
  "999up"                                                      ; author
  "copyright 2022, 999up <dev@layer128.net>"                   ; copyright notice
  "30.03.2022"                                                 ; creation date
  "RGB* GRAY* INDEXED*"                                        ; image type the script works on
  SF-IMAGE        "Current Image"   0                          ; the source image
  SF-ADJUSTMENT   "Number of Rows"  '(1 1 100 1 10 0 1)        ; number selection for # of rows
  SF-ADJUSTMENT   "Tile Raster"     '(512 500 1024 1 12 0 1)   ; the raster, default 512x512px
  SF-ADJUSTMENT   "Gap size"        '(32 1 100 1 5 0 1)        ; the gap size, default 32 (new scanner)
  SF-TOGGLE       "Scale image to fit raster"  FALSE           ; scale image if it doesn't fit
  SF-TOGGLE       "[x] Crop/[ ] Extend height to fit"  FALSE   ; crop or extend image at the bottom
  SF-TOGGLE       "Create Banner Mask" FALSE                   ; creates a banner mask
  SF-TOGGLE       "With gaps"       TRUE                       ; creates gaps between slices
  SF-STRING       "Slice basename"  "bannername"               ; basename for slice files
  SF-DIRNAME      "Save in..."      gimp-data-directory        ; storage directory
)

; ================ What and where to show in the GIMP menus ==============

; register at Tools/Ingress menu
(script-fu-menu-register "script-fu-ingress-banner-set-guides" "<Image>/Tools/Ingress")
(script-fu-menu-register "script-fu-ingress-empty-image-with-mask" "<Image>/Tools/Ingress")
(script-fu-menu-register "script-fu-ingress-banner-slice" "<Image>/Tools/Ingress")
(script-fu-menu-register "script-fu-ingress-slicer" "<Image>/Tools/Ingress")

; ---- Test only ----
;(script-fu-menu-register "script-fu-ingress-banner-mask" "<Image>/Tools/Ingress")
