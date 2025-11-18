# TVPaint Data Nodes

## Overview

The TVPaint data nodes for Blackmagic Design Resolve Studio/Fusion Studio allow you to interact with 2D animation data inside a node graph. This approach works with a series of nodal operators that allow you to edit and modify the TVPaint JSON data on the fly.

This TVPaint implementation is based around the "ScriptVal" datatype in Fusion, and works using ideas pioneered by the Vonk Ultra data node project.

## Software Requirements

To run TVPaint based workflows on your Resolve/Fusion system you will need the following tools:

- BMD Resolve Studio or Fusion Studio v18.5 - v20+
- Reactor Package Manager (Free)
- Vonk Ultra Data Nodes (via Reactor)

## Open Source Software License Term

- LGPL/GPL v3

## Installation

1. Install the Reactor Package Manager for Resolve/Fusion.

2. Install the Reactor package named "Vonk Ultra" that is found in the "Kartaverse/Vonk Ultra" category in the Reactor window.

3. Install the Reactor package named "TVPaint Data Nodes" that is found in the "Kartaverse/TVPaint" category in the Reactor window.

4. Quit and relaunch Resolve/Fusion once for the fuse nodes to load.

## TVPaint Scripts

Look in the Fusion "Script/TVPaint" menu to see the automation scripts.

### TVPaint Build Comp

Auto-build a comp node-graph based upon the active TVPaintLoader node selection.

![TVPaint Build Comp Script](Docs/Images/script-tvpaint-build-comp.png)

#### Usage:

1. Add a TVPaintLoader node to your Fusion comp. Use the node's (Browse) button to select a TVPaint exported .json file on your hard disk. The JSON document's filepath will be entered into the Filename field.
2. Select the TVPaintLoader node in the node graph area.
3. Launch the "Scripts > TVPaint > TVPaint Build Comp " menu item. A dialog appears that allows you to customize the settings. Click the "Run" button to continue.
4. A TVPaint for Fusion nodegraph will be generated. Keep in mind, that a new undo state is created for you automatically so you can easily revert the changes made to your node graph.

### Remove Unselected Nodes

This script is used to quickly cleanup a comp when you are doing repetitive experiments. Any node that is unselected in the node graph will be instantly deleted. As a result, this will leave you with only the currently selected nodes in the comp.

An undo point is defined when the script is run so you can revert the changes easily.

#### Usage:

1. Select several nodes in the flow area.
2. Launch the "Scripts > Remove Unselected Nodes " menu item.
3. All non-selected nodes will be removed from the the node graph.

### Show Fuses Folder

Opens the "TVPaint for Fusion" Fuses folder in a desktop folder browsing window.

`Fuses:/Kartaverse/TVPaint/`

### Show Comps Folder

Opens the "TVPaint for Fusion" Comp examples folder in a desktop folder browsing window.

`Reactor:/Deploy/Comps/Kartaverse/TVPaint/`

## TVPaint Node Categories

The TVPaint data nodes are separated into the following categories and sub-categories based upon the function they perform:

Camera
- TVPaintCameraFPS
- TVPaintCameraPixelAspectRatio
- TVPaintCameraSize

Clip
- TVPaintClipDPI
- TVPaintClipFPS
- TVPaintClipMarkIn
- TVPaintClipMarkOut
- TVPaintClipName
- TVPaintImageCount

Create
- TVPaintBackground

IO
- TVPaintLoader

Layer
- TVPaintLayerBlendMode
- TVPaintLayerCount
- TVPaintLayerName
- TVPaintLayerOpacity

Link
- TVPaintLinkFilename
- TVPaintLinkImage

Project
- TVPaintProjectFormat
- TVPaintProjectVersion

## TVPaint Node Usage

The Fusion node graph allows for the use of "data nodes". This nodal operator driven approach allows the individual node based input and output connections to pass TVPaint encoded documents "down the flow" in a parametric fashion.

This is achieved by encoding the raw TVPaint JSON information into a Fusion datatype called a "ScriptVal" which is represented by a Lua table structure. The TVPaint data is passed between node input and output connections in a way that allows you to visually control the operations that dynamically create, load, edit, render, and save the cell animation.

An TVPaint node graph starts with an "TVPaintLoader" node that imports an existing TVPaint (JSON formatted) file from disk.
