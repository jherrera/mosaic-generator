# MosaicGenerator

MosaicGenerator is a _Processing sketch_ that generates mosaic images from a dataset of pictures.

This sketch is inspired by the work of Daniel Shiffman and his [ObamaMosaic](https://github.com/ITPNYU/Obamathon/blob/master/examples/Processing/ObamaMosaic/), but takes a different approach both in the handling of the dataset and the matching of individual _tiles_ to a pixel.

## Handling big datasets

Because loading and holding an image in memory takes up resources, it places a limit on how big a dataset can get if we try to load them all at once.

However, we don't need to have the image in memory; we only need to load one image at a time, calculate its RGB averages and store these values in a JSON object (in memory or in disk). This way we can handle big datasets. 

As an example, RGB averages from a dataset containing 2,000 images can be stored in a JSON file of around 350KB.

## Color matching

We can match color from a pixel (in the original image) to a _tile_ (one of the individual images in the dataset) by first calculating the RGB averages for the _tile_. We simply loop through all the pixels in a given image, adding up all its Red, Green and Blue values. Finally, we divide by the total numbers of pixels and we get the R,G and B averages, which we then save to a JSON object. 

Later, when we are trying to match a particular RGB value from a pixel to one of the images in the dataset, we loop through the JSON object looking for suitable matches.

Consider the RGB values from a given pixel: `pR`, `pG`, and `pB`; we want to find the JSON entry and its values `R`, `G` and `B`, that are the _least different_. We substract each individual value and get its absolute value. We then add these three differences and that is our _calculated difference_:

    float diff = abs(pR - R) + abs(pG - G) + abs(pB - B);

We can then keep track of the best value in the dataset; the lower the value, the more closely it matches the pixel.

The _sketch_  keeps track of an arbitrary number of these values. Keeping a sort of "top N best values"; when it finishes looking through the JSON list, it then returns one of these "top N values" at random. 

This introduces a little bit of randomness into the image, as otherwise the same tile tends to cluster around areas of the original image where there isn't much variance.
