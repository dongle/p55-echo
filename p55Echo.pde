/*
P55 Echo
 by Jonathan Beilin
 http://jonbeilin.net
 github: dongle
 
 A re-implementation of the Echo effect in Adobe After Effects in processing.
 Takes a directory of a series of TIFFs and spits out a series of processed TIFFs.
 Blends and fades previous frames to create a dreamy swirl as seen at http://vimeo.com/22928669.
 Works best with things shot against an alpha.
 
 Setup contains some nifty switches to flip like resolution & blendmode etc.
 
 */

float decayAmount, currentAlpha;
int blendmode;
int frameskip, skippedFrames, renderFrameSkip;
int imgWidth, imgHeight;
int iterationsUntilBlack, iterationsSinceFade, iterationsBetweenFades;
File[] files;
boolean preserveAlphaRender, startWithBackground;
boolean composite;
color c, backgroundColor;

boolean slowMode;
int maxShadows, shadowSkip;
int startingFrame;

PImage currentRawFrame, clearFrame;
PGraphics buffer, renderFrame;

void setup() {
  // HERE ARE THE OPTIONS
  // HAVE FUN
  imgWidth = 1920;
  imgHeight = 1080;
  renderFrameSkip = 0; // render every X frames - good for testing
  String folderPath = "/Users/archer/slowmotroid";
  startWithBackground = true; // some blend modes are not going to be happy blending against alpha
  preserveAlphaRender = false; // if true, will matte against ...
  backgroundColor = color(0,0,0); // background color for each frame
  startingFrame = 1900; // more relevant if you turn on slowMode below ...

  composite = false; // note that this overrides blending

  // p55 blend mode cheat sheet:
  // these are good:
  // ADD, DIFFERENCE, LIGHTEST, SCREEN
  // these work but have uneven results depending on source etc:
  // EXCLUSION, DIFFERENCE
  // these don't really work based on the blending modes in p55. bummer :/
  // BLEND, SUBTRACT, DARKEST, MULTIPLY, OVERLAY, HARD_LIGHT, SOFT_LIGHT, DODGE, BURN
  blendmode = SCREEN;

  // for some reason if you draw an image with 254 alpha 192 times 
  // it turns black feel free to tweak this to your taste
  iterationsUntilBlack = 192;
  decayAmount = .9992; // this is the maximum; can adjust to fade faster

  // turn on slowMode if you're using a blend that can clip to white
  // it will re-render all previous frames each frame which is hella slow
  // but it will let add/screen fade properly
  // this is probably most useful for rendering single frames - might want
  // to set the starting frame to something
  slowMode = true;
  maxShadows = 650; // 100 total shadows. pump this as high as you want
  shadowSkip = 2; // only shadow frames that are a multiple of this number + 1
  frameskip = 0; // deprecated

  // setting counters to start at the appropriate place
  currentAlpha = 255.0;
  skippedFrames = 0;
  iterationsSinceFade = 0;

  size(100, 100);

  currentRawFrame = createImage(imgWidth, imgHeight, ARGB);
  clearFrame = createImage(imgWidth, imgHeight, ARGB);

  renderFrame = createGraphics(imgWidth, imgHeight, JAVA2D);
  buffer = createGraphics(imgWidth, imgHeight, JAVA2D);

  if (startWithBackground) {
    buffer.beginDraw();
    buffer.background(backgroundColor);
    buffer.endDraw();
  }

  files = listFiles(folderPath);
  iterationsBetweenFades = int(files.length / ( iterationsUntilBlack * 2.0));
  //println(files);

  if (slowMode) {
    makeEchoSlow();
  }
  else {
    makeEchoFast();
  }
}

void makeEchoSlow() {
  for (int i = startingFrame; i < files.length; i++) {
    if (getExtension(files[i]).equals("tif")) {

      // clear the buffer, which sort of isn't a buffer anymore
      buffer.beginDraw();
      if (!preserveAlphaRender) {
        buffer.background(backgroundColor);
      }
      else {
        buffer.loadPixels(); 
        buffer.pixels = Arrays.copyOf(clearFrame.pixels, clearFrame.pixels.length);
        buffer.updatePixels();
      }
      println("FRAME: " + i);

      // do echoes and stuff
      int j = i - (maxShadows * (shadowSkip + 1));
      if (j < 0) {
        j = 0;
      }
      while(j <= i) { 
        if (j % (shadowSkip + 1) == 0) {
          if (getExtension(files[j]).equals("tif")) {
            println("compositing: " + j);
            currentRawFrame = loadImageIO(files[j].getAbsolutePath());

            // determine fade level
            // play with different starting values
            // float fadeAmount = .99 - ((i - j)/ (float) (shadowSkip + 1) ) / maxShadows;
            float fadeAmount = .75 - ((i - j)/ (float) (shadowSkip + 1) ) / maxShadows;
            if (fadeAmount < 0) {
              fadeAmount = 0;
            }
            // fixed fadeAmount is pretty rad
            // fadeAmount = .1;

            // fade source image
            currentRawFrame.loadPixels();
            for (int k = 0; k < currentRawFrame.pixels.length; k++) {
              c = currentRawFrame.pixels[k];
              currentRawFrame.pixels[k] = color(red(c), green(c), blue(c), alpha(c)*fadeAmount);
            }
            currentRawFrame.updatePixels();

            // blend or composite source
            if (!composite) {
              buffer.blend(currentRawFrame, 0, 0, imgWidth, imgHeight, 0, 0, imgWidth, imgHeight, blendmode);
            }
            else {
              buffer.image(currentRawFrame, 0, 0);
            }
          }
        }
        j++;
      }


      // finally add current frame
      currentRawFrame = loadImageIO(files[i].getAbsolutePath());
      if (!composite) {
        buffer.blend(currentRawFrame, 0, 0, imgWidth, imgHeight, 0, 0, imgWidth, imgHeight, blendmode);
      }
      else {
        buffer.image(currentRawFrame, 0, 0);
      }
      buffer.endDraw();

      if (i % (renderFrameSkip + 1) == 0) {
        buffer.save("slowEcho-" + i + ".tif");
      }
    }
  }
}

void makeEchoFast() {
  for (int i = startingFrame; i < files.length; i++) {
    if (getExtension(files[i]).equals("tif")) {

      buffer.beginDraw();

      // fade if it's time to fade
      iterationsSinceFade++;
      buffer.loadPixels();
      if (iterationsSinceFade >= iterationsBetweenFades) {
        for (int j = 0; j< buffer.pixels.length; j++) {
          c = buffer.pixels[j];
          buffer.pixels[j] = color(red(c), green(c), blue(c), alpha(c)*decayAmount);
        }
        iterationsSinceFade = 0;
      }
      buffer.updatePixels();

      // blend current raw frame with buffer
      currentRawFrame = loadImageIO(files[i].getAbsolutePath());
      if (!composite) {
        buffer.blend(currentRawFrame, 0, 0, imgWidth, imgHeight, 0, 0, imgWidth, imgHeight, blendmode);
      }
      else {
        buffer.image(currentRawFrame, 0, 0);
      }
      buffer.endDraw();

      // make the final frame for render
      // add background
      // straight-up overlay current raw frame
      renderFrame.beginDraw();
      if (!preserveAlphaRender) {
        renderFrame.background(backgroundColor);
      }
      else {
        renderFrame.loadPixels(); 
        renderFrame.pixels = Arrays.copyOf(clearFrame.pixels, clearFrame.pixels.length);
        renderFrame.updatePixels();
      }
      renderFrame.image(buffer, 0, 0);
      renderFrame.image(currentRawFrame, 0, 0);
      renderFrame.endDraw();

      if (i % (renderFrameSkip + 1) == 0) {
        renderFrame.save("echo-" + i + ".tif");
      }

      println("frame" + i);
    }
  }
}

// Begin filehandling code

// This function returns all the files in a directory as an array of Strings  
String[] listFileNames(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    String names[] = file.list();
    return names;
  } 
  else {
    // If it's not a directory
    return null;
  }
}

// This function returns all the files in a directory as an array of File objects
// This is useful if you want more info about the file
File[] listFiles(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    File[] files = file.listFiles();
    return files;
  } 
  else {
    // If it's not a directory
    return null;
  }
}

String getExtension(File f) {
  String ext = "none";
  String s = f.getName();
  int i = s.lastIndexOf('.');

  if (i > 0 &&  i < s.length() - 1) {
    ext = s.substring(i+1).toLowerCase();
  }
  return ext;
}

