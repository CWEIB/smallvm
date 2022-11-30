// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// Copyright 2019 John Maloney, Bernat Romagosa, and Jens Mönig

// MicroBlocksEditor.gp - Top-level window for the MicroBlocks IDE
// John Maloney, January, 2018

to startup { openMicroBlocksEditor } // run at startup if not in interactive mode

to uload fileName {
  // Reload a top level module file when working on MicroBlocks. The 'lib/' prefix and '.gp'
  // suffix can be omitted. Example: "reload 'List'"

  if (not (endsWith fileName '.gp')) { fileName = (join fileName '.gp') }
  if (contains (listFiles '../ide') fileName) {
	fileName = (join '../ide/' fileName)
  } (contains (listFiles 'ide') fileName) {
	fileName = (join 'ide/' fileName)
  } else {
	fileName = (join '../gp/runtime/lib/' fileName)
  }
  return (load fileName (topLevelModule))
}

defineClass MicroBlocksEditor morph fileName scripter leftItems title rightItems tipBar zoomButtons indicator progressIndicator lastStatus httpServer lastProjectFolder lastScriptPicFolder boardLibAutoLoadDisabled autoDecompile frameRate frameCount lastFrameTime newerVersion putNextDroppedFileOnBoard isDownloading

method fileName MicroBlocksEditor { return fileName }
method project MicroBlocksEditor { return (project scripter) }
method scripter MicroBlocksEditor { return scripter }
method httpServer MicroBlocksEditor { return httpServer }
method lastScriptPicFolder MicroBlocksEditor { return lastScriptPicFolder }
method setLastScriptPicFolder MicroBlocksEditor dir { lastScriptPicFolder = dir }

to openMicroBlocksEditor devMode {
  if (isNil devMode) { devMode = false }
  page = (newPage 1000 600)
  setDevMode page devMode
  toggleMorphicMenu (hand page) (contains (commandLine) '--allowMorphMenu')
  setGlobal 'page' page
  tryRetina = true
  open page tryRetina 'MicroBlocks'
  editor = (initialize (new 'MicroBlocksEditor') (emptyProject))
  addPart page editor
  redrawAll (global 'page')
  readVersionFile (smallRuntime)
  applyUserPreferences editor
  pageResized editor
  developerModeChanged editor
  if ('Browser' == (platform)) {
    // attempt to extra project or scripts from URL; does nothing if absent
    importFromURL editor (browserURL)
  }
  startSteppingSafely page
}

to findMicroBlocksEditor {
  page = (global 'page')
  if (notNil page) {
	for p (parts (morph page)) {
	  if (isClass (handler p) 'MicroBlocksEditor') { return (handler p) }
	}
  }
  return nil
}

method initialize MicroBlocksEditor {
  scale = (global 'scale')
  morph = (newMorph this)
  httpServer = (newMicroBlocksHTTPServer)
  addTopBarParts this
  scripter = (initialize (new 'MicroBlocksScripter') this)
  lastProjectFolder = 'Examples'
  addPart morph (morph scripter)
  addTipBar this
  addZoomButtons this
  clearProject this
  fixLayout this
  setFPS morph 200
  newerVersion = 'unknown'
  putNextDroppedFileOnBoard = false
  return this
}

method scaleChanged MicroBlocksEditor {
  // Called when the window resolution changes.

  removeHint (global 'page')
  removeAllParts morph
  addTopBarParts this
  addTipBar this
  addZoomButtons this

  // save the state of the current scripter
  if (2 == (global 'scale')) { oldScale = 1 } else { oldScale = 2 }
  saveScripts scripter (oldScale * (global 'blockScale'))
  oldProject = (project scripter)
  oldCategory = (currentCategory scripter)
  oldLibrary = (currentLibrary scripter)

  // make a new scripter and restore old scripter state
  scripter = (initialize (new 'MicroBlocksScripter') this)
  setProject scripter oldProject
  updateLibraryList scripter
  if (notNil oldCategory) { selectCategory scripter oldCategory }
  if (notNil oldLibrary) { selectLibrary scripter oldLibrary }
  languageChanged scripter
  sendStopAll (smallRuntime)
  initialize (smallRuntime) scripter

  lastStatus = nil // force update
  addPart morph (morph scripter)
  fixLayout this
}

// top bar parts

method addTopBarParts MicroBlocksEditor {
  scale = (global 'scale')

  leftItems = (list)
  add leftItems (140 * scale)
  add leftItems (addIconButton this (languageButtonIcon this) 'languageMenu' 'Language')
  add leftItems (addIconButton this (settingsButtonIcon this) 'settingsMenu' 'MicroBlocks')
  add leftItems (addIconButton this (projectButtonIcon this) 'projectMenu' 'File')
  add leftItems (addIconButton this (graphIcon this) 'showGraph' 'Graph')
  add leftItems (addIconButton this (connectButtonIcon this) 'connectToBoard' 'Connect')
  indicator = (last leftItems)

  if (isNil title) {
    // only add the logo and title the first time
    addLogo this
    title = (newText '' 'Arial' (17 * scale))
    addPart morph (morph title)
  }

  rightItems = (list)

  addFrameRate = (contains (commandLine) '--allowMorphMenu')
  if addFrameRate {
	frameRate = (newText '0 fps' 'Arial' (14 * scale))
	addPart morph (morph frameRate)
	add rightItems frameRate
	add rightItems (16 * scale)
  }

  add rightItems (addIconButton this (newBitmap 0 0) 'noop' 'Progress' 36)
  progressIndicator = (last rightItems)
  add rightItems (3 * scale)

  add rightItems (addIconButton this (startButtonIcon this) 'startAll' 'Start' 36)
  add rightItems (addIconButton this (stopButtonIcon this) 'stopAndSyncScripts' 'Stop' 36)
  add rightItems (7 * scale)
}

method addLogo MicroBlocksEditor {
  logoM = (newMorph)
  setCostume logoM (logoAndText this)
  setPosition logoM 0 0
  addPart morph logoM
}

method textButton MicroBlocksEditor label selector {
  label = (localized label)
  scale = (global 'scale')
  setFont 'Arial Bold' (16 * scale)
  if ('Linux' == (platform)) { setFont 'Arial Bold' (13 * scale) }
  w = ((stringWidth label) + (10 * scale))
  h = (41 * scale)
  labelY = (12 * scale)
  bm1 = (newBitmap w h (topBarBlue this))
  drawString bm1 label (gray 60) (5 * scale) labelY
  bm2 = (newBitmap w h (topBarBlueHighlight this))
  drawString bm2 label (gray 40) (5 * scale) labelY
  button = (newButton '' (action selector this))
  setCostumes button bm1 bm2
  addPart morph (morph button)
  return button
}

// zoom buttons
method addZoomButtons MicroBlocksEditor {
  zoomButtons = (array
	(newZoomButton this 'zoomOut' 'Decrease block size')
	(newZoomButton this 'restoreZoom' 'Restore block size to 100%')
	(newZoomButton this 'zoomIn' 'Increase block size'))
  for button zoomButtons {
	addPart morph (morph button)
  }
  fixZoomButtonsLayout this
}

method newZoomButton MicroBlocksEditor selector hint {
  scale = (global 'scale')
  icon = (call (action (join selector 'Icon') this))
  w = (30 * scale)
  h = (30 * scale)
  x = (half (w - (width icon)))
  y = (5 * scale)
  bm1 = (newBitmap w h (transparent))
  drawBitmap bm1 icon x y
  //bm2 = (newBitmap w h (topBarBlueHighlight this))
  //drawBitmap bm2 icon x y
  button = (newButton '' (action selector this))
  if (notNil hint) { setHint button (localized hint) }
  setCostumes button bm1
  addPart morph (morph button)
  return button
}

method restoreZoom MicroBlocksEditor {
  setBlockScalePercent this 100
}

method zoomIn MicroBlocksEditor {
  setBlockScalePercent this (((global 'blockScale') * 100) + 15)
}

method zoomOut MicroBlocksEditor {
  setBlockScalePercent this (((global 'blockScale') * 100) - 15)
}

method setBlockScalePercent MicroBlocksEditor newPercent {
  setBlockScalePercent (scriptEditor scripter) newPercent
  syncScripts (smallRuntime)
}

method fixZoomButtonsLayout MicroBlocksEditor {
  right = ((right morph) - 15)
  bottom = (((bottom morph) - (height (morph tipBar))) - 10)
  for button zoomButtons {
	right = (right - (width (morph button)))
    setLeft (morph button) right
    setTop (morph button) ((bottom - (height (morph button))) - 5)
  }
}

// tip bar
method addTipBar MicroBlocksEditor {
  tipBar = (initialize (new 'MicroBlocksTipBar'))
  setGlobal 'tipBar' tipBar
  setTitle tipBar 'an element'
  setTip tipBar 'some tip about it'
  addPart morph (morph tipBar)
}

// project operations

method downloadInProgress MicroBlocksEditor {
  if isDownloading {
    existingPrompt = (findMorph 'Prompter')
    if (notNil existingPrompt) { cancel (handler existingPrompt) }
    inform 'Downloading code to board. Please wait.' nil nil true
  }
  return isDownloading
}

method canReplaceCurrentProject MicroBlocksEditor {
  if (downloadInProgress this) {return false }
  return (or
	(not (hasUserCode (project scripter)))
	(confirm (global 'page') nil 'Discard current project?'))
}

method newProject MicroBlocksEditor {
  if (not (canReplaceCurrentProject this)) { return }
  clearProject this
  installBoardSpecificBlocks (smallRuntime)
  updateLibraryList scripter
  fileName = ''
  updateTitle this
}

method clearProject MicroBlocksEditor {
  // Remove old project morphs and classes and reset global state.

  closeAllDialogs this
  setText title ''
  fileName = ''
  createEmptyProject scripter
  clearBoardIfConnected (smallRuntime) true
  if (isRunning httpServer) {
	clearVars httpServer
  }
  clearLoggedData (smallRuntime)
}

method closeAllDialogs MicroBlocksEditor {
  pageM = (morph (global 'page'))
  for p (copy (parts pageM)) {
	// remove explorers, table views -- everything but the MicroBlocksEditor
	if (p != morph) { removePart pageM p }
  }
  doOneCycle (global 'page') // force redisplay
}

method openProjectMenu MicroBlocksEditor {
  if (downloadInProgress this) {return }

  fp = (findMorph 'MicroBlocksFilePicker')
  if (notNil fp) { destroy fp }
  pickFileToOpen (action 'openProjectFromFile' this) lastProjectFolder (array '.ubp' '.gpp')
}

method openProjectFromFile MicroBlocksEditor location {
  // Open a project with the given file path or URL.
  if (beginsWith location '//') {
    lastProjectFolder = 'Examples'
  } else {
    lastProjectFolder = (directoryPart location)
  }

  if (not (canReplaceCurrentProject this)) { return }

  if (beginsWith location '//') {
	data = (readEmbeddedFile (substring location 3) true)
  } else {
	data = (readFile location true)
  }
  if (isNil data) {
	error (join (localized 'Could not read: ') location)
  }
  openProject this data location
}

method openProject MicroBlocksEditor projectData projectName updateLibraries {
  if (downloadInProgress this) { return }
  clearProject this
  fileName = projectName
  updateTitle this
  if (endsWith projectName '.gpp') {
	// read old project
	mainClass = nil
	proj = (readProject (emptyProject) projectData)
	if ((count (classes (module proj))) > 0) {
		mainClass = (first (classes (module proj)))
	}
	loadOldProjectFromClass scripter mainClass (blockSpecs proj)
  } else {
	loadNewProjectFromData scripter (toString projectData) updateLibraries
  }
  updateLibraryList scripter
  developerModeChanged scripter
  saveAllChunksAfterLoad (smallRuntime)
}

method openFromBoard MicroBlocksEditor {
  if (not (canReplaceCurrentProject this)) { return }
  clearProject this
  fileName = ''
  updateTitle this
  updateLibraryList scripter
  readCodeFromNextBoardConnected (smallRuntime)
}

method saveProjectToFile MicroBlocksEditor {
  fp = (findMorph 'MicroBlocksFilePicker')
  if (notNil fp) { destroy fp }
  saveProject this nil
}

method copyProjectURLToClipboard MicroBlocksEditor {
  // Copy a URL encoding of this project to the clipboard.

  saveScripts scripter
  codeString = (codeString (project scripter))
  if (notNil title) {
    projName = (text title)
    codeString = (join 'projectName ''' projName '''' (newline) (newline) codeString)
  }
  setClipboard (join
    'https://microblocksfun.cn/run/microblocks.html#project='
	(urlEncode codeString true)
  )
}

method saveProject MicroBlocksEditor fName {
  saveScripts scripter

  if (and (isNil fName) (notNil fileName)) {
	fName = fileName
	if (beginsWith fName '//Examples') {
	  // if an example was opened, do a "save as" into the Microblocks folder
	  fName = (join (gpFolder) '/' (filePart fileName))
	}
  }

  if ('Browser' == (platform)) {
	if (or (isNil fName) ('' == fName)) { fName = 'Untitled' }
	i = (findLast fName '/')
	if (notNil i) { fName = (substring fName (i + 1)) }
	if (not (endsWith fName '.ubp')) { fName = (join fName '.ubp') }
	browserWriteFile (codeString (project scripter)) fName 'project'
	return
  }

  fName = (fileToWrite (withoutExtension fName) (array '.ubp'))
  if ('' == fName) { return false }

  if (and
	(not (isAbsolutePath this fName))
	(not (beginsWith fName (gpFolder)))) {
	  fName = (join (gpFolder) '/' fName)
  }
  if (not (endsWith fName '.ubp')) { fName = (join fName '.ubp') }

  fileName = fName

  lastProjectFolder = (directoryPart fileName)

  updateTitle this
  if (canWriteProject this fileName) {
    writeFile fileName (codeString (project scripter))
  }
}

method canWriteProject MicroBlocksEditor fName {
  return (or
   (isNil (readFile fName))
   (confirm (global 'page') nil 'Overwrite project?'))
}

method isAbsolutePath MicroBlocksEditor fName {
  // Return true if this string is an absolute file path.
  letters = (letters fName)
  count = (count letters)
  if (and (count >= 1) ('/' == (first letters))) { return true } // Mac, Linux
  if (and (count >= 3) (':' == (at letters 2)) (isOneOf (at letters 3) '/' '\')) {
	return true // Win
  }
  return false
}

// board control buttons

method connectToBoard MicroBlocksEditor { selectPort (smallRuntime) }
method stopAndSyncScripts MicroBlocksEditor { stopAndSyncScripts (smallRuntime) }
method startAll MicroBlocksEditor { sendStartAll (smallRuntime) }

// project title

method updateTitle MicroBlocksEditor {
  projName = (withoutExtension (filePart fileName))
  setText title projName
  redraw title
  centerTitle this
}

method centerTitle MicroBlocksEditor {
  scale = (global 'scale')
  left = (right (morph (last leftItems)))
  right = (left (morph (first rightItems)))
  titleM = (morph title)
  setCenter titleM (half (left + right)) (21 * scale)

  // hide title if insufficient space
  if (((width titleM) + (8 * scale)) > (right - left)) {
	hide titleM
  } else {
	show titleM
  }
}

// stepping

method step MicroBlocksEditor {
  if ('Browser' == (platform)) {
	checkForBrowserResize this
	processBrowserDroppedFile this
	processBrowserFileSave this
  }
  processDroppedFiles this
  updateIndicator this
  if (not (busy (smallRuntime))) { processMessages (smallRuntime) }
  if (isRunning httpServer) {
	step httpServer
  }
  if ('unknown' == newerVersion) {
    launch (global 'page') (newCommand 'checkLatestVersion' this) // start version check
    newerVersion = nil
  } (notNil newerVersion) {
    reportNewerVersion this
    newerVersion = nil
  }
  if (notNil frameRate) {
	updateFPS this
  }
}

method updateFPS MicroBlocksEditor {
	if (isNil lastFrameTime) { lastFrameTime = 0 }
	if (isNil frameCount) { frameCount = 0 }
	if (frameCount > 5) {
		now = (msecsSinceStart)
		frameMSecs = (now - lastFrameTime)
		msecsPerFrame = (round ((frameCount * 1000) / frameMSecs))
		setText frameRate (join '' msecsPerFrame ' fps')
		frameCount = 1
		lastFrameTime = now
	} else {
		frameCount += 1
	}
}

// Progress indicator

method drawProgressIndicator MicroBlocksEditor bm phase downloadProgress {
	scale = (global 'scale')
	radius = (13 * scale)
	cx = (half (width bm))
	cy = ((half (height bm)) + scale)
	bgColor = (topBarBlue this)
	if (1 == phase) {
		lightGray = (mixed (gray 0) 5 bgColor)
		darkGray = (mixed (gray 0) 15 bgColor)
	} (2 == phase) {
		lightGray = (mixed (gray 0) 10 bgColor)
		darkGray = (mixed (gray 0) 25 bgColor)
	} (3 == phase) {
		lightGray = (mixed (gray 0) 25 bgColor)
		darkGray = (mixed (gray 0) 50 bgColor)
	}

	fill bm bgColor
	if (and (3 == phase) (downloadProgress >= 1)) { return }

	// background circle
	drawCircle (newShapeMaker bm) cx cy radius lightGray

	// draw progress pie chart
	degrees = (round (360 * downloadProgress))
	oneDegreeDistance = ((* 2 (pi) radius) / 360.0)
	pen = (pen (newShapeMaker bm))
	beginPath pen cx cy
	setHeading pen 270
	forward pen radius
	turn pen 90
	repeat degrees {
	  forward pen oneDegreeDistance
	  turn pen 1
	}
	goto pen cx cy
	fill pen darkGray
}

method showDownloadProgress MicroBlocksEditor phase downloadProgress {
	isDownloading = (downloadProgress < 1)
	bm1 = (getField progressIndicator 'offCostume')
	drawProgressIndicator this bm1 phase downloadProgress
	bm2 = (getField progressIndicator 'onCostume')
	drawProgressIndicator this bm2 phase downloadProgress
	costumeChanged (morph progressIndicator)
	updateDisplay (global 'page') // update the display
	nextEvent // discard events while downloading
}

// Connection indicator

method drawIndicator MicroBlocksEditor bm bgColor isConnected {
	scale = (global 'scale')
	fill bm bgColor
	if isConnected {
		cx = (half (width bm))
		cy = ((half (height bm)) + scale)
		radius = (13 * scale)
		green = (mixed (color 0 200 0) 70 bgColor)
		drawCircle (newShapeMaker bm) cx cy radius green
	}
	icon = (connectButtonIcon this)
	drawBitmap bm icon (10 * scale) (10 * scale)
}

method updateIndicator MicroBlocksEditor forcefully {
	if (busy (smallRuntime)) { return } // do nothing during file transfer

	status = (updateConnection (smallRuntime))
	if (and (lastStatus == status) (forcefully != true)) { return } // no change
	isConnected = ('connected' == status)

	bm1 = (getField indicator 'offCostume')
	drawIndicator this bm1 (topBarBlue this) isConnected
	bm2 = (getField indicator 'onCostume')
	drawIndicator this bm2 (topBarBlueHighlight this) isConnected

	costumeChanged (morph indicator)
	lastStatus = status
}

// browser support

method checkForBrowserResize MicroBlocksEditor {
  browserSize = (browserSize)
  w = (first browserSize)
  h = (last browserSize)
  winSize = (windowSize)

  dx = (abs ((at winSize 1) - w))
  dy = (abs ((at winSize 2) - h))
  if (and (dx <= 1) (dy <= 1)) {
    // At the smallest browser zoom levels, sizes can differ by one pixel
    return // no change
  }

  openWindow w h true
  page = (global 'page')
  oldScale = (global 'scale')
  updateScale page
  scale = (global 'scale')
  pageM = (morph page)
  setExtent pageM (w * scale) (h * scale)
  for each (parts pageM) { pageResized (handler each) w h this }
  if (scale != oldScale) {
	for m (allMorphs pageM) { scaleChanged (handler m) }
  }
}

method putNextDroppedFileOnBoard MicroBlocksEditor {
  putNextDroppedFileOnBoard = true
}

method processBrowserDroppedFile MicroBlocksEditor {
  pair = (browserGetDroppedFile)
  if (isNil pair) { return }
  fName = (callWith 'string' (first pair))
  data = (last pair)
  if putNextDroppedFileOnBoard {
    putNextDroppedFileOnBoard = false // clear flag
	sendFileData (smallRuntime) fName data
  } else {
    processDroppedFile this fName data
  }
}

method processBrowserFileSave MicroBlocksEditor {
	lastSavedName = (browserLastSaveName)
	if (notNil lastSavedName) {
		if (endsWith lastSavedName '.hex') {
			startFirmwareCountdown (smallRuntime) lastSavedName
		} (endsWith lastSavedName '.ubp') {
			// Update the title
			fileName = (withoutExtension lastSavedName)
			updateTitle this
		}
		if ('_no_file_selected_' == lastSavedName) {
			startFirmwareCountdown (smallRuntime) lastSavedName
		}
	}
}

// dropped files

method processDroppedFiles MicroBlocksEditor {
  for evt (droppedFiles (global 'page')) {
	fName = (toUnixPath (at evt 'file'))
	data = (readFile fName true)
	if (notNil data) {
	  processDroppedFile this fName data
	}
  }
  for evt (droppedTexts (global 'page')) {
	text = (at evt 'file')
	processDroppedText this text
  }
}

method processDroppedFile MicroBlocksEditor fName data {
  lcFilename = (toLowerCase fName)
  if (endsWith lcFilename '.ubp') {
	if (not (canReplaceCurrentProject this)) { return }
	openProject this data fName
  }
  if (endsWith lcFilename '.ubl') {
	importLibraryFromFile scripter fName data
  }
  if (endsWith lcFilename '.csv') {
	if (isNil data) { return } // could not read file
	data = (joinStrings (splitWith (toString data) ',')) // remove commas
	clearLoggedData (smallRuntime)
	for entry (lines data) { addLoggedData (smallRuntime) entry }
  }
  if (endsWith lcFilename '.png') {
    importFromPNG this data
  }
  // xxx for testing:
  if (endsWith lcFilename '.gp') {
    eval (toString data) nil (topLevelModule)
  }
}

method processDroppedText MicroBlocksEditor text {
  if (beginsWith text 'http') {
    text = (first (lines text))
    url = (substring text ((findFirst text ':') + 3))
    host = (substring url 1 ((findFirst url '/') - 1))
    path = (substring url (findFirst url '/'))
    fileName = (substring path ((findLast path '/') + 1) ((findLast path '.') - 1))

    if (or ((findSubstring 'scripts=' url) > 0) ((findSubstring 'project=' url) > 0)) {
      importFromURL this url
      return
    }

    if (endsWith url '.ubp') {
      if (not (canReplaceCurrentProject this)) { return }
      openProject this (httpBody (httpGet host path)) fileName
    } (endsWith url '.ubl') {
      importLibraryFromString scripter (httpBody (httpGet host path)) fileName fileName
    } (and (or (notNil json) (endsWith url '.png')) ('Browser' == (platform))) {
      data = (httpBody (basicHTTPGetBinary host path))
      if ('' == data) { return }
      importFromPNG this data
    }
  } else {
	spec = (specForOp (authoringSpecs) 'comment')
	block = (blockForSpec spec)
	setContents (first (inputs block)) text
	// doesn't work because hand position isn't updated until the drop is done
	setLeft (morph block) (x (hand (global 'page')))
	setTop (morph block) (y (hand (global 'page')))
	addPart (morph (scriptEditor scripter)) (morph block)
  }
}

method importFromURL MicroBlocksEditor url {
  i = (findSubstring 'scripts=' url)
  if (notNil i) { // import scripts embedded in URL
    scriptString = (urlDecode (substring url (i + 8)))
    pasteScripts scripter scriptString
    return
  }
  i = (findSubstring 'project=' url)
  if (notNil i) { // open a complete project
    urlOrData = (substring url (i + 8))
    if (beginsWith urlOrData 'http') {
      // project link
      fileName = (substring urlOrData ((findLast urlOrData '/') + 1) ((findLast urlOrData '.') - 1))
      if (not (canReplaceCurrentProject this)) { return }
      openProject this (httpBody (httpGetInBrowser urlOrData)) fileName
   } else {
      // project embedded in URL
      projectString = (urlDecode (substring url (i + 8)))
      if (not (canReplaceCurrentProject this)) { return }
      projName = (extractProjectName this projectString)
      if (not (canReplaceCurrentProject this)) { return }
      openProject this projectString projName
    }
    return
  }
}

method extractProjectName MicroBlocksEditor projectString {
  for line (lines projectString) {
    if (beginsWith line 'projectName') {
      return (first (argList (first (parse line))))
    }
  }
  return '' // no name found
}

method importFromPNG MicroBlocksEditor pngData {
  scriptString = (getScriptText (new 'PNGReader') pngData)
  if (isNil scriptString) { return } // no script in this PNG file
  i = (find (letters scriptString) (newline))
  scriptString = (substring scriptString i)
  pasteScripts scripter scriptString
}

// handle drops

method wantsDropOf MicroBlocksEditor aHandler { return true }

method justReceivedDrop MicroBlocksEditor aHandler {
  if (or (isAnyClass aHandler 'ColorPicker' 'Monitor') (hasField aHandler 'window')) {
	addPart (morph (global 'page')) (morph aHandler)
  } else {
	animateBackToOldOwner (hand (global 'page')) (morph aHandler)
  }
}

// version check

method checkLatestVersion MicroBlocksEditor {
  latestVersion = (fetchLatestVersionNumber this) // fetch version, even in browser, to log useage
  if ('Browser' == (platform)) { return } // skip version check in browser/Chromebook
  currentVersion = (splitWith (ideVersionNumber (smallRuntime)) '.')

  // sanity checks -- both versions should be lists/arrays of strings representing integers
  // can get garbage if the HTTP request fails
  for n latestVersion { if (not (representsAnInteger n)) { return }}
  for n currentVersion { if (not (representsAnInteger n)) { return }}

  for i (count latestVersion) {
	latest = (toInteger (at latestVersion i))
	current = (toInteger (at currentVersion i))
	pilot = (current > latest)
	if pilot {
      // we're running a pilot release, lets check the latest one
      latestVersion = (fetchLatestPilotVersionNumber this)
      for n latestVersion { if (not (representsAnInteger n)) { return }} // sanity check
      latest = (toInteger (at latestVersion i))
	}
	if (latest > current) {
	  newerVersion = latestVersion
	} (current > latest) {
      // if this subpart of the current version number is > latest, don't check following parts
      // (e.g. 2.0.0 is later than 1.9.9)
      return
	}
  }
}

method fetchLatestVersionNumber MicroBlocksEditor {
  platform = (platform)
  if ('Browser' == platform) {
    if (browserIsChromeOS) {
      suffix = '?C='
    } else {
      suffix = '?B='
    }
  } ('Mac' == (platform)) {
    suffix = '?M='
  } ('Linux' == (platform)) {
    suffix = '?L='
  } ('Win' == (platform)) {
    suffix = '?W='
  } else {
    suffix = '?R='
  }
  url = (join '/downloads/latest/VERSION.txt' suffix (rand 100000 999999))
  versionText = (basicHTTPGet 'microblocksfun.cn' url)
  if (isNil versionText) { return (array 0 0 0) }
  return (splitWith (substring (first (lines versionText)) 1) '.')
}

method fetchLatestPilotVersionNumber MicroBlocksEditor {
  versionText = (basicHTTPGet 'microblocks.fun' '/downloads/pilot/VERSION.txt')
  if (isNil versionText) { return (array 0 0 0) }
  versionLine = (first (lines versionText))
  // take out "-pilot" first
  return (splitWith (substring versionLine 1 ((count versionLine) - 6)) '.')
}

method reportNewerVersion MicroBlocksEditor {
  versionString = (joinStrings newerVersion '.')
  newerVersion = nil // clear this to avoid repeated calls from step
  (inform (global 'page') (join
      'A new MicroBlocks version has been released (' versionString ').' (newline)
      (newline)
      'Get it now at http://microblocks.fun')
    'New version available')
}

// user preferences

method readUserPreferences MicroBlocksEditor {
  result = (dictionary)
  if ('Browser' == (platform)) {
    jsonString = (browserReadPrefs)
    waitMSecs 20 // timer for callback in ChromeOS
    jsonString = (browserReadPrefs) // will have result the second time
  } else {
    path = (join (gpFolder) '/preferences.json')
    jsonString = (readFile path)
  }
  if (notNil jsonString) {
	result = (jsonParse jsonString)
	if (not (isClass result 'Dictionary')) { result = (dictionary) }
  }
  return result
}

method isChineseWebapp MicroBlocksEditor {
	if ('Browser' != (platform)) { return false }
	url = (browserURL)
	return (or
		((containsSubString url 'microblocksfun.cn') > 0)
		((containsSubString url 'blocks.aimaker.space') > 0)
	)
}

method applyUserPreferences MicroBlocksEditor {
	prefs = (readUserPreferences this)
	if (notNil (at prefs 'locale')) {
		setLanguage this (at prefs 'locale')
	} (isChineseWebapp this) {
		setLanguage this '简体中文'
	}
	if (notNil (at prefs 'boardLibAutoLoadDisabled')) {
		boardLibAutoLoadDisabled = (at prefs 'boardLibAutoLoadDisabled')
	}
	if (notNil (at prefs 'autoDecompile')) {
		autoDecompile = (at prefs 'autoDecompile')
	}
	if (notNil (at prefs 'blockSizePercent')) {
		percent = (at prefs 'blockSizePercent')
		setGlobal 'blockScale' ((clamp percent 25 500) / 100)
	}
}

method saveToUserPreferences MicroBlocksEditor key value {
	prefs = (readUserPreferences this)
	if (isNil value) {
		remove prefs key
	} else {
		atPut prefs key value
	}
    if ('Browser' == (platform)) {
		browserWritePrefs (jsonStringify prefs)
	} else {
		path = (join (gpFolder) '/preferences.json')
		writeFile path (jsonStringify prefs)
	}
}

method toggleBoardLibAutoLoad MicroBlocksEditor flag {
	boardLibAutoLoadDisabled = (not flag)
	saveToUserPreferences this 'boardLibAutoLoadDisabled' boardLibAutoLoadDisabled
}

method boardLibAutoLoadDisabled MicroBlocksEditor {
	return (boardLibAutoLoadDisabled == true)
}

method toggleAutoDecompile MicroBlocksEditor flag {
	autoDecompile = flag
	saveToUserPreferences this 'autoDecompile' autoDecompile
}

method autoDecompileEnabled MicroBlocksEditor {
	return (autoDecompile == true)
}

// developer mode

method developerModeChanged MicroBlocksEditor {
  developerModeChanged scripter
  fixLayout this
}

// layout

method pageResized MicroBlocksEditor {
  scale = (global 'scale')
  page = (global 'page')
  fixLayout this
  if ('Win' == (platform)) {
	// workaround for a Windows graphics issue: when resizing a window it seems to clear
	// some or all textures. this forces them to be updated from the underlying bitmap.
	for m (allMorphs (morph page)) { costumeChanged m }
  }
}

// top bar drawing

method topBarBlue MicroBlocksEditor { return (colorHSV 180 0.045 1.0) }
method topBarBlueHighlight MicroBlocksEditor { return (colorHSV 180 0.17 1.0) }
method topBarHeight MicroBlocksEditor { return (46 * (global 'scale')) }

method drawOn MicroBlocksEditor aContext {
  scale = (global 'scale')
  x = (left morph)
  y = (top morph)
  w = (width morph)
  topBarH = (topBarHeight this)
  fillRect aContext (topBarBlue this) x y w topBarH
  grassColor = (color 137 169 31)
  grassH = (5 * scale)
  fillRect aContext grassColor x ((y + topBarH) - grassH) w grassH
}

// layout

method fixLayout MicroBlocksEditor fromScripter {
  setExtent morph (width (morph (global 'page'))) (height (morph (global 'page')))
  fixTopBarLayout this
  fixZoomButtonsLayout this
  fixTipBarLayout this
  if (true != fromScripter) { fixScripterLayout this }
}

method fixTopBarLayout MicroBlocksEditor {
  scale = (global 'scale')
  space = 0

  // Optimization: report one damage rectangle for the entire top bar
  reportDamage morph (rect (left morph) (top morph) (width morph) (topBarHeight this))

  centerY = (20 * scale)
  x = 0
  for item leftItems {
	if (isNumber item) {
	  x += item
	} else {
	  m = (morph item)
	  y = (centerY - ((height m) / 2))
	  setPosition m x y
	  x += ((width m) + space)
	}
  }
  x = (width morph)
  for item (reversed rightItems) {
	if (isNumber item) {
	  x += (0 - item)
	} else {
	  m = (morph item)
	  y = (centerY - ((height m) / 2))
	  setPosition m (x - (width m)) y
	  x = ((x - (width m)) - space)
	}
  }
  centerTitle this
}

method fixTipBarLayout MicroBlocksEditor {
	fixLayout tipBar
	setLeft (morph tipBar) 0
	setBottom (morph tipBar) (bottom morph)
}

method fixScripterLayout MicroBlocksEditor {
  scale = (global 'scale')
  if (isNil scripter) { return } // happens during initialization
  m = (morph scripter)
  setPosition m 0 (topBarHeight this)
  w = (width (morph (global 'page')))
  h = (max 1 (((height (morph (global 'page'))) - (top m)) - (height (morph tipBar))))
  setExtent m w h
  fixLayout scripter
}

method drawIcon MicroBlocksEditor {
	h = 200
	w = ((2 / 3) * h)
	r = (h / 28)

	bm = (newBitmap (w + 5) (h + 5)) // add a bit for line width
	pen = (newVectorPen bm)

	beginPath pen (0.632 * w) (0.012 * h)
	cubicCurveTo pen (0.562 * w) (0.013 * h) (0.342 * w) (0.046 * h) (0.342 * w) (0.165 * h)
	cubicCurveTo pen (0.342 * w) (0.241 * h) (0.356 * w) (0.337 * h) (0.392 * w) (0.401 * h)
	cubicCurveTo pen (0.316 * w) (0.405 * h) (0.299 * w) (0.410 * h) (0.240 * w) (0.417 * h)
	cubicCurveTo pen (0.282 * w) (0.365 * h) (0.298 * w) (0.313 * h) (0.298 * w) (0.251 * h)
	cubicCurveTo pen (0.298 * w) (0.029 * h) (0.390 * w) (0.013 * h) (0.344 * w) (0.013 * h)
	cubicCurveTo pen (0.298 * w) (0.013 * h) (0.035 * w) (0.087 * h) (0.054 * w) (0.251 * h)
	cubicCurveTo pen (0.081 * w) (0.323 * h) (0.104 * w) (0.426 * h) (0.138 * w) (0.474 * h)
	cubicCurveTo pen (0.077 * w) (0.550 * h) (0.030 * w) (0.620 * h) (0.030 * w) (0.697 * h)
	cubicCurveTo pen (0.030 * w) (0.864 * h) (0.241 * w) (1.000 * h) (0.503 * w) (1.000 * h)
	cubicCurveTo pen (0.791 * w) (1.000 * h) (1.000 * w) (0.864 * h) (1.000 * w) (0.697 * h)
	cubicCurveTo pen (1.000 * w) (0.643 * h) (0.965 * w) (0.395 * h) (0.517 * w) (0.395 * h)
	cubicCurveTo pen (0.554 * w) (0.331 * h) (0.569 * w) (0.238 * h) (0.569 * w) (0.165 * h)
	cubicCurveTo pen (0.569 * w) (0.042 * h) (0.695 * w) (0.012 * h) (0.628 * w) (0.012 * h)
	cubicCurveTo pen (0.630 * w) (0.012 * h) (0.630 * w) (0.012 * h) (0.632 * w) (0.012 * h)
	fill pen (gray 250)
	stroke pen (gray 0) 3
	return bm
}

// context menu

method rightClicked MicroBlocksEditor aHand {
  popUpAtHand (contextMenu this) (global 'page')
  return true
}

method contextMenu MicroBlocksEditor {
  menu = (menu 'MicroBlocks' this)
  addItem menu 'about...' (action 'showAboutBox' (smallRuntime))
  addLine menu
  addItem menu 'update firmware on board' (action 'installVM' (smallRuntime) false false) // do not wipe flash, do not download VM from server
  addLine menu

if (contains (commandLine) '--allowMorphMenu') { // xxx testing (used by John)
// addItem menu 'decompile all' (action 'decompileAll' (smallRuntime))
// addLine menu
// addItem menu 'dump persistent memory' (action 'sendMsg' (smallRuntime) 'systemResetMsg' 1 nil)
// addItem menu 'compact persistent memory' (action 'sendMsg' (smallRuntime) 'systemResetMsg' 2 nil)
// addLine menu
}

  if (not (devMode)) {
	addItem menu 'show advanced blocks' 'showAdvancedBlocks'
  } else {
	addItem menu 'firmware version' (action 'getVersion' (smallRuntime))
	addLine menu
// Commented out for now since all precompiled VM's are already included in IDE
//	addItem menu 'download and install latest VM' (action 'installVM' (smallRuntime) false true) // do not wipe flash, download latest VM from server
	addItem menu 'erase flash and update firmware on ESP board' (action 'installVM' (smallRuntime) true false) // wipe flash first, do not download VM from server
	if ('Browser' != (platform)) {
	  addLine menu
	  if (not (isRunning httpServer)) {
		addItem menu 'start HTTP server' 'startHTTPServer'
	  } else {
		addItem menu 'stop HTTP server' 'stopHTTPServer'
	  }
	}
	addLine menu
	if (boardLibAutoLoadDisabled this) {
		addItem menu 'enable autoloading board libraries' (action 'toggleBoardLibAutoLoad' this true)
	} else {
		addItem menu 'disable autoloading board libraries' (action 'toggleBoardLibAutoLoad' this false)
	}

	if (autoDecompileEnabled this) {
		addItem menu 'disable PlugShare when project empty' (action 'toggleAutoDecompile' this false) 'when plugging a board, do not automatically read its contents into the IDE even if the current project is empty'
	} else {
		addItem menu 'enable PlugShare when project empty' (action 'toggleAutoDecompile' this true) 'when plugging a board, automatically read its contents into the IDE if the current project is empty'
	}

// xxx for testing blend in browser...
// addItem menu 'time redraw' (action 'timeRedraw' this)
// addLine menu
// addItem menu 'cursorTest' cursorTest
// addItem menu 'benchmark' (action 'runBenchmarks' (global 'page'))

	addLine menu
	addItem menu 'hide advanced blocks' 'hideAdvancedBlocks'
  }
  return menu
}

method hasHelpEntryFor MicroBlocksEditor aBlock {
  return (notNil (helpEntry tipBar (primName (expression aBlock))))
}

method openHelp MicroBlocksEditor aBlock {
  entry = (helpEntry tipBar (primName (expression aBlock)))
  if (isNil entry) { return }
  helpPath = (at entry 2)
  if (beginsWith helpPath '/') {
    url = (join 'https://wiki.microblocks.fun' helpPath)
  } else {
    url = (join 'https://wiki.microblocks.fun/reference_manual/' helpPath)
  }
  openURL url
}

// Pretty Printer test

method ppTest MicroBlocksEditor {
	// Test the pretty printer by loading each example project and then generating its
	// code string. The result should match the original file.

	for fn (listEmbeddedFiles) {
		if (beginsWith fn 'Examples') {
			data1 = (readEmbeddedFile fn)
			proj = (loadFromString (newMicroBlocksProject) data1)
			data2 = (codeString proj)
			if (data2 != data1) {
				showMismatches this fn data1 data2
			}
		}
	}
}

method showMismatches MicroBlocksEditor fn s1 s2 {
	print 'MISMATCH!' (filePart fn)
	lines1 = (nonEmptyLines this s1)
	lines2 = (nonEmptyLines this s2)
	if ((count lines1) != (count lines2)) {
		print '  Line counts do not match' (count lines1) (count lines2)
	}
	mismatchCount = 0
	for i (min (count lines1) (count lines2)) {
		l1 = (at lines1 i)
		l2 = (at lines2 i)
		if (l1 != l2) {
			print '    A: ' l1; print '    B: ' l2
			mismatchCount += 1
		}
	}
	print '  Mismatched lines:' mismatchCount
}

method nonEmptyLines MicroBlocksEditor s {
	result = (list)
	for line (lines s) {
		if (line != '') { add result line }
	}
	return result
}

method cursorTest MicroBlocksEditor {
  menu = (menu 'Cursor Test' this)
  addItem menu 'default'		(action 'setCursor' 'default')
  addItem menu 'text'			(action 'setCursor' 'text')
  addItem menu 'wait'			(action 'setCursor' 'wait')
  addItem menu 'crosshair'		(action 'setCursor' 'crosshair')

  addItem menu 'nwse-resize'	(action 'setCursor' 'nwse-resize')
  addItem menu 'nesw-resize'	(action 'setCursor' 'nesw-resize')
  addItem menu 'ew-resize'		(action 'setCursor' 'ew-resize')
  addItem menu 'ns-resize'		(action 'setCursor' 'ns-resize')

  addItem menu 'move'			(action 'setCursor' 'move')
  addItem menu 'not-allowed'	(action 'setCursor' 'not-allowed')
  addItem menu 'pointer'		(action 'setCursor' 'pointer')

  popUpAtHand menu (global 'page')
}

method showGraph MicroBlocksEditor {
	graph = (findMorph 'MicroBlocksDataGraph')
	if (notNil graph) { destroy graph }
	page = (global 'page')
	graph = (newMicroBlocksDataGraph)
	setPosition (morph graph) (x (hand page)) (y (hand page))
	addPart page graph
}

method showAdvancedBlocks MicroBlocksEditor {
  setDevMode (global 'page') true
  developerModeChanged this
}

method hideAdvancedBlocks MicroBlocksEditor {
  setDevMode (global 'page') false
  developerModeChanged this
}

method startHTTPServer MicroBlocksEditor {
  if (start httpServer) {
	(inform (join 'MicroBlocks HTTP Server listening on port ' (port httpServer)) 'HTTP Server')
  } ('' == (port httpServer)) {
	return // user did not supply a port number
  } else {
	(inform (join
		'Failed to start HTTP server.' (newline)
		'Please make sure that no other service is running at port 6473.')
		'HTTP Server')
  }
}

method stopHTTPServer MicroBlocksEditor {
  stop httpServer
}

// Language Button

method languageMenu MicroBlocksEditor {
  menu = (menu 'Language' this)
  addItem menu 'English' (action 'setLanguage' this 'English')
  if ('Browser' == (platform)) {
	for fn (sorted (listFiles 'translations')) {
	  fn = (withoutExtension fn)
	  language = (withoutExtension fn)
	  addItem menu language (action 'setLanguage' this language)
	}
  } else {
	for fn (sorted (listEmbeddedFiles)) {
	  fn = (withoutExtension fn)
	  if (beginsWith fn 'translations/') {
		language = (withoutExtension (substring fn 14))
		addItem menu language (action 'setLanguage' this language)
	  }
	}
  }
  if (devMode) {
	addLine menu
	addItem menu 'Custom...' (action 'readCustomTranslationFile' this)
  }
  popUpAtHand menu (global 'page')
}

method setLanguage MicroBlocksEditor newLangOrCode {
  newLang = (languageNameForCode (authoringSpecs) newLangOrCode)
  saveToUserPreferences this 'locale' newLang
  setLanguage (authoringSpecs) newLang
  languageChanged this
}

method readCustomTranslationFile MicroBlocksEditor {
  pickFileToOpen (action 'readCustomTranslation' this) nil (array '.txt')
}

method readCustomTranslation MicroBlocksEditor fName {
  languageName = (withoutExtension (filePart fName))
  translationData = (readFile fName)
  if (notNil translationData) {
	installTranslation (authoringSpecs) translationData languageName
	languageChanged this
  }
}

method languageChanged MicroBlocksEditor {
  languageChanged scripter

  // update items in top-bar
  for item (join leftItems rightItems) {
	if (not (isNumber item)) { destroy (morph item) }
  }
  addTopBarParts this
  updateIndicator this true
  fixLayout this
}

// Iconic menus

method settingsMenu MicroBlocksEditor {
  popUpAtHand (contextMenu this) (global 'page')
}

method addIconButton MicroBlocksEditor icon selector hint width {
  scale = (global 'scale')
  w = (43 * scale)
  if (notNil width) { w = (width * scale) }
  h = (42 * scale)
  x = (half (w - (width icon)))
  y = (11 * scale)
  bm1 = (newBitmap w h (topBarBlue this))
  drawBitmap bm1 icon x y
  bm2 = (newBitmap w h (topBarBlueHighlight this))
  drawBitmap bm2 icon x y
  button = (newButton '' (action selector this))
  if (notNil hint) { setHint button (localized hint) }
  setCostumes button bm1 bm2
  addPart morph (morph button)
  return button
}

method projectMenu MicroBlocksEditor {
  menu = (menu 'File' this)
  addItem menu 'Save' 'saveProjectToFile'
  addLine menu
  addItem menu 'New' 'newProject'
  addItem menu 'Open' 'openProjectMenu'
  if ('connected' != (updateConnection (smallRuntime))) {
	addItem menu 'Open from board' 'openFromBoard'
  } else {
  	checkBoardType (smallRuntime)
  }
  addLine menu
  addItem menu 'Copy project URL to clipboard' 'copyProjectURLToClipboard'
  if (devMode) {
	if ((count (functions (main (project scripter)))) > 0) {
		addLine menu
		addItem menu 'export functions as library' (action 'exportAsLibrary' scripter fileName)
	}
	if (boardHasFileSystem (smallRuntime)) {
		addLine menu
		addItem menu 'put file on board' (action 'putFileOnBoard' (smallRuntime))
		addItem menu 'get file from board' (action 'getFileFromBoard' (smallRuntime))
	}
  }
  popUpAtHand menu (global 'page')
}

// Internal graphics performance tests

to timeRedraw { timeRedraw (first (allInstances 'MicroBlocksEditor')) }

method timeRedraw MicroBlocksEditor {
  page = (global 'page')
  scriptsM = (morph (scriptEditor scripter))
  count = 100
  t = (newTimer)
  repeat count {
    changed scriptsM
    fixDamages page true
  }
  msecs = (msecs t)
  print msecs 'msecs' ((1000 * count) / msecs) 'fps'
}

method redrawnMorphs MicroBlocksEditor {
  // Shows the number of each type of morph redrawn by timeRedraw.

  stats = (dictionary)
  scriptsM = (morph (scriptEditor scripter))
  for m (allMorphs scriptsM) {
    add stats (className (classOf (handler m)))
  }
  for p (reversed (sortedPairs stats)) {
    print p
  }
}

// Script image utility

method fixScriptsInFolderTree MicroBlocksEditor language countryCode rootPath {
  scriptEditor = (scriptEditor scripter)
  setBlockScalePercent this 150
  setExportScale scriptEditor 200
  setLanguage this language

  pattern = (join 'locales/' countryCode '/files/')
  for pngFilePath (allFiles rootPath '.png') {
    if (notNil (findSubstring pattern pngFilePath)) {
      fixPNGScriptImage this pngFilePath
    }
  }
}

method fixPNGScriptImage MicroBlocksEditor pngFile {
  scriptEditor = (scriptEditor scripter)

  // load scripts from file
  clearProject this
  importFromPNG this (readFile pngFile true)

  scriptCount = (count (parts (morph scriptEditor)))
  if (0 == scriptCount) { return }

  updateLibraryList scripter
  if (1 == scriptCount) {
    block = (handler (first (parts (morph scriptEditor))))
    exportAsImageScaled block nil false pngFile
print (filePart pngFile)
  } else {
    saveScriptsImage scriptEditor pngFile true
print scriptCount 'scripts:' (filePart pngFile)
  }
}

// UI image resources

method makeLogoPNG MicroBlocksEditor {
  // Used to generate images for the logo images in both normal and retina resolution.
  // Must be run on a computer with the necessary fonts.

  bm = (newBitmap 276 80 (gray 0 0))
  drawBitmap bm (bunnyIcon this 2) -6 4
  drawLogoText this bm 2
  writeFile 'logoAndTextRetina.png' (encodePNG bm)
  writeFile 'logoAndTextRetina.txt' (base64Encode (encodePNG bm))

  bm = (newBitmap 138 40 (gray 0 0))
  drawBitmap bm (bunnyIcon this 1) -3 2
  drawLogoText this bm 1
  writeFile 'logoAndText.png' (encodePNG bm)
  writeFile 'logoAndText.txt' (base64Encode (encodePNG bm))
}

method drawLogoText MicroBlocksEditor bm scale {
  // Used to create a logo images.
  // Must be run on a computer with the necessary fonts (e.g. MacOS).

  textColor = (gray 50)
  left = (31 * scale)
  top = (5 * scale)
  setFont 'Trebuchet MS' (18 * scale)
  drawString bm 'MicroBlocks' textColor left top
  setFont 'Futura Medium Italic' (8 * scale)
  top += (20 * scale)
  drawString bm 'Small, Fast, Human Friendly' textColor left top
}

method connectButtonIcon MicroBlocksEditor {
  data = '
iVBORw0KGgoAAAANSUhEUgAAABkAAAAWCAYAAAA1vze2AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAF
RgAABUYBwbT6GgAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAKZSURBVEiJrZPB
axNREMa/2U2wCzmIUFCraS499NLWLELD7koOgSIqVGitCKVSWkpBlOJND4LQgyDVmyYbQfAPsHioIiJb
26SXLrQgFMRDzKHtMTVoTLLZ8WC3bNc0yRq/25tv3vvNvHmP8B80NTU1KAiCDqCLiO4lk8nnbl9sFzAz
MzNCRIsAugBIAC7JspwzTXPTyaF2ANPT03eIaAGA4LGqAC6nUqn3/wRRVfU2EX3v7e2NA5ggIgwPD6Nc
LmNpacmdWmTmC7qub7QMGR0dFXd3d58y8y0AdjgcFkKhEMbHxxGNRpFKpbC1teXdtg0g1hIkFoudEATh
IxH1OzEiQnd3NwYGBlAsFrGzs1N3LzMbTQcfj8cHAWwS0Rmvt7e3h1KphHK5fBDr6+uDJEkoFApOMce9
AzskVVUnLcvK4M+rqVcl8vk8KpUKACCRSGB2dhaRSMSd8+TI61IUZYGI5hoV4UgQBPT09GBsbAy5XA7r
6+sAUCOi+8lk8lFdiKqq7wAMtQJwJEkSIpEIiAgAfjDzDV3X3wB1PqOmaTcB3PUDAADLsmDbNkKh0LZt
20PpdNpwvEOdyLIclCQpD+CkX4gjURQfLi8vP3DHDg2+o6NDbgcAgC3L+uUNBtwLIupsA2ABmMxkMq+a
Qb4xs+/TiagmiuJFwzA+1PO9/6STmW2fjAozJ44CAJ5OmPkaETX8oB4VAoHAecMwvjZKOoAoinIagOID
8KVUKp0zTfNns0QCAE3Tosy8COCs22Rmu05nNSJ6u7KycqXVagKapl1n5pcAju3HPtu2PS+K4qlqtfop
GAyOAOjfL2ijVqu9WFtba3g9f0GY+ZkL8JqZJ7LZbNGVY/o58CjIIhFdBfB4dXV1HoD/N9xEvwHaIuvR
gNAXcQAAAABJRU5ErkJggg=='
  dataRetina = '
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
TkSuQmCC'
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method startButtonIcon MicroBlocksEditor {
  data = '
iVBORw0KGgoAAAANSUhEUgAAABQAAAAWCAYAAADAQbwGAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAJ
egAACXoBD0XXIwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAFWSURBVDiNrdM9
axRRFMbx3x0GjaQ2pDCFRcxK2pAitpYi+QIpjQoWFoJYKbFML7EIhHwDYyobi7yInca4d0FBhC3WWKUJ
a0KYFJuVQTa7M84+3XnO4X+fw72XhgfqPoru+2FERSWYE8xiRdtP0ZMq4ERmPFePYVnbN9Gi99LywOBq
D/8aXhv3ScPdsgmv9OlPy7wRbYvmigG5VGDuFnZEb30xMQh4ucjJ57ojFUUvfO0dpGjCvEbxXGJP3e1h
ALuaErzTsO67sWEAIcgsOLGvbr5jRKfn4GFoaVigrrIUx1T+wweCe2o2EvypkghrEtNqNiDFyX/CPks8
MmU7byY6K5fRoeCxlpl/Yd2EZVbelHpoUvOige6l9FewJfPUTR8GjaY46tPfxzM1mwMPzQF/9/CbeKlm
VXBaFNYBBr9kf+sWlo145bp2GVA+4S5uYFVq3WSld+kMPTFR1LOrihUAAAAASUVORK5CYII='
  dataRetina = '
iVBORw0KGgoAAAANSUhEUgAAACcAAAAsCAYAAADmZKH2AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAS
9QAAEvUBKRJxDwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAALKSURBVFiFzdjN
a1xVGIDx3z25UZoS8asqiuhC0klSBP+GFupCcOXSL4SgKFmEirgQdddSSqkipRRKLHbjSmihEQtudOdC
Jc2dmCAo+BXRQG0j6jjHxWTayaQx83Hv3DxwN+ec951n3veeM/dOAjKfY1jiHM6o+MMOILFkj5qVlrEr
mBUdNuGnssQgqNvbNnYbpiWWZU5Y9EAZYhBE920xN4Jpdd/KnLLsnkGK0ajcdh96C6b8Y1nVYVWjgxCD
ILGnw7WjotdEVVUv+sJwoWYabb23y5j7RSftNq/qqUKs1gmCO3uMHRN9KDPnsslcrdYJopE+cxwUfK3q
bN6bJkj6lmvkiZ5Wsygzk9f9mEflbhDdjmN2m5c52G+6QI5yNxjDnMx5Cx7qNUlRck2ekFiQecuSW7sN
DthVgFQrI3hTzZcu299NYKD7b9QjFcElmfdl7uokICAtWKqdZ7AkM7XdwoCh4n02cQdOyVyUeXirRWH9
KovHMa9qWpS0TyYya4rfFJ1wSeJZFT82B8pq6804IPpK1ZPNgbLb2s7doo9kToiGEpk6m/tdOtEHO6lq
GwliwL9le7QRcdxez6eol23Twq94wbjzNH4ddkrlPpF4rvUoSVErUQiu4nUV70nE1omUjQMDJbqIl0z4
7mbTZbV1RfSqCWf/b9Gg2xoxq+6QSb9vtzjFX8U7gQWJV1R82mlAwFqBQtbzv63usW7EaFTuz2KcwAV1
L5v0fS/BqWIq9w2mjfu4nyRBkqvcqmjGNfv6FYNUzEWuhjOGveGRDf+S9kUqsdbnMTxnyIwxWU5O10nx
W4+xizhk3IUcfTYQxK7b8AOm/GxfkWI02rrSYVtXRUeMeseDhR4/10k7qNyaxLv+dsSjVgch1SQV/LLF
4+Y1idM42vqMNUhS9U277IrESdFRlZ43Sy403royn2m8v55TN2vS1TKlmvwHLHW8gYqPdl8AAAAASUVO
RK5CYII='
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method stopButtonIcon MicroBlocksEditor {
  data = '
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAI
+gAACPoBjcM6MwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAACFSURBVDiN7dU9
DkAwGIfx5zW7Re9lZpE4iY+NweBcnIK9pjZVEgnvxjO2yW/rv0KUBVmgBrL4LmoyUAnY8FAusAYobzDX
YCAPUQ8+wC5ReYmdUFHAjugMrQLm6mSGFUiVwC1Rgnw/+BVwVPRGzafXGyi0xsFhVmO+PAbvB/aAncAA
ffwF7ItnNpUpNqZKAAAAAElFTkSuQmCC'
  dataRetina = '
iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAR
8wAAEfMBmr+RUAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAIaSURBVFiF7dkx
TxRBGIfx39wqh1fZ2JBQWFDZ8gWUGDUIBDWCojHxgxkIMSGCgIKCBuMXsKUCtMBQ0ECFnHiuxR16HHvr
GY7bM+HpdubNzpPZyebd/wYN8pFz3TzD7YTpiwg1YzF2E2oXN3l6lR+NrFt700RionUmAmON1Dew6MwO
D3s5aKA2nVU68kxhuBlyVbyJudtDMa0oVbAi9wJDTVX7w1LEncvs1yuoK7hGHjMh+cw1k3d5hrv5ljSZ
SxrcohB40wI5uFFkYYtC0uSxHdzkQpFFXDt1taN8yDNQu5NHdnCVjiLTWi8Hffu8+kJn9eBvwVU6OplB
f8vVKgSul5irnH9UBGOiPJMxA1nJVXEzMPWJ8xBiog0m8SBjsVpmNxkJ64zjSdY2dZgI62zjUtYmddjO
xURZW6QQ5UK7CzoTPBFngiclyqnT0bQJUTvLobx7P7OWSKGUQylrixTOBE/KfyAYt7tgaHdBvM3aIoWl
tm35Y15+ZTRULqINnmMkY69D5ne538tBDgKlXR7jdcZisBwzeph8HUkWKmHRrIy+jQPvcwxVh0nHoo81
8oE53GqpHSt5Bmujj8R0a4vCXvlx97VEjZUCQ13s1U4ktltd7MX0BxZO381ynsEkOVKa1R6K+9zD/Kmp
lQPMutkgf+mmr/C9WH71zDbbLGYxZjgtXeUfQvTPjMc8aoZcYHqHsaaE6Idk9RviFzG4jSVrWs+wAAAA
AElFTkSuQmCC'
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method projectButtonIcon MicroBlocksEditor {
  data = '
iVBORw0KGgoAAAANSUhEUgAAABAAAAAWCAYAAADJqhx8AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAH
6QAAB+kBlHo8QAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAEbSURBVDiN7ZSx
aoNAAIb/hGsqlRZBChWbQicnB3c79AXyEKV5Axdx9w2cut3iEzi2QnFyL9TD1qWTgoNBQ0jQDoXSpOYS
2jXf+v//Bwd3NwAH3/fHs9ksopRebURLABEh5I5sG3ued2EYxkuWZac98RGA29Vq9TDsG1uWdS1J0pum
aX3jn9z8EjiOMy7LklVVdbJjDADHawLXdc/zPE8ZY1uPtsl30bZtOU3TD8bYCAAEQdhfQCkV67p+J4SM
VFWFKIqYTCYAgPl8zheEYSjIsvyq6/pZXyGKIr6gKIpYUZTLJEnWgqZpEAQB4jjmCgamaXbcxg5678FB
cBD8RbD4x34xBMB/LXyeh4SQ+67rnvD1Ue7LEsBj27bTTyA4XCa7dVryAAAAAElFTkSuQmCC'
  dataRetina = '
iVBORw0KGgoAAAANSUhEUgAAACEAAAAsCAYAAADretGxAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAP
0gAAD9IB+4k7yQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAIrSURBVFiF7di9
i9oAGAbwJ7lrC6IHVuxdS40UgoJIXKQZjNCl0L+lmxQRyXCCkK2HSwYHb3IWHPQ6lvqBXHEpiF81LUlP
QTBwyE1K0inQw35EE7FDnjHJ++bH+yYQQsBiisWiy+fzfS4UChGTJUsAHQAXzWbzAwCQVgCiKLpZlv0a
jUbNAgDAA+A1gCuO43KWEKIouhOJxDgWiz3dtQeAc47j3hzvUlkqlTzxeHzEMMyZBYCRd1tPIpvN+rxe
7zebAADwcqtJpFKpx6qq3iyXy0c2AQDgxPQkBEHw393dTXu9np0AAICpSQiC4Jck6cdgMHhoNwAw8Xbk
crlnk8nkZl+AfyJ4ng8oivJ9OBw+2BcA+Ms6eJ4PzGYzaTQabVxDEMT+EZlMhppOp5PxePzb8xRF2YrY
WEc+n38xn8//CGBZFslk8t4xTdMsIe7dqFKpPHG5XF8YhtkAkCSJQCAAhmE21rFYLOxBVKvV00gkMqRp
2r1tk06nYx1Rq9XOQqHQkKbpk20bSJKEer1uCUGWy+Xn4XB4tAug3+8jnU5jtVpZQhyv1+uWLMseWZZN
Fei6DlVV0e120W63LT+UAEBwHKdb7mIxlr6s7IqDMOIgjDgIIw7CiIMw4iCMOAgjDsKIgzDy3yCWBzbc
kgCuD4y4JnVdvzikgCCI90eKoowpiiIAvDoA4LzRaFweAYAsyx+DwWAHwCkAPwDbf479kluCID5pmva2
1WpdAsBPdzu15+Xij+EAAAAASUVORK5CYII='
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method settingsButtonIcon MicroBlocksEditor {
  data = '
iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAH
OgAABzoBqsXEHQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAJ1SURBVDiNpZU/
aBRREMZ/c7tXbBoVooFAWiNaXmO4XYwhCfgnEMXTRuxTxiSIvZWK2qW2sAoSUUlhUA/yHmqRNqCtYDwU
tErA8/JZ5E7ebVYv4lftzJv53puZt98z9oE0TR8C19rmhnPuRK+cUq+AWq0WAVOB63i1Wh3ulReHRrVa
HS6VSvckLTrnngM0Go0qcCiXdwZ4D5Cm6Xkzm9nZ2bnuvX/fCbDOR5qmR4HXwGDb5SV9NbOzQDlkNbOW
pKeSDpjZWNvdMLOxtbW1ja4Tm9l9SYNBftXMKIKkCLiQWx8A7gDnIOixpMVCln9AyNG1ZZqmr4HRgpzP
kt4BmNnJ9unycM65rGN03QpJ33LBLUkLcRwPee+nvffT29vbQ2Z2A2jlYr+GhgGMjo4ebDabk2b2iKDv
kha893cLTkeWZQuSbgeupqSr5XL5Rb1e/25pmq4Cp4EoX34cx0P1ev1nEXGlUiknSfKRvW1pAa9KwHgB
KcDbP5ECrK+vN4E3BUsRMNHzz/sbJBXfR3aHt8reQQCMVCqVcoEf2G2FmY0ULLWA1ZJzbjKO435JV4Cw
9IG+vr7ZPxEnSTIHHAlcTeByHMf9zrnJrlKyLFuWNB3ubmY3t7a2HrR72hnaHHCL7tksO+cudowuEZKU
F5tI0u0kSeazLHvbjhkBDhcU0R8aoQidB54V1r1/THVU8fetMLOZ/yTt4ghFaBb4FMR54ImkHwUcLUmP
gZeBrwEs7CF2zn2QNGZmK+yWlDrnLkRRNJFnlTTvvb/knBsHpsxsRdKpjhZDTt2KUKvVos3NzS8Er4ik
Y+FrUYSef97S0lKL7qFu9CIF+AVCxv2ly3PtJwAAAABJRU5ErkJggg=='
  dataRetina = '
iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAYAAAAehFoBAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAO
egAADnoBz63/KAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAU+SURBVFiFxZld
iFRlGMf/z3tmRmiZAdOirHYEvSlv9KIVnPfAZNvqFOESCJJkGBhZGlokZBkUUUhgWWYFlSREgQUV1ZrZ
NrLvCHpRXbTd5IJOCRukwoyrzOzM++9ix9idOefMObOj/i/P8/U7H+/HeV5Bl5TNZhfWarVfAMxtMlmS
LxYKhde7UUd1IwkATE5OPoJWWABQIvI0AOlGna4BA+gPsN2SyWTu6kaRrgAPDAz0iMjyIB8RCbqh0Iq1
sYvrus9Za0upVOrA0NBQxcvp8uXLWQBz2uTqB7DXy5DL5eZcvHjxMQDJkZGRNwDQL0nQExat9T6Su0Xk
vXK5/KfWeoNXDmvtw21gAWDl4sWLW25Ka/1guVweJbmf5G6t9YdBXH4DQbTW+wA82WwgOayU2l6v18eV
UlsBbADQGwIYAP4h+QHJd0VkrlJqD8n7Pfw+NsZsAmDDAPvCToO2ImLR/pPy06SIKJJOgI8ndEuA67o7
AOwMqiYigtkNWCdE/LJ0Oj1RLBaPT7/YEmStLc0CpKuy1pabr7UAp1KpAwDGrglRsMYaLDPU8kmcOnWq
nk6nzwBYd02wfERy4/Dw8B/N132XS631YQCrriqVv34yxnguNL6jXCm13Vr7O8IPrgmShwHklVJ/A4C1
9nYAWRFZDaAnTBKS1nGc7X52X+BKpXI+Ho/bEMB1AHur1eprJ0+ePOdh39fX1zcvHo+/0NgEBU1lEBFL
cjwycDwe3xJkb6hEcl2hUBgKcmrcyDOZTOZHEfkcQCrAPQZgK4CXvIx+T08wtYIFyQJY3w52ugqFwpC1
di2m3kqQHvVj+3/QZbPZWL1eX06yH8AggKVtku4xxjwbFna6XNd9k+S2Nm6/AfhKRI46jnMin8/XAEAy
mUxOKfUEySyCX9V0TVSr1bTPN9tW2Wx2fq1WO42QAxFASUTy1tr3RWtdAZCIWPMLY8zaiDEzpLX+EsBD
EcOqCtFhQfJY1JhmiUi+g7BERxuYK/PsbGStPdtR7U6CSM76h1Ip1VGOToFv6ySuGzkUgGoHcdlOijXp
ng5iKorkoIh8AyD0PlhEVvf19c3roCCAqWkNwH0RQkoNxsFYY6Uairhw9CQSiZ0AOlo4arXaLrSZg0Xk
V5Jftywcfv5a69MI/rm0ANYYY76NAuu67iqS3yFgEyQixZGRkYXw+N33G3QUkU/a1FYAPs1kMrkIsA+Q
PBQECwAkD8CnN+E7taxYseJmx3HOkmy3Y6uLyDuVSuVVv6W6sRTvAvBUCNjJeDy+IJ/P/+tl94VxHGc+
yTDTnkNyWyKR2KS1/gHAMQB/NWx3AMjWarVVAG4IkQsAHGvtrQCiAZPcg2jzdA+m9gZR9wczJCKqXq+/
BeBeL7snkOu6g7h+/3MQkZWu667xtDVfyOVyc8rl8iiARVedLFhjyWRySXMDsuUJN7qI1xsWABaVSqWN
zRe9PonkNYAJJaVUC0vLFFMsFo/39vbeBOBuv0SNZmAdnffXJqfac4HxHxljdqJpPvYKoDFmC4D9PrDD
juMsFZEFJF8BcCYC6DiAl2Ox2AJr7RIR+T4A9nGEbLf+b2tqu44BeN4Yc6jJT7mue5Dk+jawExcuXLhx
dHR0xu5Qa90P4G0Ad7aDBYJfCY0xW0RkB8nNyWRyiQcsGok/awMLAD83wwKAMeZoMplcRnKziOzwa2Rf
UVeOogYGBnouXbp0DsHnHNuMMZ5nHFHUlVOkI0eOTJA8EeRD8mg3anXznC4IaLxQKLS0TjtR14BJHgRw
3sNkMXXc5XuUFUX/AfHiFId5ScXEAAAAAElFTkSuQmCC'
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method languageButtonIcon MicroBlocksEditor {
  data = '
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAH
qAAAB6gBuRybzQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAANXSURBVDiNlZXd
axxlGMV/z8wkrMZNDRRlNbdqQQrFoDXZeWHRJmJiRXrhjSB6IxXphaAgSKshopGCF+K3f4DI3pS2KqZV
w84sKdFFxAYpih/UYnrlNonZfMzM8WJnZbMEis/NMGfeczhznvd9XmP38sIwPAocBfZJ6gMwsy3gkpm9
F0XRR0DWS7RewDl3TNIbwEAObZpZIskkBWbWn+NrwEtxHL+7w0n3SxiGn0t6G0jNbMPMPm21WsUsy85L
OtdsNotA1cw2cnfvOOfO7ipYLpe/Ah4GvgBqkn5PkuTpRqOx3VmztLS01Wq1npL0h5nNS5qTNBWG4dwO
wXK5PG1mD5jZYhAEbwFTZnZ8YWGh1RtJo9FYl3RC0uEgCGaB74Bx59xxAKtUKoUkSa7l4kHOy4DvJV0z
sxVgpKMnadDMbgYOdAyZWZplWdrX17cnSNN0BuiXNGVmC8ACsArUgEFgD1DIBbeBX4EVQJIGsiwr+75f
NrPTSZK8as653yTtjeO4WKlUgiRJViU9X6/XP+jK9xRAvV5/rKuBzwEnS6VSsVqtps65NUlXPUm3ARcB
Njc3bwUKZvZLb3a9lWXZz8ANy8vLt9C2exEYtjAMJemKmS0CReAQMA/83cW/P39e6MKGgApwPo/oIFDy
AF3Pzf+pANg2s8txHB8ZHR293ff9PyW9Xq/Xz3UWdWV4pIONjY1NeJ5XMbMnoyj6KwzDC8BeD7gC7AcY
Hh5eBtbN7I7rOTGzO4F/oii6mkP7gcvmnDsp6QUze2R9ff2bQqHwred5TUlf0850EHgoJ31JO69V4EFJ
xYGBgYNra2uHPM87Bcx2b2yjvVF92rleoj0AmsDdueCSme3JsqxoZnflnJT2QchKpdKgNz8/vyHpNaAP
+CFN08M5+UQcx/fGcTwuaVHSYhzH41EU3ed53jSA7/uTwI8595Vqtbrl5WHP5L94j+/7LwNngZmRkZEb
e7ObmJgYkDQt6XSapseAA5Lm4jh+E3rmoXPuM0mTwIqZ9Us602q1nigUClWAZrP5+NDQ0CfAJO1jWATO
xHH86H/N6nWQH6lZ4CZJnSmd5J8DoD/v8qqZvVir1T7c0f1ewbw859wzkp6VtK8zpSVtmdlPnue9X6vV
PmaXK+Bf79GQ6SIwG1kAAAAASUVORK5CYII='
  dataRetina = '
iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAP
UQAAD1EBcwOWNwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAf7SURBVFiFzVh9
rFRHFf+d2bvvLoSPpAVKkYpC2iJRAZG8vr1zl9UASkla20Aq2EZpaanRqH+ALabaNLFSS/1KNC2WSqpA
ra+GaFMw6Kabd+fuFpQGW6lIILUC9hX6oPCKb/ftvXP8Y+c+hmXfJ8/EX7K5cz7mzO/OnTl7ZggjxIIF
CyaNGTPmHgC3AJhDROOZWQAAEWlm7iaiQwB+H0XR1nK5fGYk49AwSY3NZDKPEtEqANcMayCiTmbe4TjO
Q8VisTKqBFeuXNnS2dn5LDOvAOAMh1gTRMz8/LRp0+5ub2/vvWKCUsq7AGwBMKZpAKJzzPwjZj5JRE8D
ADPfK4S4jpm/AWBCs37M3JNKpdZ2dHTsHGh8MQi5XQB+2UCuarUPxHF8g1LqEQA1S18LguDh3t7emQD2
WS9TtdpjtNY7fN9vHwlBx/f9vwL4nKV7D0A7ANfIrzLzp0ql0qn+gu/fv7+rVqstBXAQAJjZBfACgHOJ
DzOvkFIeRD9LpxlBIaV8jZk/niiIaDczSwC3G9UFZl4dhmF3f+QS7Nu373wcx6sA/MeobqtUKpKZ91pu
c82EDE5QSlkA8BFL9d0gCJYLITYCSBnCG8Mw/Mdg5BKUy+XDADYaMZXJZL4ZhuFniGhT4sPMc6SUfxyQ
oJTyAQB5q9N3lFLfzmazs5j5DqM+fubMmS1DJZfg7NmzTwH4lxFX53K564Mg+JYQ4hHLbXEul1vflKDv
+9cCeNSyHSei89lsdqEQ4mu4uEYeO3To0KDpoRGmzw+MmIrj+MvZbHah1vosgBOJn9b6saVLl05J5L40
4/v+fmZeOMg4MRFtZ+bjAE4DOM3MVSI6z8xLiWgDADDzZiLay8wTiMgFMNn8PsjMdxLRgNmDiMpBEGT7
CPq+P4eZD5ngIKKTAD4wlJkZRXQCmJpwyGQyNxYKhSMCALTWT1qOHUqp6Y7jXMfMdzKzsmw8CkTsGAER
3QVghlLqWgAlACAiVKvVp4D6unKIKJv0yGQy9wJAsVg8AWCHlDJJLXAcZ6bWOo6iaGoqlZrCzFMApAFk
AEgAK41rOwAFoAKgRkSn4jg+5ThOZ0tLS7pSqRwzfu8EQbDdin9PFEV/N6IEIBzzV5ZsgBOFQuFIwxvP
N893i8XiP037eOO0eJ53johWAgAzvxSG4bP9TaHv+13MfDURzbP1xWLxsJTy3wCmAUjncrnPCwB3WD4v
2h1aW1snAPiQEZsm0pGAmV83z5n5fH5cg2130tZarxLM/FHLfslbu647Axd3+uHRIgjgDfMUtVpthm3Q
Wm+zxHmCiCYZgZVS+xqcJyZtZu4aRYJ9xWsqlZpoG8rl8iu4uJEmOQBaDIHI87wv2M5ENI+5b9PNarQ3
oM1ue54X9eeotZ4lRD0VxnF8m+d5H25wiVDffC0kpRyN1PE/w4AZ/f8BDurfm5i5BmCNbRRCzGPm9QDA
zDsB7L48RB98IlpnfLcACPpzJKLlAFYZ381oyBBEtA1Ampm1Q0RVZs4QkaOU2mE7SinfArDekD0WBMEl
dhue5zkA1hmxHIZhv75Syr5yjpl3lUqlsmUWUspfGaJVobVOdid5nneTHUgIYVe+V/U34AjQF4uIztuG
fD6fxcXU1iWI6DXL+UsNBN8EoA1Bu4i9UswxT51Op9+yDVEU2cvsoGDm5y3Fctu5WCy+D+BNQ3buKBJM
jhNHzRg2liWNVCq1k1D/5lWY/2PXdW+0/4+llL+FOYvEcTzddd0urfXkKIqmCiGuBjAeAEw9uNa0txJR
cubo1lp3OY7TKYQ4rbWerLVOKusXlFJJgYF8Pj/bKhZqSqmMg/onDAEsAoBqtfoMAD+fz4+LougmZh5H
VF8SQogjURSNNe1LXjvxMe21ANYmshACWmtorUFEF6xu4z3PW5JOp8vFYvH9OI5/kRiYOQCgLytYDd4A
cAOu/BZhqIgAHAUwO+Hnuu7sQqFwpO+1pZSvAGgdKAozayHEHq3120TUiXrZXyGiXmb+JICvGNefEdFf
mLkF9VpxMjNPFUJM01p/drCSH0ColJKANUOu695arVZPwhwtUT9vPC2EKDHzLQDuIyKhtf5DGIY/bYzo
eR4nn5mZ/6yUuqwelFJ+nYhuNuKTzPyiKZbvB5AULVFPT0/fhUHfmxQKhXeEEA9a8SanUqlaEAQvaa0f
R/0zgIgeWLZsmYthwvTZYMQ4juMfhmG4x8gJOTDzhgMHDrx7GUEA6OjoeALAnxJZa/2wlHJTqVQ6xsy/
Nurp3d3d6zBMdHd33w9zECOi7eVy+ajneY8DeMhy2xOG4Y/tfpetBaXUkoYN86CUcm+1Wv0+gNjoNrW1
tc1u7NsffN+fA+B7Rowrlcpmz/MKyTHVkH5dKXVzY9+mizUMw3kwFz4GSzKZTEhEu4w8Vgix0xwJBsTi
xYsnmkJjLAAw8+9c1y0R0actt1eDIPhEs/797aZIKTUfwG8s3QRmXpFcoRHR/HQ6/XI2m53SPATQ2tp6
TU9Pz8sA5hpyvUR0O6w7Q631c0qpBTBrvBGDXmAuWrRoVRzHW2FmoAnOE9FPABxn5p8b3Tqt9Qwi+ioR
NZ1lIrrAzGuUUgPeDw71jtrJ5XLPaK1X48qTdw3AdqXUfehn1mwMtaKOOjo6vug4zngiesIk6eHibWbe
7DjOBKXU3UMhBwzzlt9GW1vbVel0eo3W+lYAHwMwDheTfAygG8DfmHlXOp3eViwW3xvJOP8F10V9BVup
s+gAAAAASUVORK5CYII='
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method graphIcon MicroBlocksEditor scale {
  data = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAWCAYAAADafVyIAAAABHNCSVQICAgIfAhkiAAAAA
lwSFlzAAAKkAAACpABL6VQZQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAMLSU
RBVEiJrZVPaBxVHMc/b/bNZHtYk01MnIZYUohFTVzbxNBbCwXxYObS4sGLWFvYgydbK43R5TUmYMHutR
baXkTIoYey7oZStM2hBD1EF3PomiZUs6FLsgfJkj+QmZ3nYXfCmiZ0W/Z7enx/v/f9Pt7vO/PE0NDQZS
HEZ4BJY+ECSVkVd4UQfzZSXWv9BnBOUjn5bCqVeqeRBo7jzAD9xosKKKVO7MK9PDo6+nYtJxzH0cDvoV
DolOd5++sRtyzL7Ovru10sFs/n8/lcwMdisYumaQ6VSqWT8/PzCaBfBkXP87qFEEfqMejo6DhiGEa0ub
n586WlpesAbW1tByzLcra2tv6em5srGUblcrYN0un0FDBVj4FSagogHA6/OTg4+MD3/RlgGvAtyzqZyW
SyjuMA8NwzUEq9DhwDsoD2fT8hhDgDHAWuKaWytf17GiilPhkfH99tJnFAABeAFPC+1vo7oNjU1PTVzu
a9DATwheu647VkMpncB3wEPFJK/QKMVksvAV8ODw//+5RQkKJyuXxGSvkaQGdn51u2bX8N6Hw+f7FYLD
4G6O7uPt7a2vrp6urqDwsLCz8B9Pb2XpBSRmdnZ0d839cAnuc9CoVCN9jrO4hGo+8BGsC27Y8DPhKJvA
u4hUJhKuBWVlZuLS8v3wjEd2I7RZOTk1kgOzY29qrnef3APWDRNM3TAwMDaK3/Ag4BP05MTNzcTawWQY
rkzoLneXFACiGuSimnXdf9QGt9mWqEDcO49izxWvzvipRSFnAWeGLbdmpkZKQghPgWOAicBh4mEokHL2
wghDgFvCKE+D4ej7sAkUgkCfxTrV+lOpt6sZ0irfX5WCx207KsA7lc7pv19fVS0NTV1XW4vb39w1wupz
Y3NzefJaq1/kMIcYXaf1FPT88+y7IOuq7789ra2t3aDYuLi7+Fw+EnGxsb9+s5tZSyUC6XK+uAbGlpmQ
EumaZ5J51O/7pzUyaTma5HPMBTKVJKrQDqeUTqgXAcZ4vKk/mwkcLVJ9OUQBI4p7UeaKQBlUf/yn/9gR
oIgZwg6gAAAABJRU5ErkJggg=='
  dataRetina = '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'
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method zoomOutIcon MicroBlocksEditor scale {
  dataRetina = '
iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAACXBIWXMAABx2AAAcdgH7OYqmAAAAGXRF
WHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAy5JREFUWIXN2EtoXVUUBuAvMU0Uan3Vtj5A
FFqtigNtpa0jpT4gOnCggtDSgkMfOFHEgUUQCk7EFkQdtBOtYBxWMSNBUetjKlofQSltBtKmRmxq08bB
ziXnrnvuPY97LvGHPdgc1r/+vdfae691hjSHy/EAxnEzrsMazOM4pvEtDuNz/Nug7564FRM4h4WS4zRe
x1WDFLYaB6QdKissjhm8jJGmxd2B3wqcz+EPKbxFi5jElU2JewSzOU7O4UPsxDXBZhi34Hl80UXkz9jQ
r7jNOJND/gHWV+DZLh2YPJG1d/JaHAuEZ7CjJt8I9uWInFQzJycD0d/YVlNcFs/miHypKsn2QHABTzQg
roU3A/+MCqEewpFA8EaD4kgh/S742FvW+O5geNpgLtj7g59TWFHG8NVg+NoAxLXwZfB173AJo4fDfKJp
VRl8FObjRQYjOG9pRcelnBwUNmrfwc+K7pu10ivQwk+Lhi1cJr0sdTGnPSJHpQ25aHEeX6QObNK+okPh
+23he9XxZ47P6cz32aIcjDs8X7SiBpCtE1cUhXg6zNeF+Um824eY2TAfCj5OFBFcrD0kR/sQUwbXB39f
FYV4DlOZ+XrcOBhtSC1DFj+UuQcPh3k/p7YI8c79uIzRQ9q3fQpjzepCarSyfc1ZXFrGcEwq3bMinx6A
wIngI15pPfFUMP5HKu2bws7APy+1CKUxgh8DyXmdOVMH90iHMcv9Th2izTp73wvY3Ye4x6XKPOb46qpE
V+DTQJQN9zMYrcB3NfZLC8xy/YXbq4rbKHVbRe/qFJ7DTV14hqUo7F0UkrfQjpQpKp3G8T5W5XzLVh0R
v+B3qTwblTrCDVJ1lIdjeFQq+0thCC8uiohhWJDCvU3nwakzPtH5xvfEGA5aOgR5oWz1JMN4DL/WEPY1
7qsijBSK2MFlT+ysVANGjOJBqRHvJnYe3+AV3FVVGGyRyptu4qrce2O4AVtxp1QZl3n3u+JJ+f9csuOF
fhz0gz2651trvGewzVJPzPQQtiD9hbpkucTB2zmiWjt6QqpylxUr8b1OcWelJP9fYK1OkbuWU1AeVuIt
qVPbs7xSlvAfCj2QzoDCDrQAAAAASUVORK5CYII='
  data = '
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAA6QAAAOkAHc49yqAAAAGXRF
WHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAYFJREFUOI2l1L9LVWEcx/HXjaRMLRquJQi5
ZDlHe4M0REsNQqND/0AQ7bVas+Bi0BAKTtEWzYkRUaDiIoRDOfij8t5SvA3nq/fpeO85V/zA4ZznfD/f
9/P9nvM8D+W6iUksYwe/8AUvcK2D/EP14BX20YhrB/VkvBvg02WwPnyMpO94hMEkfhVPsR2et2XQuTB+
wKUC3zBWwvu8nWk0DN9QLeyjCf0pa3+4qLrxDmAHehY5E/lAJWaro/cYwOsB/FzJBar4gSWM4DymC0B/
8CAKqeFv/s+cinsjGV8pANaS50aS/x+wht84WwDKayiAi3niPt7jHO4eAzgW93etgvdjtmUMdAAbwHoU
c6OVoYL5gG6XQPsT78t2ptvY1NyvK7KWuhPPBTzEWngWZHv/iJ4ksA3Z1jsA17EYE+wm72e0WLNn8DqB
beJOtH8Pb2QnTSOJz+JWq6qq+JQkbOFxm8/Rj4ttYodaxZ7meTdTllCmKdlC3sNXWfsnUldAV3H5pLB/
foZsC5ZTyFQAAAAASUVORK5CYII='
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method restoreZoomIcon MicroBlocksEditor scale {
  dataRetina = '
iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAACXBIWXMAABx2AAAcdgH7OYqmAAAAGXRF
WHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAA0lJREFUWIXN2EmIXFUUBuCv2rY7QpRoYuIE
opDExAEcIhpdSYxCzMKFCgGDgsskIooiLnQZ0IWoILrRjQOYbRTbjRAhzrgSjUOjhKQXDh3b2Ind6XZx
q+hXp17Ve69eFe0PF+rUrfuf/95zh3OqYXBYhe3YgY24FGsxj2OYwhc4iEP4d4C+e2IzDmAOiyXbCTyP
1cMUtgZvSCtUVlhs03gGo4MWdx1+LnB+Cr9K4S2axAQuGJS4nZjJcTKH97AbF4cxI7gKj+GTLiJ/wIa6
4rZgNof8XayvwLNNOjB5IvteyUtwNBDO4sE++Ubxco7ICX3uyYlA9De29ikui305Ip+uSrItECzggQGI
a+GlwD+tQqgb+CwQvDhAcaSQfhl87C87+OYw8IThXLB3Bj9/4uwym/GeYL+C35uf12JvDVEnLa3URziM
W5v2KtxehuRr7TO7PtN3tc4NXqX9Fnw9HvpfKBI3ijOZAcekPTksgZtC/8dFIV4nvQItfN8c2MIUniia
ZQ/MBvuItCBnNe34InXgJu0zeqeGmLKYyvibGSn4cVzh+aFIakc2Tyw8xVPBvijYK3BtDTFz+CZjN4KP
40UEK7SH+EjoH/QhuSz0Hy4K8SlMZuz1uKJoVjWwPdjflrmoD2JPxt4pvZ2ki/ZQDUHTwY6PwvtlSO7W
vuyTGK8hqhs2aq9rTuPcMgPHpdQ9K3JPzxH94UDwUelKeyQM/kdK7QeF3YF/XioRSmMU3wWSMzr3TD+4
TTqMWe7X+yHaorP2XcDDNcTdL2XmcY+vqUp0Pj4MRNlw78VYBb4LpbRtIXD9hWuqitskVVtFl+4kHsWV
XXhGpCjsbwrJm2jHlmnELwJ24G2cl9OXzToifsQvUno2JlWEG6TsKA9Hca+U9pdCA081RcQwLErh3qrz
4PTTPtD5xvfEON60dAjyQtmqSUZwH37qQ9inuKOKMFIoYgWXPbEzUoIQMYa7pEK8m9h5fI5ncWNVYXCL
lN50E1fl3hvH5VIBdIOUGRclJj2xS/5/Ltn2ZB0HdfCc7vut1d5SfOKHhukewhalf6HOWS5x8FqOqNaK
Hpey3GXFSnylU9xpS1X+smOdTpEPLaegPKzEq/hDOjj/C/wH9uC4M441HhwAAAAASUVORK5CYII='
  data = '
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAA6QAAAOkAHc49yqAAAAGXRF
WHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAZVJREFUOI2l079rlEEQxvFPgmLEH40mZ8BC
C6O9pLKKSECxCugfIGhhKUiakMJesRSsBAtJwEZiF8RSUUQUNaY5EAuxMDF6OWO8s9h54+a8e99ABpZ5
991nvjuzO0u1jeIOFtDAD7zBLRzfQvyG7cF9tNCO0UAzm/8O8I4q2D68jKAvuIbD2fox3MD30Dyugj4M
4TPUSnQjWAztzV6iMyH4hMHSOv5BV6TyR7qleTX8NJZwugT2B09xG1O40inoi92a2BsZtktGI+JOxPx1
Z4YHA/RBao8mTlVkSGqpXzjaCewP3w7fQr0E2Mq+21n8JuAqfmLA1ks+EvP3nRm28ARncR6PcKkkw/Xw
F8PPdxNNxG4LGC6BFTaMr5HMyW6CPjwP6EoFdCjT3uslGpf6rzinRVzA7kyzH5fxOTQvpLf/n01msG/S
0yvAq3iHj1jL/s9Ib3+T7cKDDLaEc1H+BOakGy0gy5jFWLesBvEqC1jG9R7HUcOBHmsbVpeuv+irmaqA
KrsrNfI63krlb8t2BrSOQ9uF/QUd5IF+Y39L9AAAAABJRU5ErkJggg=='
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method zoomInIcon MicroBlocksEditor scale {
  dataRetina = '
iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAACXBIWXMAABx2AAAcdgH7OYqmAAAAGXRF
WHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAA2pJREFUWIXN2EuIXEUUBuCvx86MQtREo/ER
8EUePoigiWgUFxKjMLpwEUXBaECXKm4UcWE2QsCNaEBUUDc+wOguiuNCQSE+wZVoog5qcGZhdOKImZjJ
jIvqJtV1b/e91dNh/KHgHm6dU/+tU3Uet2FwWIYtGMVanI+zMYvfMIkvsQef4N8Brt0Tl2E3jmK+5jiE
Z3DmiSS2Aq8KO1SXWDqm8CSagya3Hj9VLD6DXwT3Vn3EGM4YFLnbMV2yyFG8jW04N9EZwjo8ik+7kNyP
NQsltxGHS4y/hdUZdjYLF6aMZN87eR4OJAYP494+7TXxfAnJMX2eybHE0N/Y1Ce5GA+XkHwi18jmxMAc
7qrQ2SXc0incXTH3ucT+lAxXN/B5YuDZGnqvRPPvq5jbxFfJGjvrErwmUTykXoDNIQg3J+v8iSVDNRRv
S+RdOFhDLxcfYm8kL8MN/RDcPTBKRbyTyKNVBJu4MpIn8M1AKXXivUTeUBVvVgpZoI3vhfPRxulCZinD
JdHzdThWMmdGp0f2tead1JLTjFTABp0H983k/eWKMSxn/F6y5mT0frqOi2PMVn3RABDXiUuqXDyZyOck
8h94uYvujULhCh8LeTbFdCI3kjUmKvg5WadL9lUpRMiNg7AqWW9vlYtnMB7Jq3FRBslcbEnkb+vEwT2J
3O3WDgJpzE3DTilu1bnt4xipoZfr4rU6+5ojOLXODn6EXyP5QjxYQy8XT+uMGu8qXqKueEDnLv4jlPa9
kLOD2xL7s0KLUBtNfJcYOaZ4ZmKsEpqr9VjeY971wmWMbb+UQ66NjYq97xy292OshTuFyjw94ytyDS3H
B4mh2N0PYTjD3llC2TaX2PoLV+SSu1TIAlV5dRyP4OIudoYEL+xsESn70MKRaVSQG8UbOK3kXVx1pPgB
PwtN+7DQEa4RqqMyHMAdQtlfCw083iKRumFecPcmxYvTz3hfMcf3xAhec/wSlLmy3ZMMYSt+7IPYZ7gp
hxjBFWkHF9/YaaEGTDGMW4RGvBvZWXyBp3B1LjG4VihvupGrinsxRnCBUElfJVTGdbJWV9yj/J9LPB5b
yAILwQ7dz1t7vK76xp8wTPUgNi/8hTplscjBiyWk2js6IeTURcVSfK1I7ohwyP8XWKlI8v7FJFSGpXhB
6NR2LC6V4/gPU86YtMg9uoAAAAAASUVORK5CYII='
  data = '
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAA6QAAAOkAHc49yqAAAAGXRF
WHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAaJJREFUOI2l1L1rVEEUBfDfihq/g8JGA4I2
Rq3FXkQsxEYLwT9AC0tB0lnYK5aCjYKFRBALsRPbKIqIQoxpAmKhFolRsxsTdi3mbjI+57mRXHgMM+fc
c++Zj0f/OIpbmMQ8fuAtbuDgKvKXYyvuoYNufPNoZ/PFEF7fT2w7XkXSZ1zG3gw/gGuYC86TfqIPg/gc
u//BG8FUcK/XkU4E4SOaFWwcYwXR75L9kXUFwUsxXsXXCjaAjZW1D7gpWb5YFWtEtTa2FYq9xqPC+iHJ
1ZtGBWjiC97jMHbgToYfl056POYLOB+NtPCrejK9Lehm830Z3rPbW2tlWDfL/0OwhZ/YVLBWZ3l/CE5U
FTt4hi04XUisi3MxPi2BZ6PaJIZX0eGwdBs6OFISbOBFiM5VRHdhMJsPZdy7de2fxIyV9zoVljZnnEFc
wKfgvJTe/l8xitkgzUhPryfcxkQUWMzWxxTu7ADuZ2KzOBX2z+CxdP+6Gf4Ax0pdNaXN7iV8w5Wa7RjC
zhpsOaaxZOV/V338/x23pYu8hHeS/TXFhhCdxp61iv0GkDZz2QEPwisAAAAASUVORK5CYII='
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method bunnyIcon MicroBlocksEditor scale {
  dataRetina = '
iVBORw0KGgoAAAANSUhEUgAAAEgAAABICAYAAABV7bNHAAAAAXNSR0IArs4c6QAAAAlwSFlzAAALEwAA
CxMBAJqcGAAAAVlpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRv
YmU6bnM6bWV0YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDUuNC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRm
PSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpE
ZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFk
b2JlLmNvbS90aWZmLzEuMC8iPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVu
dGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4K
TMInWQAAEIhJREFUeAHdXAeQVFUW/ROAUTCBZJC4rDiyarlYiogwAmKJirqKpEUoQDFgQLQMqJhRCiOW
CpIkLCoYMayCJJUsLCAgMENmyEEEptPbc+68++tPT7dMT890z/iqfr//X77n33fffffd346ToPD000+n
oqv0k3V3yy23pEUrZ4xJOVn9ks5PSIdt27ZNnzNnToCDB5EZL7zwQrP09PS8Rx55ZL0SRGA++ugjPgY1
7f3336+zefPm2qFQqGG1atVWPvjggxsJEoLRMuU6tlxDznGmT59eu3fv3sNxm40rdMUVV5ghQ4Z0ZB4A
zGDM8Nprr/29R48ew+rVq7cEj7/jMqeccopp06ZN4JlnnmnJMpbLeFt+A8Bxp9Pjjz8+AJQcwGUAgAEn
kAPM888/304pfO+99zI7dOgwBc/kIPPwww+bGTNmmNWrV5vHHntM0kaNGvXXAEjBwXSofNNNN80gwQ89
9JDZunVrHtLyBgwYYKpUqfKdggMwBuM+UL16dTN58mSzc+dOH8r5cQUDgUBely5dTIsWLSbb8pRR5TdQ
3nD0a9asqdqpU6fVuDVffvmlD3IkCILNqlWrKItMnz59urHc7bffPo7PTz75pNm/fz8BDLFcMCjFQ199
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
'
  data = '
iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAAAlwSFlzAAALEwAA
CxMBAJqcGAAAAVlpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRv
YmU6bnM6bWV0YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDUuNC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRm
PSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpE
ZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFk
b2JlLmNvbS90aWZmLzEuMC8iPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVu
dGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4K
TMInWQAABmlJREFUWAmtWFtolEcUnt1cLGmK0kvWSmIjiNi8KJgGDWq0okUhitJCoC1IQNMmUCtYii2I
D4U8SPHBkrRaioRCJdoGETSKxJpUqYlpNSohMSqJuWiqMYm57m36fZM565+su9nVHJidmTNnzvnmzJyZ
869S8VGiQzxt7969b6DvcvBS0X734MGDcyzPOeYQm5mmgHk7PT3956KiIr1y5cofreoVqH8tLS1tR9FZ
WVnfW77MmRkEDi2i+P0dO3YMPH78WFdXV2uMf4DyVXl5ue7t7dWkEydOkJ9n5ybYekYrAfMetkj7/X5j
eN++fQ2w8u358+dNHz+j4+PjevPmzX/NqPUpyuQMJG/durV1eHiYxkfpIcj9uX///k6Lhii9HR0d5JdS
x7Jly5JYzzSJd76or6+n7XH+tLa20nBTbW2t6ft8viDYvmvXrpH/iQUhc+PC5I4mDSMBjn8EWrJkCZvm
TAwMDATRHkxNTXWeEZfX66XMMH9elKIBcrtcLq7Yk5OTk5WcnKwA0GwhzooffG7XpPmBgMHvBBk3rkkK
nbNxPqQ7e+7cua+yEwwGDSCcJXYHx8bG6Ckh19OnT9keE8aL1LEACjB6nMoBjPNGsHXGJdaT7sHBQYp1
W9lJcyxv2ioiIMfMof7+fuMSt9ttjAAg57XBIyOUE/6jR48o10seaMYBicL/uru7e2gBnjBbNDQ0NI5u
E/jGJcJ/+PBhH/j9lAXJ/IlejL/RPKQRXDygwStXrrQCBFUaQPfv3+c5udHe3t5BJijIA41+M9pGEPcQ
w/6lDjgVTyW5S75paWlBUOlRhLbeuXNnjRX8CV4hf+TOnTv0SAVKCorzUiSoaAvH8DMSg884z2/9fevW
LbVo0aKke/fuqcOHD3sKCgp+x1atwPlSaWlpr3DaoUOHClDlNzc3d5WVldWh/QsKnxgSgZkgML0X+cHK
5el4De+YeSYAwE9vMfIQbfQOKlOzbQjbp3t6evSRI0foNYJKtvZffgvXrFkjXizr6uqiQR+KeSpsTV4I
nOWZt43ttrY2vWrVqn+gR3KkmLcvqhPXrVtX8+TJE9rGg+83AKZ6hoPksdBLqAl8rLOzU2dmZtY6DIjn
HazYmuKdD0+fPk17fmuE7WmJeGy6Mnb58mVu39fWrOiNDYVIwaJZyaZNmy7Z1MM3sehpsYQErHyAjD17
9vCeesvqj2/r7B3EuXnHjh2jvkA83uEEIW4fyHv9+nV66UsqdZxNdmMiiYgf7GH2WsViJ+baesnHyNy2
bZu5wzCZ3g87S5HcRkFzZxQWFubgnuEKcO2EzWdKYgoFhACAmYF0pXYzhVm+fDkTqzehi94KUxgJkCiZ
PX/+/PTERHMGw2QJhiBZ2CaxxmNriijhOAAa4/hieR38d+xYzIBEMBFZYegZoGIhAcMskfmRNWpqpLLq
3LlzIuqsg3PmmOuIoEjPFE70I74xE8vFtsFY6LoXL3CutCsrK9Xq1avNFtEzpJs3byryhQQ8+q7R0VGy
TdqCWuyQF5VCyPEd1ogkHjrNHcR6Et29e1cjGwhdiDzAvHueEwAm1PDeMWfKsNbDjkE0VBJl5ch7CGJS
lPHVdxI/gfg1W1JSom0GEBq2sj4C3b59e73DaGjhwouIEPeQyFTW1dWxbWQlem7fvq1qakwEG7mMjAy1
ceNGtXjxYr7+hseUtqqqSkkuhUdZHT16tIqD9h6KecuMQvyYFWRnZ9f09fVxxZO81NTUpI8fP64bGxs1
En599epVferUKQ0gGmDNZzVffZCfW7hr165pb2rZFgEwtea4xpb9O2vWrM/Wrl2bgGiC7gDOr1t5PB61
cOFC9eDBA1VRUaHoETyk6uzZsyo3N1fl5eUpRCm9EDh58mTC7t27S9C+hMJ7JBQsaIdoOkBUxsk9Fy9e
7FiwYMGWpUuXEowPoBKwcpWUlKTmzZunkDEaMOzjrlHr16/nFUCjQTysSRs2bOA/Jd+hcOufCwb8mEmA
f37gwAE9MjJitgE/DD9GTxBeZO4TRFizT76XEQfPcFHlDkthB9kxFldTQOVitY1nzpzRyB5hN5wASjc0
NOji4mJ+rXzqsBIxiEQmXrTcPn5Gk7bgj6mP8/Pzs/G8eFJSUhSAuPkphD8hbly4cOEPyPyGws9ZAqGn
WKJSvICojJ5yngEm+B4U6mJhJA2gCDkXIbyI9f8PmQ4SvBAaOwAAAABJRU5ErkJggg=='
  if (2 == scale) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}

method logoAndText MicroBlocksEditor {
  dataRetina = '
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
QmCC'
  data = '
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'
  if (2 == (global 'scale')) { data = dataRetina }
  return (readFrom (new 'PNGReader') (base64Decode data))
}
