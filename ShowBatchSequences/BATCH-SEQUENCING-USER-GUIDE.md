# Batch Sequencing Visualization - User Guide

## Overview

The Batch Sequencing Visualization application provides an interactive view of ETL (Extract, Transform, Load) batch sequences for the Health Catalyst DOS Platform. It displays the dependencies and execution flow from Source Mart jobs to SAM Jobs, helping you understand and monitor batch processing workflows.

## Getting Started

### Accessing the Application

Open the HTML file in your web browser:
- **Latest View**: `BatchSequenceDetail-IDEA_[SERVER].html`
- The application automatically loads the most recent batch sequence data

### Understanding the Interface

The application displays a visual diagram where:
- **Nodes** represent individual batch jobs
- **Arrows** show dependencies between jobs (which jobs must complete before others can start)
- **Colors** indicate different types of jobs and their status

#### Legend

- **Light Blue** - Source Mart jobs
- **Purple** - Subject Area Mart (SAM) jobs
- **Gray** - Wrong Data Mart or removed jobs
- **Orange** - Jobs with incorrect naming

## Core Features

### 1. Filter Options

Located in the top-right header, the Filter dropdown provides three views:

#### All Batches (Default)
- Displays the complete batch sequence diagram
- Shows all jobs and their dependencies
- Use this view to understand the full workflow

#### Did Not Run Today
- Filters to show only batches that have not run today or failed
- Includes parent dependencies for lineage context
- Helpful for identifying issues and monitoring daily execution
- If all batches ran successfully, you'll see a green success message

#### Broken References
- Shows batches with broken references or invalid dependencies
- Includes parent nodes for context
- Use this to identify and fix configuration issues
- If no broken references exist, you'll see a green success message

**Note**: When viewing historical snapshots, filters are disabled. To use filters, return to the latest view by clicking the Renown Health logo.

### 2. Zoom and Pan Controls

#### Zoom Buttons (Bottom-Right)
- **+ Button** - Zoom in
- **- Button** - Zoom out
- **R Button** - Reset zoom to fit the entire diagram in the viewport

#### Mouse Controls
- **Mouse Wheel** - Scroll up to zoom in, scroll down to zoom out
- **Click and Drag** - Pan around the diagram (click on whitespace, not on nodes)
- The cursor changes to a grab hand when over draggable areas

#### Text Selection
- Click on node text to select and copy job names or information
- The cursor changes to a text cursor when hovering over text

### 3. Historical Snapshots

Access past batch sequences to compare changes over time or review historical execution patterns.

#### Opening the History Calendar

Click the **Calendar icon** in the top-right header to open the Historical Snapshots modal.

#### Using the Calendar

- **Month Navigation**: Use the left/right arrow buttons to navigate between months
- **Days with Snapshots**: Highlighted in purple with a count badge showing the number of snapshots
- **Selecting a Date**: Click on a highlighted day to view available snapshots for that date

#### Loading a Snapshot

1. Click on a date with snapshots (purple highlighted)
2. A list of snapshots for that day appears below the calendar, sorted by time (earliest first)
3. Click on a specific time to select it (the selected item highlights in purple)
4. Click **Okay** to load the selected snapshot
5. Click **Cancel** to close without loading

#### Returning to Latest View

- Click **Reset (Latest)** in the history modal, or
- Click the **Renown Health logo** in the top-left corner

**Note**: Historical snapshots show the batch state at that specific time. Filters are not available in snapshot view.

### 4. Environment Switcher (DEV/PROD)

Switch between Development and Production environments to compare configurations or monitor different systems.

#### Switching Environments

1. Click the **Database icon** in the top-right header
2. Select from the dropdown:
   - **RHNV-EDWDEV** - Development environment
   - **RHNV-EDWPROD** - Production environment
3. The current environment is highlighted in purple
4. The page reloads with the selected environment's data

### 5. Help Information

Click the **Question mark icon** in the top-right header to access:
- Feature descriptions
- Usage tips
- Contact information for support

## Tips and Best Practices

### Daily Monitoring Workflow

1. Open the latest view each morning
2. Check the "Did Not Run Today" filter to identify any issues
3. Review the "Broken References" filter to catch configuration problems
4. Use the full "All Batches" view to understand dependencies when troubleshooting

### Comparing Changes

1. Open the current view
2. Use the History Calendar to load a snapshot from a previous date
3. Open both in separate browser tabs to compare side-by-side
4. Look for new nodes, removed nodes, or changed dependencies

### Investigating Issues

1. Use the "Did Not Run Today" filter to identify problem batches
2. Note the parent dependencies shown in the filtered view
3. Check if parent jobs completed successfully
4. Use the full diagram to trace the complete dependency chain

### Navigating Large Diagrams

1. Use the Reset (R) button to fit the entire diagram in view
2. Zoom in on specific areas of interest
3. Click and drag to pan to different sections
4. Use text selection to copy job names for searching in other systems

## Technical Details

### Snapshot Generation

- Snapshots are automatically generated at regular intervals
- Each snapshot captures the batch state at that specific time
- Snapshots are retained for 90 days
- Both SVG diagrams and interactive HTML files are created

### File Locations

- **Diagrams**: `ShowBatchSequences/Diagrams/` folder
- **GraphViz Source**: `ShowBatchSequences/GraphViz/` folder
- **HTML Files**: Interactive pages with embedded SVG content

### Browser Compatibility

The application works best in modern browsers:
- Google Chrome (recommended)
- Microsoft Edge
- Mozilla Firefox
- Safari

## Troubleshooting

### Diagram Not Loading

- Refresh the browser page
- Clear browser cache and reload
- Ensure JavaScript is enabled in your browser

### Zoom Not Working

- Try using the zoom buttons instead of mouse wheel
- Click the Reset (R) button to restore default view
- Refresh the page if controls become unresponsive

### Historical Snapshots Not Appearing

- Snapshots are only available for dates when the generation script ran
- Check that you're looking at the correct month
- Snapshots older than 90 days are automatically deleted

### Cannot Switch Environments

- Ensure both DEV and PROD environments are accessible
- Check network connectivity
- The target environment must have generated diagrams available

## Support

For questions, issues, or feature requests, please contact:

**Ronald Odiyar**  
Email: ronald.odiyar@renown.org

---

*Last Updated: February 2026*
