#= require jasmine.HeadlessReporter

elapsed = (startTime, endTime)->
  (endTime - startTime)/1000

ISODateString = (d)->
  pad = (n)-> if n < 10 then '0'+n else n
  [
    d.getFullYear() + '-'
    pad(d.getMonth()+1) + '-'
    pad(d.getDate()) + 'T'
    pad(d.getHours()) + ':'
    pad(d.getMinutes()) + ':'
    pad(d.getSeconds())
  ].join('')
  

trim = (str)->
  str.replace(/^\s+/, "" ).replace(/\s+$/, "" )
  
escapeInvalidXmlChars = (str)->
  str.replace(/\&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/\>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/\'/g, "&apos;");

class jasmine.HeadlessReporter.JUnit extends jasmine.HeadlessReporter
  constructor: (@outputTarget = null) ->
    super(@outputTarget)
    
    # savePath where to save the files
    # consolidate whether to save nested describes within the
    #                  same file as their parent; default: true
    # useDotNotation whether to separate suite names with
    #                  dots rather than spaces (ie "Class.init" not
    #                  "Class init"); default: true
    @savePath = "spec/reports"
    @consolidate = true
    @useDotNotation = true
    
  @finished_at: null

  reportSpecStarting: (spec)->
    super
    spec.startTime = new Date()
    spec.suite.startTime ?= spec.startTime

  reportSpecResults: (spec)->
    super
    @length++
    
    results = spec.results()
    spec.didFail = !results.passed()
    spec.duration = elapsed(spec.startTime, new Date())
    outs = []
    outs.push "<testcase classname=\"#{this.getFullName(spec.suite)}\""
    outs.push " name=\"#{escapeInvalidXmlChars(spec.description)}\" time=\"#{spec.duration}\">"

    failure = [];
    failures = 0;
    resultItems = results.getItems();
    for result in resultItems
      if result.type == 'expect' && result.passed && !result.passed()
        failures += 1;
        failure.push "#{failures}: #{escapeInvalidXmlChars(result.message)} "

    if failures > 0
      @failedCount++
      outs.push "<failure>#{trim(failure.join(''))}</failure>"
    outs.push  "</testcase>"
    spec.output = outs.join('')

  reportSuiteResults: (suite)->
    super
    results = suite.results()
    specs = suite.specs()
    specOutput = []
    # for JUnit results, let's only include directly failed tests (not nested suites')
    failedCount = 0

    suite.status = if results.passed() then 'Passed.' else 'Failed.'
    
    if results.totalCount == 0 # todo: change this to check results.skipped
      suite.status = 'Skipped.'

    # if a suite has no (active?) specs, reportSpecStarting is never called
    # and thus the suite has no startTime -- account for that here
    suite.startTime = suite.startTime || new Date();
    suite.duration = elapsed(suite.startTime, new Date())

    for spec in specs
      failedCount += 1 if spec.didFail
      specOutput.push spec.output
    
    outs = []
    outs.push '\n<testsuite name="' + this.getFullName(suite)
    outs.push '" errors="0" tests="' + specs.length + '" failures="' + failedCount
    outs.push '" time="' + suite.duration + '" timestamp="' + ISODateString(suite.startTime) + '">'
    outs.push specOutput.join("\n  ")
    outs.push "\n</testsuite>"
    suite.output = outs.join('')

  reportRunnerResults: (runner)->
    super
    suites = runner.suites()
    for suite in suites
      fileName = 'TEST-' + this.getFullName(suite, true) + '.xml'
      output = []
      output.push '<?xml version="1.0" encoding="UTF-8" ?>'
      # if we are consolidating, only write out top-level suites
      continue if @consolidate && suite.parentSuite
      if @consolidate
        output.push "\n<testsuites>"
        output.push @getNestedOutput(suite)
        output.push "\n</testsuites>"
        @writeFile(@savePath + fileName, output.join(''))
      else
        output.push suite.output
        @writeFile(@savePath + fileName, output)
        
      @constructor.finished_at = (new Date()).getTime()

  getNestedOutput: (suite)->
    output = []
    output.push suite.output
    for sub_suites in suite.suites()
      output.push @getNestedOutput(sub_suites)
    output.join('')

  writeFile: (filename, text)->
    JHW.writeFile(filename, text)
  
  getFullName: (suite, isFilename)->
      if @useDotNotation
        fullName = suite.description
        parentSuite = suite.parentSuite
        
        while parentSuite
          fullName = parentSuite.description + '.' + fullName
          parentSuite = parentSuite.parentSuite
          for (var ; parentSuite; ) {
      else
        fullName = suite.getFullName()

      # Either remove or escape invalid XML characters
      if isFilename
        fullName.replace(/[^\w]/g, "")
      else
        escapeInvalidXmlChars(fullName)
        
  log: (str)->
    @puts str
