status = (texts...) ->
  console.log texts...
  $('.status').append "#{texts[0]}<br/>"

addErrorBlock = (x, y, errorClass) ->
  $('.error-blocks').append """
    <div class="error-block #{errorClass}" style="left: #{x * 8}rem; top: #{y * 8}rem;"></div>
  """

converter = null
conversionPaperStrategy = null
conversionSingleToInk = false
conversionPreserveNeighbors = null

$ ->
  console.log "START"
  conversionPaperStrategy = Converter.ConversionStrategy.LighterToPaper
  conversionPreserveNeighbors = Converter.ConversionStrategy.NeighboursNo

  $('.file-input').change ->

    # Clean up.
    $('.status').html('')
    $('.error-blocks').html('')
    $('.downloads').hide()
    $('.downloads .menu').hide()

    file = $('.file-input')[0].files[0]

    console.log "Got file", file
    console.log "Loading the file ..."

    extension = file.name.substring _.lastIndexOf(file.name, '.') + 1

    image = new Image
    image.onload = ->
      console.log "Loaded image."

      # Preview at x2 size.
      $('.image-preview').css
        width: image.width * 2
        height: image.height * 2

      status "Analyzing …"
      converter = new Converter image, file.name

    reader = new FileReader()
    reader.addEventListener 'load', ->
      console.log "Loaded file."

      switch extension
        when 'png'
          console.log "Setting to image …"
          $('.image-preview').off 'load'
          $('.image-preview').on 'load', ->
            image.src = reader.result

          $('.image-preview').attr src: reader.result

        when 'tap'
          console.log "Reading bytes …"
          tapData = new Uint8ClampedArray reader.result
          console.log tapData

          for i in [0..50]
            console.log i, String.fromCharCode(tapData[i]), tapData[i],

    switch extension
      when 'png' then reader.readAsDataURL file
      when 'tap' then reader.readAsArrayBuffer file

  $('.download-scr').click ->
    converter?.downloadScr()

  $('.download-tap').click ->
    converter?.downloadTap()

  $('.conversion-options .option').click (event) ->
    $target = $(event.target)
    $target.parent().find('.option').removeClass 'selected'
    $target.addClass 'selected'

  convert = ->
    converter?.convertIntoMemory conversionPaperStrategy, conversionSingleToInk, conversionPreserveNeighbors

  selectPaperOption = (strategy) ->
    conversionPaperStrategy = strategy
    convert()

  selectSingleToInk = (value) ->
    conversionSingleToInk = value
    convert()

  selectPreserveNeighbors = (value) ->
    conversionPreserveNeighbors = value
    convert()

  $('.darker').click -> selectPaperOption Converter.ConversionStrategy.DarkerToPaper
  $('.lighter').click -> selectPaperOption Converter.ConversionStrategy.LighterToPaper
  $('.smaller').click -> selectPaperOption Converter.ConversionStrategy.SmallerToPaper
  $('.bigger').click -> selectPaperOption Converter.ConversionStrategy.BiggerToPaper

  $('.single-ink').click -> selectSingleToInk true
  $('.single-paper').click -> selectSingleToInk false

  $('.neighbor-left').click -> selectPreserveNeighbors Converter.ConversionStrategy.NeighboursLeft
  $('.neighbor-up').click -> selectPreserveNeighbors Converter.ConversionStrategy.NeighboursUp
  $('.neighbor-no').click -> selectPreserveNeighbors Converter.ConversionStrategy.NeighboursNo
  $('.neighbor-match').click -> selectPreserveNeighbors Converter.ConversionStrategy.NeighboursMatch

class Converter
  @ConversionStrategy:
    DarkerToPaper: 'DarkerToPaper'
    LighterToPaper: 'LighterToPaper'
    BiggerToPaper: 'BiggerToPaper'
    SmallerToPaper: 'SmallerToPaper'
    NeighboursNo: 'NeighboursNo'
    NeighboursLeft: 'NeighboursLeft'
    NeighboursUp: 'NeighboursUp'
    NeighboursMatch: 'NeighboursMatch'

  constructor: (@image, @filename) ->
    @width = @image.width
    @height = @image.height
    @blockWidth = Math.ceil @width / 8
    @blockHeight = Math.ceil @height / 8

    canvas = $('<canvas>')[0]
    canvas.width = @width
    canvas.height = @height
    context = canvas.getContext '2d'
    context.drawImage @image, 0, 0
    @imageData = context.getImageData 0, 0, @width, @height
    
    screenCanvas = $('.screen')[0]
    screenContext = screenCanvas.getContext '2d'
    @screenImageData = new ImageData (new Uint8ClampedArray 256 * 192 * 4), 256, 192
    @screenImageData.data[i] = 255 for i in [0...256 * 192 * 4]

    @videoMemory = new Uint8ClampedArray 6912

    @updateScreen = =>
      screenContext.putImageData @screenImageData, 0, 0

    @updateScreen()

    @colorThreshold = 128
    @brightThreshold = 224

    # TODO: If needed we can dynamically determine thresholds.
    # @_analyzeColors()

    @_analyzeBlocks =>
      status "All checks completed!"

      $('.current-block').hide()

      unless @error
        $('.downloads').show()

        @convertIntoMemory conversionPaperStrategy, conversionSingleToInk, conversionPreserveNeighbors, =>
          console.log "Conversion finished."
          $('.downloads .menu').show()

  _analyzeColors: ->
    # Analyze the colors to determine brightness levels.
    histogram = (0 for value in [0..255])
    histogramMax = 0
    
    for value in @imageData.data
      histogram[value]++
      histogramMax = Math.max histogramMax, histogram[value]

    # Draw the histogram.

    histogramContext = $('.histogram')[0].getContext '2d'
    histogramContext.lineWidth = 1

    for value in [0..255]
      if value < @colorThreshold
        histogramContext.strokeStyle = "rgb(192,191,0)"

      else if value < @brightThreshold
        histogramContext.strokeStyle = "rgb(255,255,0)"

      else
        histogramContext.strokeStyle = "rgb(255,255,255)"

      console.log histogramContext.strokeStyle

      histogramContext.beginPath()
      histogramContext.moveTo value + 0.5, 0
      histogramContext.lineTo value + 0.5, 16
      histogramContext.stroke()

      histogramContext.beginPath()
      histogramContext.strokeStyle = "black"
      histogramContext.moveTo value + 0.5, 16
      histogramContext.lineTo value + 0.5, 16 * (1 - Math.pow(histogram[value] / histogramMax, 0.1))
      histogramContext.stroke()

    $('.histogram').show()

  _analyzeBlocks: (callback) ->
    $('.current-block').show()

    jobQueue = []

    @blockData = ([] for blockX in [0...@blockWidth])

    for blockY in [0...@blockHeight]
      for blockX in [0...@blockWidth]
        do (blockX, blockY) =>
          jobQueue.push =>
            $('.current-block').css
              left: blockX * 16
              top: blockY * 16

            colors = []
            pixels = ([] for x in [0..7])

            for x in [0...8]
              for y in [0...8]
                pixelX = blockX * 8 + x
                pixelY = blockY * 8 + y
                color = @_getPixelColor pixelX, pixelY
                colors.push color
                pixels[x][y] = color

            colors = _.uniqBy colors, (color) ->
              color.color + color.brightness * 8

            # Check for number of colors (maximum of 2).
            if colors.length > 2
              status "ERROR: #{colors.length} colors in block #{blockX}, #{blockY}.", colors
              addErrorBlock blockX, blockY, 'multiple-colors'
              @error = true

            # Check for brightness levels.
            if colors.length is 2
              if colors[0].brightness isnt colors[1].brightness
                if colors[0].color is 0 or colors[1].color is 0
                  # We're OK. Black can be converted to the other level of brightness.
                  colors[0].brightness = 1
                  colors[1].brightness = 1

                else
                  # Not OK.
                  status "ERROR: Two levels of brightness in block #{blockX}, #{blockY}.", colors
                  addErrorBlock blockX, blockY, 'multiple-brightness'
                  @error = true


            for color in colors
              color.pixelCount = 0

              for x in [0...8]
                for y in [0...8]
                  color.pixelCount++ if pixels[x][y].color is color.color

            @blockData[blockX][blockY] = {pixels, colors}

    @_processJobQueue jobQueue, callback

  convertIntoMemory: (conversionPaperStrategy, convertSingleToInk, preserveNeighbors, conversionDoneCallback) ->
    conversionPaperStrategies =
      "#{@constructor.ConversionStrategy.DarkerToPaper}": (block) => @_darkerToPaper block
      "#{@constructor.ConversionStrategy.LighterToPaper}": (block) => @_lighterToPaper block
      "#{@constructor.ConversionStrategy.SmallerToPaper}": (block) => @_smallerToPaper block
      "#{@constructor.ConversionStrategy.BiggerToPaper}": (block) => @_biggerToPaper block

    @_convertIntoMemory conversionPaperStrategies[conversionPaperStrategy], convertSingleToInk, preserveNeighbors, conversionDoneCallback

  _darkerToPaper: (block) ->
    @_colorValueComparison block, (darkerColorIndex, lighterColorIndex) =>
      paper: block.colors[darkerColorIndex].color
      ink: block.colors[lighterColorIndex].color

  _lighterToPaper: (block, preserveNeighbors) ->
    @_colorValueComparison block, (darkerColorIndex, lighterColorIndex) =>
      paper: block.colors[lighterColorIndex].color
      ink: block.colors[darkerColorIndex].color

  _colorValueComparison: (block, paperInkCallback) ->
    if block.colors.length is 1
      @_handleSingleValue block

    else
      darkerColorIndex = if block.colors[0].color < block.colors[1].color then 0 else 1
      lighterColorIndex = 1 - darkerColorIndex

      _.extend paperInkCallback(darkerColorIndex, lighterColorIndex),
        brightness: block.colors[0].brightness or block.colors[1].brightness

  _handleSingleValue: (block) ->
    paper: block.colors[0].color
    ink: block.colors[0].color
    brightness: block.colors[0].brightness

  _smallerToPaper: (block) ->
    @_areaComparison block, (smallerColorIndex, biggerColorIndex) =>
      paper: block.colors[smallerColorIndex].color
      ink: block.colors[biggerColorIndex].color

  _biggerToPaper: (block) ->
    @_areaComparison block, (smallerColorIndex, biggerColorIndex) =>
      paper: block.colors[biggerColorIndex].color
      ink: block.colors[smallerColorIndex].color

  _areaComparison: (block, paperInkCallback) ->
    if block.colors.length is 1
      @_handleSingleValue block

    else
      smallerColorIndex = if block.colors[0].pixelCount < 8 * 8 / 2 then 0 else 1
      biggerColorIndex = 1 - smallerColorIndex

      _.extend paperInkCallback(smallerColorIndex, biggerColorIndex),
        brightness: block.colors[0].brightness or block.colors[1].brightness

  _convertIntoMemory: (comparisonCallback, convertSingleToInk, preserveNeighbors, conversionDoneCallback) ->
    clearTimeout @_currentJobQueueTimeout
    jobQueue = []

    @attributeData = ([] for blockX in [0...@blockWidth])

    $('.screen-cursor').show()

    for blockY in [0...24]
      for blockX in [0...32]
        do (blockX, blockY) =>
          jobQueue.push =>
            $('.screen-cursor').css
              left: blockX * 16
              top: blockY * 16

            # Determine attribute value.
            blockData = @blockData[blockX][blockY]
            attribute = comparisonCallback blockData
            @attributeData[blockX][blockY] = attribute

            blockConvertSingleToInk = convertSingleToInk

            unless preserveNeighbors is @constructor.ConversionStrategy.NeighboursNo
              # If we have any neighbors, try to use their information instead.
              analyzeNeighbor = (neighbourX, neighbourY) =>
                neighborAttribute = @attributeData[neighbourX][neighbourY]
                videoMemoryRow = @_screenRowToVideoMemoryRow neighbourY * 8
                neighborConvertSingleToInk = @videoMemory[neighbourX + videoMemoryRow * 32] > 0

                # If the neighbor uses any of the same colors as us, try to match their selection.
                if attribute.paper is attribute.ink
                  # We're of single color. See if the neighbor was as well.
                  if neighborAttribute.paper is neighborAttribute.ink
                    # The neighbour was also single color, so we should just do what they did if our colors match.
                    blockConvertSingleToInk = neighborConvertSingleToInk if attribute.ink is neighborAttribute.ink

                  else
                    # If our color is neighbour's ink color, we should be too.
                    blockConvertSingleToInk = attribute.ink is neighborAttribute.ink

                else
                  # We have two colors and we might decide to switch our selection around.
                  doSwitch = false

                  #  See if the neighbor was single.
                  if neighborAttribute.paper is neighborAttribute.ink
                    # Are they using their color as ink?
                    if neighborConvertSingleToInk
                      # Yes! We should match our ink to theirs.
                      doSwitch = true if attribute.paper is neighborAttribute.ink

                    else
                      # No. We should match our paper to theirs.
                      doSwitch = true if attribute.ink is neighborAttribute.paper

                  else
                    # The neighbor also has two colors. We should switch so that at least one of papers or inks match.

                    doSwitch = true if attribute.paper is neighborAttribute.ink or attribute.ink is neighborAttribute.paper

                  if doSwitch
                    # Do the switch to match.
                    [attribute.paper, attribute.ink] = [attribute.ink, attribute.paper]

              if preserveNeighbors is @constructor.ConversionStrategy.NeighboursLeft
                analyzeNeighbor blockX, blockY - 1 if blockY > 0
                analyzeNeighbor blockX - 1, blockY if blockX > 0

              else if  preserveNeighbors is @constructor.ConversionStrategy.NeighboursUp
                analyzeNeighbor blockX - 1, blockY if blockX > 0
                analyzeNeighbor blockX, blockY - 1 if blockY > 0

              else
                analyzeNeighborMatch = (neighbourX, neighbourY) =>
                  neighborBlockData = @blockData[neighbourX][neighbourY]

                  match = 0

                  for color in blockData.colors
                    matchedColor = _.find neighborBlockData.colors, (neighbourColor) -> color.color is neighbourColor.color

                    if matchedColor
                      match += Math.min color.pixelCount, matchedColor.pixelCount

                  match

                leftMatch = if blockX > 0 then analyzeNeighborMatch blockX - 1, blockY else 0
                upMatch = if blockY > 0 then analyzeNeighborMatch blockX, blockY - 1 else 0

                if leftMatch > upMatch
                  analyzeNeighbor blockX, blockY - 1 if blockY > 0
                  analyzeNeighbor blockX - 1, blockY if blockX > 0

                else
                  analyzeNeighbor blockX - 1, blockY if blockX > 0
                  analyzeNeighbor blockX, blockY - 1 if blockY > 0

            attributeValue = 0
            attributeValue += attribute.brightness << 6
            attributeValue += attribute.paper << 3
            attributeValue += attribute.ink

            @videoMemory[6144 + blockX + blockY * 32] = attributeValue

            # Convert pixel data into bitmap data.
            for y in [0...8]
              rowValue = 0

              for x in [0...8]
                pixelX = blockX * 8 + x
                pixelY = blockY * 8 + y

                if blockData.colors.length is 1
                  pixelValue = if blockConvertSingleToInk then 1 else 0

                else
                  pixelValue = if blockData.pixels[x][y].color is attribute.ink then 1 else 0

                previewColor = (1 - pixelValue) * 255
                @screenImageData.data[(pixelX + pixelY * 256) * 4 + i] = previewColor for i in [0..2]

                bitIndex = 7-x
                bitValue = 1 << bitIndex
                rowValue += bitValue * pixelValue

              rowInVideoMemory = @_screenRowToVideoMemoryRow blockY * 8 + y

              @videoMemory[blockX + rowInVideoMemory * 32] = rowValue

            @updateScreen()

    @_processJobQueue jobQueue, =>
      $('.screen-cursor').hide()
      conversionDoneCallback?()

  _screenRowToVideoMemoryRow: (y) ->
    rowY = y % 8
    blockY = (y - rowY) / 8

    thirdIndex = Math.floor (blockY * 8 + rowY) / 64
    blockRowInThird = blockY % 8
    rowInBlock = rowY % 8

    thirdIndex * 64 + rowInBlock * 8 + blockRowInThird

  downloadScr: ->
    @_download [@videoMemory], 'scr'

  downloadTap: ->
    start = new Uint8ClampedArray 24

    # Length of first block (19)
    [start[0], start[1]] = @_int16to2x8 19

    # Block flag (0 means header)
    start[2] = 0

    # Header type (3 means byte block)
    start[3] = 3

    # 10-character file name
    blockName = @filename.replace '.png', ''
    for index in [0..9]
      start[4 + index] = blockName.charCodeAt(index) or 32

    # 6 custom header info values
    start[14] = 0
    start[15] = 27
    start[16] = 0
    start[17] = 64
    start[18] = 0
    start[19] = 128

    # checksum of the header (xor of all header values start[2] through start[19]
    start[20] = @_checksum start, 2, 19

    # Length of second block (video memory + flag + checksum)
    [start[21], start[22]] = @_int16to2x8 @videoMemory.length + 2

    # Block flag (255 means data)
    start[23] = 255

    end = new Uint8ClampedArray 1
    end[0] = start[23] ^ @_checksum @videoMemory

    console.log "tap", start, @videoMemory, end

    @_download [start, @videoMemory, end], 'tap'

  _int16to2x8: (integer) ->
    lowByte = integer & 0xff
    highByte = (integer & 0xff00) >> 8
    [lowByte, highByte]

  _checksum: (array, start = 0, end = array.length - 1) ->
    checksum = 0

    for value in array[start..end]
      checksum ^= value

    checksum

  _download: (binaryArrays, extension) ->
    $anchor = $('<a>')
    anchor = $anchor[0]
    anchor.href = window.URL.createObjectURL new Blob binaryArrays, type: 'application/octet-stream'
    anchor.download = @filename.replace '.png', ".#{extension}"
    $('body').append anchor
    anchor.click()
    $anchor.remove()

  _processJobQueue: (jobQueue, callback) =>
    if jobQueue.length
      job = jobQueue.shift()
      job()

      @_currentJobQueueTimeout = setTimeout =>
        @_processJobQueue jobQueue, callback
      ,
        1

    else
      callback?()

  _getPixelColor: (x, y) ->
    data = @_getPixelData x, y

    red = if data.r > @colorThreshold then 1 else 0
    green = if data.g > @colorThreshold then 1 else 0
    blue = if data.b > @colorThreshold then 1 else 0

    brightRed = if data.r > @brightThreshold then 1 else 0
    brightGreen = if data.g > @brightThreshold then 1 else 0
    brightBlue = if data.b > @brightThreshold then 1 else 0

    # Determine color.
    color = blue + red * 2 + green * 4

    # Determine brightness level.
    brightValues = [
      red + brightRed
      green + brightGreen
      blue + brightBlue
    ]

    if (1 in brightValues) and (2 in brightValues)
      status "Illegal color in pixel #{x}, #{y}."
      brightness = null

    else if (2 in brightValues)
      brightness = 1

    else
      brightness = 0

    color: color
    brightness: brightness

  _getPixelData: (x, y) ->
    offset = (x + y * @width) * 4

    r: @imageData.data[offset]
    g: @imageData.data[offset + 1]
    b: @imageData.data[offset + 2]
