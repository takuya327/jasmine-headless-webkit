env = null
spec = null
suite = null
reporter = null
runner = null

fakeSpec = (suite, name)->
  s = new jasmine.Spec(env, suite, name)
  suite.add(s)
  s

fakeSuite = (name, parentSuite)->
  s = new jasmine.Suite(env, name, null, parentSuite || null)
  parentSuite.add(s) if (parentSuite)
  runner.add(s)
  s

# make sure reporter is set before calling this
triggerSuiteEvents = (suites)->
  for s in suites
    for ss in s.specs()
      reporter.reportSpecStarting(ss)
      reporter.reportSpecResults(ss)
    reporter.reportSuiteResults(s)

describe "jasmine.HeadlessReporter.JUnit", ->
  beforeEach ->
    env = new jasmine.Env()
    env.updateInterval = 0
    runner = new jasmine.Runner(env)
    suite = fakeSuite("ParentSuite")
    spec = fakeSpec(suite, "should be a dummy with invalid characters: & < > \" '")
    reporter = new jasmine.HeadlessReporter.JUnit )

  describe "constructor", ->
    it "should default path to spec/reports", ->
      expect(reporter.savePath).toEqual("spec/reports")

    it "should default consolidate to true", ->
      expect(reporter.consolidate).toBe(true)

    it "should default useDotNotation to true", ->
      expect(reporter.useDotNotation).toBe(true)

  describe "reportSpecStarting", ->
    it "should add start time", ->
      reporter.reportSpecStarting(spec)
      expect(spec.startTime).not.toBeUndefined()

    it "shound add start time to the suite", ->
      expect(suite.startTime).toBeUndefined()
      reporter.reportSpecStarting(spec)
      expect(suite.startTime).not.toBeUndefined()

    it "should not add start time to the suite if it already exists", ->
      a = new Date()
      suite.startTime = a
      reporter.reportSpecStarting(spec)
      expect(suite.startTime).toBe(a)

  describe "reportSpecResults", ->
    beforeEach ->
      reporter.reportSpecStarting(spec)
      # spec.results_ = fakeResults()
      reporter.reportSpecResults(spec)

    it "should compute duration", ->
      expect(spec.duration).not.toBeUndefined()

    it "should generate <testcase> output", ->
      expect(spec.output).not.toBeUndefined()
      expect(spec.output).toContain("<testcase")

    it "should escape bad xml characters in spec description", ->
      expect(spec.output).toContain("&amp; &lt; &gt; &quot; &apos;")

    it "should generate valid xml <failure> output if test failed", ->
      # this one takes a bit of setup to pretend a failure
      spec = fakeSpec(suite, "should be a dummy")
      reporter.reportSpecStarting(spec)
      expectationResult = new jasmine.ExpectationResult(
        matcherName: "toEqual"
        passed: false
        message: "Expected 'a' to equal '&'."
      )
      results = {
        passed: -> false
        getItems: -> [expectationResult]
      }
      spyOn(spec, "results").andReturn(results)
      
      reporter.reportSpecResults(spec)
      expect(spec.output).toContain("<failure>")
      expect(spec.output).toContain("to equal &apos;&amp;")

  describe "reportSuiteResults", ->
    beforeEach ->
      triggerSuiteEvents([suite])
    
    it "should compute duration", ->
      expect(suite.duration).not.toBeUndefined()
      
    it "should generate startTime if no specs were executed", ->
      suite = fakeSuite("just a fake suite")
      triggerSuiteEvents([suite])
      expect(suite.startTime).not.toBeUndefined()
    
    it "should generate <testsuite> output", ->
      expect(suite.output).not.toBeUndefined()
      expect(suite.output).toContain("<testsuite")
    
    it "should contain <testcase> output from specs", ->
      expect(suite.output).toContain("<testcase")

  describe "reportRunnerResults", ->
    subSuite = null
    subSubSuite = null
    siblingSuite = null

    beforeEach ->
      subSuite = fakeSuite("SubSuite", suite)
      subSubSuite = fakeSuite("SubSubSuite", subSuite)
      siblingSuite = fakeSuite("SiblingSuite With Invalid Chars & < > \" ' | : \\ /")
      subSpec = fakeSpec(subSuite, "should be one level down")
      subSubSpec = fakeSpec(subSubSuite, "should be two levels down")
      siblingSpec = fakeSpec(siblingSuite, "should be a sibling of Parent")

      spyOn(reporter, "writeFile")
      spyOn(reporter, "getNestedOutput").andCallThrough()
      triggerSuiteEvents([suite, subSuite, subSubSuite, siblingSuite])

    describe "general functionality", ->
      beforeEach ->
        reporter.reportRunnerResults(runner)
        
      it "should remove invalid filename chars from the filename", ->
        expect(reporter.writeFile).toHaveBeenCalledWith("TEST-SiblingSuiteWithInvalidChars.xml", jasmine.any(String))
        
      it "should remove invalid xml chars from the classname", ->
        expect(siblingSuite.output).toContain("SiblingSuite With Invalid Chars &amp; &lt; &gt; &quot; &apos; | : \\ /")

    describe "consolidated is true", ->
      
      beforeEach ->
        reporter.reportRunnerResults(runner)
        
      it "should write one file per parent suite", ->
        expect(reporter.writeFile.callCount).toEqual(2)
        
      it "should consolidate suite output", ->
        expect(reporter.getNestedOutput.callCount).toEqual(4)
        
      it "should wrap output in <testsuites>", ->
        expect(reporter.writeFile.mostRecentCall.args[1]).toContain("<testsuites>")
        
      it "should include xml header in every file", ->
        for i in [0..reporter.writeFile.callCount]
          expect(reporter.writeFile.argsForCall[i][1]).toContain("<?xml")

    describe "consolidated is false", ->
      beforeEach ->
        reporter.consolidate = false
        reporter.reportRunnerResults(runner)
        
      it "should write one file per suite", ->
        expect(reporter.writeFile.callCount).toEqual(4)
        
      it "should not wrap results in <testsuites>", ->
        expect(reporter.writeFile.mostRecentCall.args[1]).not.toContain("<testsuites>")
        
      it "should include xml header in every file", ->
        for i in [0..reporter.writeFile.callCount]
          expect(reporter.writeFile.argsForCall[i][1]).toContain("<?xml")


    describe "dot notation is true", ->
      beforeEach ->
        reporter.reportRunnerResults(runner)
        
      it "should separate descriptions with dot notation", ->
        expect(subSubSuite.output).toContain('classname="ParentSuite.SubSuite.SubSubSuite"')

    describe "dot notation is false", ->
      beforeEach ->
        reporter.useDotNotation = false
        triggerSuiteEvents([suite, subSuite, subSubSuite, siblingSuite])
        reporter.reportRunnerResults(runner)
        
      it "should separate descriptions with whitespace", ->
        expect(subSubSuite.output).toContain('classname="ParentSuite SubSuite SubSubSuite"')
