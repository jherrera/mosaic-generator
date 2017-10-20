// This variable defines the mode of operation of the sketch. There are three possible values:
// MODES.JSON:    calculate RGB values and save them to a json file
// MODES.MOSAIC:  create a mosaic from RGB values loaded from a precalculated json file
// MODES.BOTH:    calculate (and save) values and then create mosaic
public enum MODES {JSON, MOSAIC, BOTH};
MODES command = MODES.MOSAIC;

// This variable specifies the path of the dataset. You can specify both a relative and an absolute path.
String datasetPath = "data/";

// This variable specifies the path of the image from which we're going to make a mosaic
String mainImageFilename = "image.jpg";

// This variable specifies the name fo the json file (both for saving and loading)
String jsonFilename = "values.json";

// This variable controls how the original image gets pixelated (i.e. scaled down).
// A value of 1 means the image remains the same. Bigger values make the image more pixelated (i.e. smaller)
int pixelationRate = 10;

// This variable controls the "tile size" of the images we draw as pixels. Bigger values result in the individual
// small tiles looking more detailed. Because the number of "pixels" we have to draw is defined by the pixelation rate,
// the two variables contribute to the outcome of the picture size.
int tileSize = 40;

// This variable specifies whether we treat each tile as 1 or 4 pixels. Using 4 pixel tiles create more detailed images
boolean fourPixelTiles = false;

// This variable controls how many values we keep as "top N" when we're looking for best matched images. If the value is 1, we only
// keep track of a single value. If value is 5, we keep track of the top 5 best matches and return one of them randomly.
int topN = 1;

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
  PGraphics pg = createGraphics(img.width * (tileSize / (fourPixelTiles ? 2: 1)), img.height * (tileSize / (fourPixelTiles ? 2: 1)));
  noStroke();
  pg.beginDraw();
  println("Total:", img.width);
  int d = fourPixelTiles ? 2 : 1;
  for(int x = 0; x < img.width - (fourPixelTiles ? 1 : 0); x += d){
    for(int y = 0; y < img.height - (fourPixelTiles ? 1 : 0); y += d){
      float[] r, g, b;
      if(fourPixelTiles){
        int[] pixelIndex = new int[4];
        pixelIndex[0] = x +(y * img.width);
        pixelIndex[1] = x + 1 +(y * img.width);
        pixelIndex[2] = x +((y + 1) * img.width);
        pixelIndex[3] = x + 1 +((y + 1) * img.width);
        r = new float[4];
        g = new float[4];
        b = new float[4];
        for(int z = 0; z < 4; z++){
          r[z] = red(img.pixels[pixelIndex[z]]);
          g[z] = green(img.pixels[pixelIndex[z]]);
          b[z] = blue(img.pixels[pixelIndex[z]]);
        }
      } else {
        int pixelIndex = x +(y * img.width);
        r = new float[1];
        r[0] = red(img.pixels[pixelIndex]);
        g = new float[1];
        g[0] = green(img.pixels[pixelIndex]);
        b = new float[1];
        b[0] = blue(img.pixels[pixelIndex]);
      }
      String filename = findBestMatch(values, r, g, b, topN);
      PImage tmp = loadImage(filename);
      pg.image(tmp, x * (tileSize / (fourPixelTiles ? 2: 1)), y * (tileSize / (fourPixelTiles ? 2: 1)), tileSize, tileSize);
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
  return "output/output_"+year()+month()+day()+"-"+nf(hour(), 2)+nf(minute(), 2)+nf(second(), 2)+"_"+pixelationRate+"-"+tileSize+"-"+(fourPixelTiles ? "q" : "n")+".png";
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
    JSONObject obj = getRGBFromImage(img);
    obj.setString("file", fileList[imgIndex].toString());
    json.setJSONObject(imgIndex, obj);
    // Display progress in console
    println(imgIndex);
  }
  // Return object,
  return json;
}

JSONObject getRGBFromImage(PImage img){
    float[] q1, q2, q3, q4;
    // Process all 4 quadrants
    q1 = processImageRegion(img,             0,              0, img.width / 2, img.height / 2);
    q2 = processImageRegion(img, img.width / 2,              0, img.width    , img.height / 2);
    q3 = processImageRegion(img,             0, img.height / 2, img.width / 2, img.height    );
    q4 = processImageRegion(img, img.width / 2, img.height / 2, img.width    , img.height    );

    // Create new JSON object to store this information
    JSONObject obj = new JSONObject();

    // Store each quadrant information
    storeQuadrantInfo(obj, 0, q1);
    storeQuadrantInfo(obj, 1, q2);
    storeQuadrantInfo(obj, 2, q3);
    storeQuadrantInfo(obj, 3, q4);
    return obj;
}

void storeQuadrantInfo(JSONObject obj, int index, float[] values){
  obj.setFloat("r"+index, values[0]);
  obj.setFloat("g"+index, values[1]);
  obj.setFloat("b"+index, values[2]);
}

// Returns an array with average values for an image region
float[] processImageRegion(PImage img, int start_x, int start_y, int end_x, int end_y){
  float r = 0,
        g = 0,
        b = 0;
  for(int x = start_x; x < end_x; x++){
    for(int y = start_y; y < end_y; y++){
      int pixelIndex = x + (y * img.width);
      r += red(img.pixels[pixelIndex]);
      g += green(img.pixels[pixelIndex]);
      b += blue(img.pixels[pixelIndex]);
    }
  }
  int numPixels = (end_x - start_x) * (end_y - start_y);
  float[] values = new float[3];
  values[0] = r / numPixels;
  values[1] = g / numPixels;
  values[2] = b / numPixels;
  return values;
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
String findBestMatch(JSONArray values, float[] in_r, float[] in_g, float[] in_b, int topListSize){
  ArrayList topList = new ArrayList(topListSize);
  for(int i = 0; i < topListSize; i++){
    topList.add(new listFind(255*3*in_r.length, 0));
  }

  for(int i = 0; i < values.size(); i++){
    JSONObject data = values.getJSONObject(i);
    float diff = 0;
    if(fourPixelTiles){
      for(int qi = 0; qi < in_r.length; qi++){
        float r = data.getFloat("r"+qi);
        float g = data.getFloat("g"+qi);
        float b = data.getFloat("b"+qi);
        // Calculate how different this particular pixel is with respect to the averages from the image in the data set
        diff += abs(r - in_r[qi]) + abs(g - in_g[qi]) + abs(b - in_b[qi]);
      }
    } else {
      float r = (data.getFloat("r0") + data.getFloat("r1") + data.getFloat("r2") + data.getFloat("r3")) / 4;
      float g = (data.getFloat("g0") + data.getFloat("g1") + data.getFloat("g2") + data.getFloat("g3")) / 4;
      float b = (data.getFloat("b0") + data.getFloat("b1") + data.getFloat("b2") + data.getFloat("b3")) / 4;
      diff = abs(r - in_r[0]) + abs(g - in_g[0]) + abs(b - in_b[0]);
    }

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