require 'chunky_png'
include ChunkyPNG::Color

class DiffImage

  def initialize(base_image, new_image)
    @base_image = ChunkyPNG::Image.from_file(base_image)
    @new_image = ChunkyPNG::Image.from_file(new_image)
    @diff_image = ChunkyPNG::Image.new(@base_image.width, @new_image.width, BLACK)
  end

  def calculate_changes
    diff = []

    @base_image.height.times do |y|
      @base_image.row(y).each_with_index do |pixel, x|
        unless pixel == @new_image[x,y]
          score = Math.sqrt(
            (r(@new_image[x,y]) - r(pixel)) ** 2 +
            (g(@new_image[x,y]) - g(pixel)) ** 2 +
            (b(@new_image[x,y]) - b(pixel)) ** 2
          ) / Math.sqrt(MAX ** 2 * 3)
          diff << score
        end
        @diff_image[x,y] = rgb(
          r(pixel) + r(@new_image[x,y]) - 2 * [r(pixel), r(@new_image[x,y])].min,
          g(pixel) + g(@new_image[x,y]) - 2 * [g(pixel), g(@new_image[x,y])].min,
          b(pixel) + b(@new_image[x,y]) - 2 * [b(pixel), b(@new_image[x,y])].min
        )
      end
    end

    total_pixels = @base_image.pixels.length
    diff_percentage = diff.inject {|sum, value| sum + value} / total_pixels
    puts "pixels (total):     #{total_pixels}"
    puts "pixels changed:     #{diff.length}"
    puts "image changed (%):  #{diff_percentage * 100} %"

    diff_percentage
  end

  def save_diff(diff_image)
    @diff_image.save(diff_image)
  end

end
