# Mandelbrot renderer
## What it does
This program renders a series of images from the mandelbrot set, a beautiful
fractal with very interesting patterns. If you want to learn more about the
mathematics behind it, take a look at the [Wikipedia entry](https://en.wikipedia.org/wiki/Mandelbrot_set).
The rendered jpeg images can later be concatenated using any video editor of your choice
to create a zooming animation.

## How it works
Images are rendered using mainly two parameters, namely the zoom and center. The higher the zoom
value, the closer we are zoomed in. The center is a complex number specifying which part of the
fractal will be at the image's center. The images are rendered in full hd.

Each pixel's color is determined by how often the function f<sub>c</sub>(z)=z<sup>2</sup>+c
can be applied without diverging (i.e. abs(z) < 2.0). These iterations are massively parallelizable
and therefore run on the GPU to gain a significant speed boost using NVIDIA CUDA technology. This means
you need a CUDA-compatible GPU to be able to run this program.

We later map the number of iterations of each pixel as a hue angle and convert the resulting
HSV color to RGB.

## Building
A makefile is provided. In addition to a C++ compiler which will be used as a backend by
the nvcc NVIDIA CUDA compiler, you of course need nvcc itself. Just run `make` and the
program will be built.

## Usage
All images will be dumped to an images folder. Configuration of values like the zoom, center and
image dimensions are done in the source code. Just change the values on the top as you see fit.
