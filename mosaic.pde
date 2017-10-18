// This variable defines the mode of operation of the sketch. There are three possible values:
// MODES.JSON:    calculate RGB values and save them to a json file
// MODES.MOSAIC:  create a mosaic from RGB values loaded from a precalculated json file
// MODEs.BOTH:    calculate (and save) values and then create mosaic
public enum MODES {JSON, MOSAIC, BOTH};
MODES command = MODES.BOTH;

// This variable specifies the path of the dataset. You can specify both a relative and an absolute path.
String datasetPath = "data/";

// This variable specifies the path of the image from which we're going to make a mosaic
String mainImageFilename = "image.jpg";

// This variable specifies the name fo the json file (both for saving and loading)
String jsonFilename = "values.json";

// This variable controls how the original image gets pixelated (i.e. scaled down).
// A value of 1 means the image remains the same. Bigger values make the image more pixelated (i.e. smaller)
int pixelationRate = 10;

// This variable controls the "pixel size" of the images we draw as pixels. Bigger values result in the individual
// small pictures looking more detailed. Because the number of "pixels" we have to draw is defined by the pixelation rate,
// the two variables contribute to the outcome of the picture size.
int pixelSize = 20;

// This variable controls how many values we keep as "top N" when we're looking for best matched images. If the value is 1, we only
// keep track of a single value. If value is 5, we keep track of the top 5 best matches and return one of them randomly.
int topN = 5;

void setup(){
  size(400, 400);
  PImage mainImage = loadImage(sketchPath(mainImageFilename));
  background(0);
  JSONArray values = null;
  if(command == MODES.JSON || command == MODES.BOTH){
      println("Calculating RGB values");
      values = createJSONFromFileList(sketchPath(datasetPath));
      saveJSONToFile(values);
      println("Saved RGB values to", jsonFilename);
  }
  if(command == MODES.MOSAIC || command == MODES.BOTH){
    if(values == null){
      values = loadJSONFromFile();
    }
    println("Creating mosaic");
    PImage scaledImage = createImage(mainImage.width / pixelationRate, mainImage.height/ pixelationRate, RGB);
    scaledImage.copy(mainImage, 0, 0, mainImage.width, mainImage.height, 0, 0, mainImage.width / pixelationRate, mainImage.height / pixelationRate);
    String fn = createMosaic(scaledImage, values);
    println("Saved mosaic to", fn);
  }
  image(mainImage, 0, 0);
  noLoop();
}

// Creates mosaic from given img (the scaled down version) and values (json object with RGB values)
String createMosaic(PImage img, JSONArray values){
  PGraphics pg = createGraphics(img.width * pixelSize, img.height * pixelSize);
  noStroke();
  pg.beginDraw();
  println("Total:", img.width);
  for(int x = 0; x < img.width; x++){
    for(int y = 0; y < img.height; y++){
      int pixelIndex = x +(y * img.width);
      float r = red(img.pixels[pixelIndex]);
      float g = green(img.pixels[pixelIndex]);
      float b = blue(img.pixels[pixelIndex]);
      String filename = findBestMatch(values, r, g, b, topN);
      PImage tmp = loadImage(filename);
      pg.image(tmp, x * pixelSize, y * pixelSize, pixelSize, pixelSize);
    }
    println(x);
  }
  pg.endDraw();
  String fn = getSaveFilename();
  pg.save(fn);
  return fn;
}

// Save json to file
void saveJSONToFile(JSONArray json){
  saveJSONArray(json, jsonFilename);
}

// Return json from precalculated file
JSONArray loadJSONFromFile(){
  return loadJSONArray(jsonFilename);
}

// Return a valid output file name including timestamp
String getSaveFilename(){
  return "output/output_"+hour()+"-"+minute()+"-"+second()+".png";
}

// Creates and returns a json object containing RGB values for every image found in path
JSONArray createJSONFromFileList(String path){
  File[] fileList = listFiles(path);

  JSONArray json = new JSONArray();
  println("Total:", fileList.length);
  // Loop through the entire fileList
  for(int imgIndex = 0; imgIndex < fileList.length; imgIndex++){
    PImage img = loadImage(fileList[imgIndex].toString());
    if(img == null){
      // Skip if we couldn't load this file as an image
      continue;
    }
    float r = 0,
          g = 0,
          b = 0;
    float totalPixels = img.pixels.length;
    // Loop through the entire pixel array of this particular image, adding all RGB values
    for(int pixelIndex = 0; pixelIndex < img.pixels.length; pixelIndex++){
       r += red(img.pixels[pixelIndex]);
       g += green(img.pixels[pixelIndex]);
       b += blue(img.pixels[pixelIndex]);
    }
    // Create new JSON object to store this information
    JSONObject obj = new JSONObject();
    obj.setString("file", fileList[imgIndex].toString());
    obj.setFloat("r", r/totalPixels);    // We want the average of the values
    obj.setFloat("g", g/totalPixels);    // we just added, so we divide by
    obj.setFloat("b", b/totalPixels);    // totalPixels
    json.setJSONObject(imgIndex, obj);
    // Display progress in console
    println(imgIndex);
  }
  // Return object,
  return json;
}

// Shift elements in list to the right. For example, take the list [A, B, C, D, E], if we want to shift elements
// from index 2 (C in the list) we call shiftRight(list, 2) and we end up with  [A, B, C, C, D] and now we can
// set index 2 to our desired value, e.g. list.set(2, "Z") to get the result [A, B, Z, C, D]
void shiftRight(ArrayList list, int pos){
  for(int i = list.size()-1; i > pos; i--){
    list.set(i, list.get(i-1));
  }
}

// An object that stores information about a particular finding while traversing the array
class listFind {
  float diff = 765;
  int index = 0;
  listFind(float d, int i){
    diff = d;
    index = i;
  }
}

// Finds the best match for a particular given set of RGB values. If topListSize is bigger than 1, randomness is
// introduced by keeping track of the top N most similar values and choosing one of them at random
String findBestMatch(JSONArray values, float in_r, float in_g, float in_b, int topListSize){
  ArrayList topList = new ArrayList(topListSize);
  for(int i = 0; i < topListSize; i++){
    topList.add(new listFind(765.0, 0));
  }

  for(int i = 0; i < values.size(); i++){
    JSONObject data = values.getJSONObject(i);
    float r = data.getFloat("r");
    float g = data.getFloat("g");
    float b = data.getFloat("b");

    // Calculate how different this particular pixel is with respect to the averages from the image in the data set
    float diff = abs(r - in_r) + abs(g - in_g) + abs(b - in_b);

    // Loop through topList and see if we can fit this value in there
    for(int li = 0; li < topList.size(); li++){
      listFind el = (listFind)topList.get(li);
      if(diff < el.diff){
        shiftRight(topList, li);
        topList.set(li, new listFind(diff, i));
        break;    // We don't need to continue looking through the top list
      }
    }
  }
  // Choose a random index from the list and return the name of the file
  int chooseIndex = floor(random(topList.size()));
  int index = ((listFind)topList.get(chooseIndex)).index;
  return values.getJSONObject(index).getString("file");
}

// List files in a given directory
File[] listFiles(String path) {
  File file = new File(path);
  if(!file.isDirectory()){
    return null;
  }
  File[] files = file.listFiles();
  return files;
}