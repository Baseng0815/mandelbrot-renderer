#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <math.h>

#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include <stb/stb_image_write.h>

struct comp {
        double real;
        double imag;
};

const int max_iter          = 2048;
const int img_width         = 1920;
const int img_height        = 1080;
const struct comp center    = {
        .real = -0.77568377,
        .imag = 0.13646737
};

const double zoom_start     = 1.0;
const double zoom_end       = 1.0e227;
const double zoom_fact      = 1.1;

__device__ void iterate(struct comp c, int *iterations)
{
        struct comp z = c;
        int i = 0;
        while (i < max_iter &&
               sqrt(z.real * z.real + z.imag * z.imag) < 2.0) {
                double real = z.real * z.real - z.imag * z.imag + c.real;
                double imag = z.real * z.imag * 2.0 + c.imag;
                z.real = real;
                z.imag = imag;
                i++;
        }

        *iterations = i;
}

__device__ void map_pixel(int px, int py, double zoom,
                          struct comp center, struct comp *result)
{
        double span_real    = 4.0 / zoom;
        double span_imag    = 2.0 / zoom;

        /* first without taking zoom into account, but already centered */
        double real_nozoom = span_real / (double)img_width  * px
                - span_real / 2.0 + center.real;
        double imag_nozoom = span_imag / (double)img_height * py
                - span_imag / 2.0 + center.imag;

        result->real = real_nozoom;
        result->imag = imag_nozoom;
}

__device__ void hsv_to_rgb(int h, int s, int v, int *r, int *g, int *b)
{
        double S = s / 100.0;
        double V = v / 100.0;
        double c = S * V;
        double x = c * (1.0 - fabs(fmod(h / 60.0, 2.0) - 1.0));
        double m = V - c;

        double R, G, B;

        if (h >= 0 && h < 60)
                R = c, G = x, B = 0;
        else if (h >= 60 && h < 180)
                R = x, G = c, B = x;
        else if (h >= 180 && h < 240)
                R = 0, G = x, B = c;
        else if (h >= 240 && h < 300)
                R = x, G = 0, B = c;
        else
                R = c, G = 0, B = x;

        *r = (R + m) * 255.0;
        *g = (G + m) * 255.0;
        *b = (B + m) * 255.0;
}

__global__ void plot_pixel(uint8_t *buf, struct comp center, double zoom)
{
        /* get index in grid-stride loop and convert to pixel coordinates */
        int i = threadIdx.x + blockIdx.x * blockDim.x;
        int px = i % img_width;
        int py = i / img_width;

        struct comp c;
        map_pixel(px, py, zoom, center, &c);

        int iterations;
        iterate(c, &iterations);

        int r, g, b;
        hsv_to_rgb(iterations % 360, 100,
                   (max_iter - iterations) /
                   (double)max_iter * 100, &r, &g, &b);

        size_t byte = 3 * (py * img_width + px);
        buf[byte + 0] = r;
        buf[byte + 1] = g;
        buf[byte + 2] = b;
}

void plot_mandelbrot(uint8_t *buf, double zoom)
{
        /* this should be a multiple of img_width * img_height */
        int threads_per_block   = 256;
        int block_count         = img_width * img_height / threads_per_block;

        plot_pixel<<<block_count, threads_per_block>>>(buf, center, zoom);
        cudaDeviceSynchronize();
}

int main(int argc, char **argv)
{
        struct stat st = { 0 };
        if (stat("./images", &st) == -1) {
                mkdir("./images", 0755);
        }

        uint8_t *buf;
        cudaMallocManaged(&buf, img_width * img_height * 3);

        int img_id = 0;
        int img_count = log(zoom_end / zoom_start) / log(zoom_fact);
        printf("Total number of images to plot: %d\n", img_count);
        for (double zoom = zoom_start; zoom <= zoom_end; zoom *= zoom_fact) {
                printf("Plotting image %d with zoom %f (%d%)...\n",
                       img_id, zoom, img_id * 100 / img_count);
                plot_mandelbrot(buf, zoom);

                char file_name[32];
                sprintf(file_name, "images/%06d.jpeg", img_id);
                stbi_write_jpg(file_name, img_width, img_height, 3, buf, 100);

                img_id++;
        }

        cudaFree(buf);
}
