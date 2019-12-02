/*
  Dynapath Generic Post Processor
  License: GPLv2

  Original author: Chris Purola
*/

/*
  Additional Info:
  This script uses writeWords2 as the Dynapath controllers only allow lines
  containing sequence numbers, thus this is the recommended method.

  Dynapath controllers do not have concept of comment lines and they must
  be omitted.

  Text is a maximum of 16 characters of uppercase-only A-Z 0-9, + and .
  Tool numbers are 00-99, with Diameter and Height offsets 000-200
*/

// ************************************
//  Global needed values for the Post
// ************************************
setCodePage("ascii");

var defaultMachineVendor = "Autocon, Inc";
var defaultMachineModel = "DynaPath 50M";
var defaultMachineDescription = "DynaPath 50M Control System on 3-axis mill";

allowedCircularPlanes = "xyz";
allowHelicalMoves = true;
allowSpiralMoves = true;
capabilities = "CAPABILITY_MILLING";
description = "Dynapath Generic Post Processor (Milling)";
longDescription = "Dynapath (10/20/30/40/50) Milling Post-Processor";
extension = "nc";
programNameIsInteger = false;
tolerance = 0.0001;

// Current state
var sequenceNumber;

// ******************************************************************
//  User-accessible properties in the post configuration setup page
// ******************************************************************
properties = {
  useConversational: true,
  forceInitialToolChange: false,
  useHDToolTable: false,
  useM06ForToolChange: true,
  startSequenceNumber: 1.000,
  // Dynapath control has support to 9999.999 or 10M lines
  incrementSequenceAmount: 0.001,
  realTolerance: 0.0001
};
// ****************************************************
//  User-friendly definitions of the above properties
// ****************************************************
propertyDefinitions = {
  useConversational: {
    title: "Use Conversational",
    description: "By default, the DynaPath controller uses a conversational " +
    "method of storing programs. This allows easy editing of program on the " +
    "onboard editor. The post processor can output in this conversational " +
    "language, or in standard EIA/ISO G-Code.",
    type: "boolean"
  },
  forceInitialToolChange: {
    title: "Force Initial Tool Change",
    description: "Force a full tool change cycle on first programmed tool",
    type: "boolean"
  },
  useHDToolTable: {
    title: "Use H and D Tool Numbers",
    description: "Some Dynapath controls are set up to use H (height) and " +
    "D(diameter) settings as well as T (tool). Use this to output T, H, and D " +
    "numbers corresponding to the selected tool if using controller-based height " +
    "and/or radius compensation.",
    type: "boolean"
  },
  useM06ForToolChange: {
    title: "Use M06 for Tool Change",
    description: "If programmed, M06 will call a controller-run subroutine to " +
    "initiate a toolchange operation. Setting this will call M06 for every " +
    "requested tool change.",
    type: "boolean"
  },
  startSequenceNumber: {
    title: "Start Sequenece Number",
    description: "Beginning sequence number to use. Setting this greater than 0 " +
    "allows adding events before program later. Keep in mind the controller has " +
    "a maximum sequence number of 9999.999. (0-9999)",
    type: "number"
  },
  incrementSequenceAmount: {
    title: "Incremental Sequence Number Amount",
    description: "Amount to increment the sequence number for each line in the " +
    "program. This can vary if other commands will be inserted without the need " +
    "for renumbering the entire program.",
    type: "number"
  },
  realTolerance: {
    title: "Tolerance for calculations",
    description: "Smallest increment the machine can produce, numbers will be " +
    "truncated to this size when calculating.",
    type: "number"
  }
};


// ************************
//  Helper functions
// ************************
function incSequence() {
  // If the max valid sequence number is reached
  if (sequenceNumber >= 9999.999) {
    // Reset back to default start
    sequenceNumber = properties.sequenceNumberStart;
  } else {
    sequenceNumber += properties.sequenceNumberIncrement;
  }
}


// *************************
//  Format Definitions
// *************************

// N Number sequence
var sequenceFormat = createFormat({decimals:3, forceDecimal:true});
// T tool specifier
var toolTFormat = createFormat({decimals:0, zeropad:true, width:2});
// H and D tool specifiers
var toolHDFormat = createFormat({decimals:0, zeropad:true, width:3})

// *************************
//  Format Functions
// *************************

// Format comments (output text)
function formatComment(text) {
  // Delete all the non-accepted characters, uppercase and truncate
  var fixedString = String(text).replace(/[^a-zA-Z0-9\+\.]/gi, "");
  return fixedString.substr(0,15).toUpperCase();
  };
}

// ************************
//  Writer functions
// ************************
function writeComment(text) {
  writeWords2("N" + sequenceFormat.format(sequenceNumber)),
    "(T)", formatComment(text), "$");
  incSequence();
}

function writeTool(tool) {
  if (useM06ForToolChange) {
    writeWords2("N" + sequenceFormat.format(sequenceNumber)),
    "(9)M06"
  }
}
