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

// Position for manual tool change operation. Machine coordinate relative.
var toolChangePosition = {x: 14, y: 1, z: 14}

allowedCircularPlanes = undefined;
allowHelicalMoves = true;
allowSpiralMoves = true;
capabilities = CAPABILITY_MILLING;
certificationLevel = 2;
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
  realTolerance: 0.0001,
  useWordSeparator: false
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
    "D (diameter) settings as well as T (tool). Use this to output T, H, and D " +
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
  },
  useWordSeparator: {
    title: "Use Spaces Between Words",
    description: "Insert spaces between codes within the block to improve readability",
    type: "boolean"
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
    sequenceNumber += properties.incrementSequenceAmount;
  }
}

function writeBlock() {
  writeWords2("N" + (sequenceFormat.format(sequenceNumber)), arguments, "$");
  incSequence();
}



// *************************
//  Format Definitions
// *************************

// N Number sequence
var sequenceFormat = createFormat({decimals:3, trim:false, forceDecimal:true});
// T tool specifier
var toolTFormat = createFormat({decimals:0, zeropad:true, width:2});
// H and D tool specifiers
var toolHDFormat = createFormat({decimals:0, zeropad:true, width:3});
// Unit format
var unitOutputFormat = createFormat({decimals:0});



// *************************
//  Modal Variables
// *************************
var unitOutput = createVariable({prefix: "P"}, unitOutputFormat);



// *************************
//  Format Functions
// *************************

// Format comments (output text)
function formatComment(text) {
  // Delete all the non-accepted characters, uppercase and truncate
  var fixedString = String(text).replace(/[^a-zA-Z0-9\+\.]/gi, "");
  return fixedString.substr(0,15).toUpperCase();
}

// Format tool identifiers
function formatTool(toolNum) {
  if (properties.useHDToolTable) {
    return "T" + toolTFormat.format(toolNum) +
           "H" + toolHDFormat.format(toolNum) +
           "D" + toolHDFormat.format(toolNum)
  } else {
    return "T" + toolTFormat.format(toolNum)
  }
}


// ************************
//  Writer functions
// ************************
function writeComment(text) {
  writeBlock("(T)", formatComment(text));
}

function writeTool(tool) {
  if (properties.useM06ForToolChange) {
    // Call toolchange function
    writeBlock("(9)", "M06", formatTool(tool));
  } else {
    writeBlock("(9)", formatTool(tool));
  }
}

function writeCoolant(coolant) {
  if (coolant) {
    writeBlock("(9)", "M08");
  } else {
    writeBlock("(9)", "M09");
  }
}

// Write spindle on/off/speed codes
// writeSpindle(true,false)
function writeSpindle(spindle) {
  // Turn on spindle
  if (spindle) {
    if (tool.clockwise) {
      writeBlock("(9)", "M03", "S" + tool.spindleRPM);
    } else {
      writeBlock("(9)", "M04", "S" + tool.spindleRPM);
    }
  } else {
    // Spindle off
    writeBlock("(9)", "M05");
  }
}

// Pause for specified seconds (.1 to 999)
// (spindle spin up, coolant start, etc)
function writeDwell(time) {
  writeBlock("(8)", "L" + time);
}

// Write units
function writeUnits(metric) {
  writeBlock("(S)", metric);
}


// ****************************
//  Sequenced event functions
// ****************************
// Depending on how your controller is programmed and configured,
// you may need to alter the sequence of events by adding or subtracting
// blocks from these sequences.

function changeTool(tool) {
  if (properties.useM06ForToolChange) {
    // Automated tool change
    // Coolant off
    writeCoolant(false);
    // Tell the operator what tool to load
    writeComment(tool.getProductId());
    // Change tool
    writeTool(tool.getNumber());
    //Spindle on
    writeSpindle(true);
    // Coolant on
    writeCoolant(tool.getCoolant());
    // Optionally dwell to allow spindle and coolant to get going
    //writeDwell(2)
  } else {
    // Manual tool change
  }
};


// ****************************
//  Main event handlers
// ****************************
function onOpen() {
  // Handle word separators
  if (properties.useWordSeparator) {
    setWordSeparator(" ");
  } else {
    setWordSeparator("");
  }
  // Set starting sequence
  sequenceNumber = properties.startSequenceNumber;
}

function onSection() {
  // Check and set units
  if (currentSection.hasParameter("operation:metric")) {
    writeUnits(unitOutput.format(currentSection.getParameter("operation:metric")));
  }
}
