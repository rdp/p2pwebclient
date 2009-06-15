


class BlockManager
  def getSingleByteOverall(byte)
    block, offset = calculateBlockAndOffset(byte)
    return @allBlocks[block].getByte(offset)
  end
  
  def fileNameForSize(size)
    assert size >= 1000 # we use K here :)
    return BlockManager.fileNameForSizeStorageDirectory + "/#{size/1000}K.file"
  end
  
  def BlockManager.createOneVeryBig
        Dir.mkPath BlockManager.fileNameForSizeStorageDirectory # just in case :)
         createWithSize(BlockManager.fileNameForSizeStorageDirectory + "30000K.file", 30_000_000)
   end

  
  def BlockManager.createAllBig
    Dir.mkPath BlockManager.fileNameForSizeStorageDirectory # just in case :)
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "25K.file", 25000)
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "50K.file", 50000)
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "100K.file", 100000)
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "200K.file", 100000)
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "500K.file", 500000)
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "1000K.file", 1000000)
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "1001K.file", 1000000)
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "10000K.file", 10000000)
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "100000K.file", 100000000) # 100 MB
    createWithSize(BlockManager.fileNameForSizeStorageDirectory + "1000000K.file", 1000000000) # 1 GB
  end
  
  def BlockManager.createWithSize(filename, size)
    logger = Logger.new('test/bmtestlog.txt', 0)
    a = BlockManager.new('http://fake/url', 0, 0, 0, 100_000, 0, 0, 0, 'peer name', 1, 'run name', 256000, 10, 10, OpenDHTEM)

    # ltodo we reuse the above name a lot...
    a.setFileSize(size)
    a.propagateWithData false
    a.writeToFile(filename)
  end
  
  
  def BlockManager.testFileFillCreateSave(fileSize)
    assert false, "undone"
    logger = Logger.new('test/bmtestlog.txt', 0)
    openDHT = OpenDHTWrapper.new('http://fake/url', logger)
    
    b = BlockManager.new('http://fake/url', 32, logger, openDHT)
    b.setFileSize(fileSize)
    0.upto(fileSize - 1) { |n|
      b.addDataOverall("b", n, false)
    }
    
    b.writeToFile("test/testblockoutput.bin")
    readTester = File.new("test/testblockoutput.bin", "r")
    assert readTester.stat.size == fileSize
    0.upto(fileSize-1) { |n|
      charIn = readTester.getc
      assert  charIn == "b"[0]
    }
    readTester.close
    
  end
  
  def BlockManager.testSelf
    assert false, "BlockManager.testSelf isn't here yet"
    # ltodo add these in
    logger = Logger.new('test/bmtestlog.txt', 0)
    openDHT = OpenDHTWrapper.new('http://fake/url', logger)
    a = BlockManager.new('http://fake/url', 32, logger, openDHT)
    a.setFileSize(100)
    a.addDataOverall("abc", 0)
    assert(!a.done?)
    3.upto(99) { |n|
      a.addDataOverall("a", n, false)
    }
    assert a.done?
    assert a.getSingleByteOverall(0) == "a"[0]
    assert a.getSingleByteOverall(2) == "c"[0]
    assert(!a.fileIsCorrect?)
    testFileFillCreateSave(1)
    testFileFillCreateSave(32)
    testFileFillCreateSave(200)
    testFileFillCreateSave(500)
    testFileFillCreateSave(1111)
    c = BlockManager.new('http://fake/url', 3200, logger, openDHT)
    BlockManager.timeSelf
    mediumSize = 10000
    # now save an existing, load to another, should be correct
    c.setFileSize(mediumSize)
    c.readFromFileOrPropagateAndSave
    assert c.fileIsCorrect?
    
    saveTo = "test/block_man_out.txt"
    c.writeToFile(saveTo)
    d = BlockManager.new('http://fake/url', 3200, logger, openDHT)
    d.setFileSize(mediumSize)
    d.loadFromFile(saveTo)
    assert d.fileIsCorrect?
    
    filename = "test/auto_create_test"
    BlockManager.createWithSize(filename, 1010)
    e = BlockManager.new('http://fake/url', 3200, logger, openDHT)
    e.setFileSize(1010)
    e.loadFromFile(filename)
    assert e.fileIsCorrect?
  end
  
  def BlockManager.timeSelf
    assert false, "undone"
    logger = Logger.new('test/bmtestlog.txt', 0)
    openDHT = OpenDHTWrapper.new('http://fake/url', logger)
    c = BlockManager.new('http://fake/url', 3200, logger, openDHT)
    bigSize = 50000
    c.setFileSize(bigSize)
    c.readFromFileOrPropagateAndSave
    assert c.fileIsCorrect?
  end
  
  def BlockManager.fileNameForSizeStorageDirectory
    return "../" + Socket.gethostname + "/large_files/"
  end

  def writeToFile(filename)
    a = File.new(filename, "wb")
    for block in @allBlocks
      block.writeToFileObject(a)
      if not block.done?
        @logger.error "ack after an undone block we quit writing to file"
        a.close
        return false
      end
    end
    a.close
  end
  
  def loadFromFile(filename)
    startTime = Time.new
    debug "begin load from file #{filename}"
    fileIn = File.new(filename, "r")
    assert fileIn.stat.size == wholeFileSize
    whereAt = 0
    while stringIn = fileIn.read(1000)
      addDataOverall(stringIn, whereAt, false)
      whereAt += stringIn.length
    end
    fileIn.close
    debug "end load from file #{filename} took #{Time.new - startTime} seconds"
  end
  
  def readFromFileOrPropagateAndSave()
    Dir.mkPath BlockManager.fileNameForSizeStorageDirectory # just in case :)
    filename = fileNameForSize(wholeFileSize())
    if File.exist? filename
      loadFromFile filename
      assertEqual @totalNumBytesInFile, @totalBytesWritten, "ack delete #{filename} it was an aborted creation" # ltodo change fixnumexclusive to just fixnumnormal
    else
      @logger.debug "propagating then saving!!!"
      propagateWithData false
      writeToFile filename
    end
    
  end
  
  # ltodo some line somewhere say "print asked block..."
  
  def propagateWithData(report = true)
    fileSize = @totalNumBytesInFile
    debug "begin propagate size #{fileSize}"
    numberLengthInFile = 10 # to have variable sized blocks...egh :) ltodo  make this func cooler? like 'abc' over-written with it, mb? or longer, with a unique string?
    assert((fileSize/numberLengthInFile).to_i * numberLengthInFile) == fileSize
    toAddFormatString = "%0#{numberLengthInFile}d"
    for n in 0..(fileSize/numberLengthInFile - 1)
      toAdd = toAddFormatString % n
      addDataOverall(toAdd, n * numberLengthInFile, report)
      
    end
    debug "end propagate"
  end
  def BlockManager.verifyChunk(largeChunk, whereStart, logger)
    # if it is 13, we want it to round up to 20 with a position of 7, a number of 2
    #
    
    extraAtBeginning = whereStart % 10 # 3
    if extraAtBeginning > 0
      whereAtWithinChunk = 10 - extraAtBeginning # 7
    else
      whereAtWithinChunk = 0
    end
    numberToCompareWith = (whereStart + whereAtWithinChunk)/10 # 2
    success = true
    # ltodo the fringes -- they..<gulp> should be checked too (later)
    while whereAtWithinChunk < largeChunk.length - 1
      actualShouldBe = "%010d" % [numberToCompareWith]
      ourSlice = largeChunk[whereAtWithinChunk..whereAtWithinChunk + 9]
      if ourSlice.length < 10 # the end chunk :) ltodo beginning chunk
        actualShouldBe = actualShouldBe[0..(ourSlice.length() -1)]
      end
      if actualShouldBe != ourSlice
        logger.error "SEEDO ACK downloaded #{ourSlice} != #{actualShouldBe} (expected for 10X chunk #{numberToCompareWith})!!!"
        success = false
        return false # TODO this bug :)
      end
      whereAtWithinChunk += 10
      numberToCompareWith += 1
    end
    return success
  end
  
  def fileIsCorrect? # ltodo turn off for large files or split up or turn off for production
    return true if @already_finalized # nao adianta
    if !done?
      @logger.error("FILE NOT DONE when asked if it is correct!")
      correct = false
    end
    @logger.debug "begin verify size #{wholeFileSize}"
    startTime = Time.new
    correct = true
    for block in @allBlocks
      if not block.validData?
        @logger.error "NOO! invalid block! #{block}"
        correct = false
      end
    end
    endTime = Time.new
    @logger.debug "file verify => #{correct}! size #{wholeFileSize} time elapsed: #{endTime - startTime}S"
    return correct
  end
   
  
end



