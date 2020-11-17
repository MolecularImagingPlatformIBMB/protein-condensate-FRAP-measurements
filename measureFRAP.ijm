// measureFRAP.ijm  
// Last update August 2020
// Author: Elena Rebollo, Molecular Imaging Platform IBMB (CSIC)
// Fiji lifeline 22 Dec 2015
/* This macro performs the following steps:
		1) Asks the user to paint a ROI to select the cell of interest
		2) Registers the cell of interest
		3) Asks the user to paint a ROI around the bleaching target area (spot)
		4) Creates a time projection of the bleached area on which the real bleached spot will be thresholded.
		5) Asks the user to fine tune the threshold on the bleached area
		6) Automatically measures the intensity of the bleached area along the time stack
		7) Ask the user to paint a ROI for background
		8) Automatically measures the intensity of the background along the time stack
		9) Automatically segments the cell area (the segmentation pipeline might need to be modifyed for each particular experiment/set of images)
		10) Automatically measures the intensity of the whole cell along the time stack, to be use for gap and bleach depth calculations
*/


//PREPARE IMAGES
//Retrieve image name 
rawName = getTitle();
name = File.nameWithoutExtension;
rename(name);
getDimensions(width, height, channels, slices, frames);
getPixelSize(unit, pw, ph, pd);
NoFrames=nSlices;

// CREATE ARRAYS TO STORE RESULTS
ROIbleach=newArray(NoFrames);
ROIback=newArray(NoFrames);
ROIgap=newArray(NoFrames);

// MANUALLY SELECT CELL OF INTEREST
setTool("rectangle");
waitForUser("paint region to isolate cell");
run("Crop");

//REGISTER THE IMAGE AND REMOVE NOISE
run("Gaussian Blur...", "sigma=2 stack");
run("StackReg", "transformation=[Rigid Body]");
rename("gfp measure");
run("Green Fire Blue");
run("Set... ", "zoom=600"); 

//SELECT BLEACH REGION 
setTool("oval");
waitForUser("Paint roi that contains the bleach dot all throughout the stack");
run("Duplicate...", "title=region duplicate");
run("Z Project...", "projection=[Max Intensity]");
run("Set... ", "zoom=1000"); 
run("Threshold...");
setOption("BlackBackground", false);
waitForUser("Adjust threshold manually and press ok");
run("Convert to Mask");
run("Analyze Particles...", "size=10-Infinity pixel add");
selectWindow("region");
run("Set... ", "zoom=600"); 

//MEASURE INTENSITY WITHIN THE BLEACH REGION ALONG STACK
run("Clear Results");
run("Set Measurements...", "mean redirect=None decimal=2");
roiManager("Select", 0);
for(i=1; i<=nSlices; i++) {
	selectWindow("region");
	setSlice(i);
	run("Measure");
	mean =getResult("Mean", 0);
	ROIbleach[i-1] = mean;
	run("Clear Results");
}

//CLOSE WINDOWS
selectWindow("MAX_region");
run("Close");
selectWindow("region");
run("Close");
selectWindow("ROI Manager");
run("Close");

//CHOOSE BACKGROUND REGION ON A TIME PROJECTION IMAGE
//Make projection image
selectWindow("gfp measure");
run("Select All");
run("Z Project...", "projection=[Max Intensity]");
rename("choose ROIS");
run("Set... ", "zoom=600"); 
//Choose background ROI
setTool("oval");
waitForUser("select background region");
roiManager("add");

//MEASURE INTENSITY OF BACKGROUND ROI ALONG TIME STACK
roiManager("Select", 0);
for(i=1; i<=nSlices; i++) {
	selectWindow("gfp measure");
	setSlice(i);
	run("Measure");
	mean =getResult("Mean", 0);
	ROIback[i-1] = mean;
	run("Clear Results");
}

//SEGMENT THE CELL TO OBTAIN THE WHOLE INTENSITY FOR GAP CALCULATION
selectWindow("choose ROIS");
run("Select All");
run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
setAutoThreshold("Default dark");
setOption("BlackBackground", false);
run("Convert to Mask");
run("Analyze Particles...", "size=50-Infinity add");
selectWindow("choose ROIS");
close();

//MEASURE INTENSITY OF CELL ROI ALONG THE TIME STACK
roiManager("Select", 1);
for(i=1; i<=nSlices; i++) {
	selectWindow("gfp measure");
	setSlice(i);
	run("Measure");
	mean =getResult("Mean", 0);
	ROIgap[i-1] = mean;
	run("Clear Results");
}

//CREATE RESULTS TABLE
run("Table...", "name=["+name+"] width=400 height=300 menu");
print("["+name+"]", "\\Headings:"+"ROIbleach \t ROIcell \t ROIbackground");
for(i=0; i<=64; i++){
	print("["+name+"]", ""+ROIbleach[i] + "\t" + ROIgap[i] + "\t" + ROIback[i]);
}

//CLOSE WINDOWS
selectWindow("gfp measure");
close();
selectWindow("ROI Manager");
run("Close");
selectWindow("Threshold");
run("Close");
selectWindow("Results");
run("Close");