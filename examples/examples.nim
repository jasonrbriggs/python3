
## Various Python 3 examples

import python3
import os, strutils


## Very high level python binding examples
proc getPythonVersion() =
  let pythonString = "import sys\nprint(sys.version)"
  # Set program name in python (recommended)
  setProgramName("get Python3 version string")
  # Initialize the Python interpreter
  initialize()
  # Execute the string script
  if runSimpleString(pythonString) == -1:
    echo("Exception occured in Python script!")
  # Close and delete the Python interpreter
  finalize()

proc Example1() =
  ## Run an interactive Python interpreter in a Nim console application
  let
    applicationName = os.getAppFilename()
    arguments = os.commandLineParams()
  var
    cArgumentList: seq[WideCString] = newSeq[WideCString]()
    returnValue: int   
  # Add application arguments to the C wchar_t argument list
  cArgumentList.add(newWideCString(applicationName))
  for arg in arguments:
    cArgumentList.add(newWideCString(arg))
  # Run the interpreter by passing it the application arguments
  returnValue = main(cArgumentList.len, addr(cArgumentList[0]))
  if returnValue == 1:
    echo("Exception occured!")
  elif returnValue == 2:
    echo("Invalid parameter list passed to the Python interpreter!")

proc Example2() =
  ## Executing a python script from a file
  var
    fileName: string = "script_example1.py"
  # Set program name in python (recommended)
  setProgramName("Example 2 ŽĆČŠĐ ŁĄŻĘĆŃŚŹ ЯБГДЖЙ ÄäÜüß")
  # Initialize the Python interpreter
  initialize()
  # Execute the script
  if runAnyFile(fileName) == -1:
    echo("Exception occured in Python script!")
  # Display program name
  echo getProgramName()
  # Close and delete the Python interpreter
  finalize()

proc Example3() =
  ## Executing a python script from a string
  # Setup the string variable with some python code
  var pythonString = "import time\nprint('Today is ', time.ctime(time.time()))"
  # Initialize the Python interpreter
  initialize()
  # Execute the string script
  if runSimpleString(pythonString) == -1:
    echo("Exception occured in Python script!")
  # Close and delete the Python interpreter
  finalize()

proc Example4() =
  ## Example of binding a hook to a Nim procedure
  ## !! THE HOOK PROCEDURE HAS TO HAVE THE SAME SIGNITURE !!
  ## !! AS SPECIFIED BY THE PYTHON DOCUMENTATION          !!
  proc procBoundToHook(): int{.cdecl.} =
    echo "HOOK EXECUTED!"
  # Set the hook(function pointer) to point to the custom procedure
  osInputHook[] = procBoundToHook
  # Run the interpreter and see the hook executed every time 
  # the interpreter prompts for the users input
  Example1()

proc Example5() =
  ## Simple example of an Exception in a python script
  # Initialize the Python interpreter
  initialize()
  # Variable Initialization
  var
    pythonString: cstring = "import time\nd=\nprint('Today is ', time.ctime(time.time()))"
    pyGlobals: PyObjectPtr = moduleGetDict(importAddModule("__main__"))
    pyLocals: PyObjectPtr = pyGlobals
  # Check globals, locals dictionaries and run the python string
  if pyGlobals == nil or pyLocals == nil:
    echo("Error creating globals and locals dictionaries")
  elif runString(pythonString, pyFileInput, pyGlobals, pyLocals) == nil:
    echo("Exception occured in Python script!")
  # Close and delete the Python interpreter
  finalize()


## Pure Embedding (C example translation)
## https://docs.python.org/3.4/extending/embedding.html#pure-embedding
proc Example6() =
  ## Import a python module from a file and execute a function from it.
  ## How to run the example: 
  ##   - compile this file
  ##   - run in console: $ python_example example_module multiply 2 3
  ##   - make sure that the example_module.py file is in the same directory as the executable
  # Application parameters
  let
    applicationName = os.getAppFilename()
    arguments = os.commandLineParams()
    argumentCount = os.paramCount()
  # Variables
  var
    pName, pModule, pDict, pFunc, pArgs, pValue: PyObjectPtr
  # Check command line arguments
  if len(arguments) < 2:
    quit "Usage: call pythonfile funcname [args]"
  # Initialize the Python interpreter
  initialize()
  # Get the app name into a python object
  pName = unicodeFromString(arguments[0]) # Error checking of pName left out
  #echo PyBytes_AsString(PyUnicode_AsASCIIString(pName))
  pModule = importImport(pName)
  decref(pName)
  # Check if module was loaded
  if pModule != nil:
    pFunc = objectGetAttrString(pModule, arguments[1]) # pFunc is a new reference
    if pFunc != nil and callableCheck(pFunc) != 0:
      var countStart = argumentCount - 2
      pArgs = tupleNew(countStart)
      for i in 0..(countStart-1):
        pValue = longFromLong(clong(parseInt(arguments[i + 2])))
        # Check if parameter value is valid
        if pValue == nil:
          decref(pArgs)
          decref(pModule)
          quit "Cannot convert argument number: $1" % $i
        # pValue reference stolen here:
        if tupleSetItem(pArgs, i, pValue) != 0:
          quit "Cannot insert tuple item: $1" % $i
      pValue = objectCallObject(pFunc, pArgs)
      decref(pArgs)
      if pValue != nil:
        echo "Result of call: $1" % $longAsLong(pValue)
        decref(pValue)
      else:
        decref(pFunc)
        decref(pModule)
        errPrint()
        quit "Call failed!"
    else:
      if errOccurred() != nil:
        errPrint()
      quit "Cannot find function '$1'\n" % arguments[1]
  else:
    errPrint();
    quit "Failed to load '$1'" % arguments[0]
  # Close and delete the Python interpreter
  finalize()


## Extending Embedded Python (C example translation)
## https://docs.python.org/3.4/extending/embedding.html#extending-embedded-python
var
  numargs: cint
  EmbMethods: array[2, PyMethodDef]
  EmbModule: PyModuleDef
  
proc emb_numargs(self: PyObjectPtr; args: PyObjectPtr): PyObjectPtr {.cdecl.} =
  if argParseTuple(args, ":numargs") == 0:
    return nil
  return longFromLong(numargs)

template pyObjectHeadInit(typ) =
  PyObject(
    ob_refcnt: 1,
    ob_type: typ
  )

template pyModuleDefHeadInit() =
  PyModuleDefBase(
    ob_base: pyObjectHeadInit(nil),
    m_init: nil,
    m_index: 0,
    m_copy: nil
  )

EmbMethods = [
  PyMethodDef(
    ml_name: "numargs", 
    ml_meth: emb_numargs, 
    ml_flags: methVarargs, 
    ml_doc: "Return the number of arguments received by the process."
  ),
  PyMethodDef(
    ml_name: nil, 
    ml_meth: nil, 
    ml_flags: 0, 
    ml_doc: nil
  )
]

EmbModule = PyModuleDef(
    m_base: pyModuleDefHeadInit(),
    m_name: "emb",
    m_doc: "Nim's embedded Python module",
    m_size: -1,
    m_methods: cast[PyMethodDefPtr](addr(EmbMethods[0])),
    m_reload: nil,
    m_traverse: nil,
    m_clear: nil,
    m_free: nil,
)

proc pyInitEmb(): PyObjectPtr {.cdecl.} =
  return moduleCreate(addr(EmbModule))
  
proc Example7() =
  # Application parameters
  let
    applicationName = os.getAppFilename()
    arguments = os.commandLineParams()
    argumentCount = os.paramCount()
    fileName = "script_example2.py"
  numargs = argumentCount.cint()
  if importAppendInittab("emb", pyInitEmb) == -1:
    quit "Could not add module 'emb'!"
  # Initialize the Python interpreter
  initialize()
  # Execute the script
  if runAnyFile(fileName) == -1:
    echo("Exception occured in Python script!")
  # Close and delete the Python interpreter
  finalize()


## Run one of the examples
getPythonVersion()
#Example1()
#Example2()
#Example3()
#Example4()
#Example5()
#Example6()
#Example7()


