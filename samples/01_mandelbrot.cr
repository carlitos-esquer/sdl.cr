# mandelbro with sdl.cr (my repo)
require "../src/sdl"

class MandelbrotExplorer
  @window : SDL::Window
  @renderer : SDL::Renderer
  @width = 800
  @height = 600
  @running = true
  @needs_redraw = true
  
  # Mandelbrot parameters
  @center_x = -0.5_f64
  @center_y = 0.0_f64
  @zoom = 1.0_f64
  @max_iterations = 384 # 256
  @color_scheme = 0  # 0: classic, 1: fire, 2: ice, 3: rainbow
  
  # Performance tracking
  @fps = 0
  @frame_count = 0
  @last_fps_time = Time.monotonic
  @render_time = 0.0_f64
  
  def initialize
    puts "=== Crystal SDL2 Mandelbrot Explorer ==="
    puts "Using your sdl_bindings_complete.cr"
    puts "Controls:"
    puts "  Arrow keys: Move"
    puts "  Numpad + Zoom in, - Zoom out"
    puts "  C: Cycle color schemes"
    puts "  R: Reset view"
    puts "  ESC: Exit"
    
    # Initialize SDL
    SDL.init(SDL::Init::VIDEO)
    at_exit { SDL.quit }
    
    # Create window (centered manually since WINDOWPOS_CENTERED not defined)
    title = "Crystal SDL2 Mandelbrot Explorer\0"
    @window = SDL::Window.new(title, @width, @height)
    
    # Create renderer
    @renderer = SDL::Renderer.new(@window)
  
    main_loop
  end
  
  def main_loop
    while @running
      event = SDL::Event.poll
      handle_event(event)
      
      # Update if needed
      update
      
      # Render
      render
      
      # Cap at 60 FPS
      #SDL.delay(16)
      sleep 0.0333
    end
    
    cleanup
  end
  
  def handle_event(event)
    case event
    when SDL::Event::Quit
      @running = false
    when SDL::Event::Keyboard
      # Check key symbol from keysym
      case event.sym
      when .escape?  # ESC key code (not SCANCODE_ESCAPE)
        @running = false
      when .c? # 'c' key (lowercase)
        @color_scheme = (@color_scheme + 1) % 4
        @needs_redraw = true
      when 114  # 'r' key (lowercase)
        reset_view
      when .up?  # UP arrow key code
        @center_y -= 0.1 / @zoom
        @needs_redraw = true
      when .down?  # DOWN arrow key code
        @center_y += 0.1 / @zoom
        @needs_redraw = true
      when .left?  # LEFT arrow key code
        @center_x -= 0.1 / @zoom
        @needs_redraw = true
      when .right?  # RIGHT arrow key code
        @center_x += 0.1 / @zoom
        @needs_redraw = true
      when .kp_plus?  # numpad '+' key (for zoom in)
        @zoom *= 1.2
        @needs_redraw = true
      when .kp_minus?  # numpad '-' key (for zoom out)
        @zoom /= 1.2
        @needs_redraw = true
      end if event.keyup?
    end
  end
  
  def update
    # Update FPS counter
    @frame_count += 1
    now = Time.monotonic
    if (now - @last_fps_time).total_seconds >= 1.0
      @fps = @frame_count
      @frame_count = 0
      @last_fps_time = now
    end
  end
  
  def render
    return unless @needs_redraw
    
    start_time = Time.monotonic
    
    # Clear screen to dark blue 
    @renderer.draw_color = SDL::Color[30, 30, 40, 255]
    @renderer.clear
    
    # Draw the Mandelbrot set using rectangles for better performance
    draw_mandelbrot_optimized
    
    # Draw a border
    draw_border
    
    # Present
    @renderer.present
    
    @render_time = (Time.monotonic - start_time).total_milliseconds
    
    # Print status to console
    print_status
    
    @needs_redraw = false
  end
  
  def draw_mandelbrot_optimized
    # Calculate bounds
    scale = 4.0 / (@width * @zoom)
    left = @center_x - (@width / 2) * scale
    top = @center_y - (@height / 2) * scale
    
    # Use larger blocks for better performance
    block_size = 4
    (@height // block_size).times do |by|
      y = by * block_size
      imag = top + y * scale
      
      (@width // block_size).times do |bx|
        x = bx * block_size
        real = left + x * scale
        
        # Sample center of block
        sample_x = real + (block_size / 2) * scale
        sample_y = imag + (block_size / 2) * scale
        
        iterations = mandelbrot_iterations(sample_x, sample_y)
        
        # Set color based on iterations
        if iterations == @max_iterations
          # Inside the set - black SDL::Color[30, 30, 40, 255]
          @renderer.draw_color = SDL::Color[0, 0, 0, 255]
        else
          # Outside the set - color based on escape time
          t = iterations.to_f32 / @max_iterations.to_f32
          
          case @color_scheme
          when 0  # Sky
            r = (t * 255).to_u8
            g = (t * 255).to_u8
            b = 255_u8
          when 1  # Fire
            r = 255_u8
            g = (t * 200).to_u8
            b = (t * 50).to_u8
          when 2  # Ice
            r = (t * 64).to_u8
            g = 32_u8
            b = (t * 255).to_u8
          when 3  # Solar
            hue = t * 360.0
            rgb = hsv_to_rgb(hue, 0.7, 1.0)
            r = (rgb[0] * 255).to_u8
            g = (rgb[1] * 255).to_u8
            b = (rgb[2] * 255).to_u8
          else
            r = g = b = (t * 255).to_u8
          end
          
          @renderer.draw_color = SDL::Color[r, g, b, 255]
        end
        
        # Draw block as rectangle
        #rect = LibSDL::Rect.new(x: x, y: y, w: block_size, h: block_size)
        @renderer.fill_rect(x,y,block_size,block_size)
      end
    end
  end
  
  def mandelbrot_iterations(real : Float64, imag : Float64) : Int32
    zr = 0.0_f64
    zi = 0.0_f64
    zr2 = 0.0_f64
    zi2 = 0.0_f64
    iterations = 0
    
    while iterations < @max_iterations && zr2 + zi2 < 4.0
      zi = 2.0 * zr * zi + imag
      zr = zr2 - zi2 + real
      zr2 = zr * zr
      zi2 = zi * zi
      iterations += 1
    end
    
    iterations
  end
  
def hsv_to_rgb(h : Float32, s : Float32, v : Float32) : Tuple(Float32, Float32, Float32)
  h = h % 360.0
  c = v * s
  x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs)
  m = v - c
  
  if h < 60.0
    r, g, b = c, x, 0.0
  elsif h < 120.0
    r, g, b = x, c, 0.0
  elsif h < 180.0
    r, g, b = 0.0, c, x
  elsif h < 240.0
    r, g, b = 0.0, x, c
  elsif h < 300.0
    r, g, b = x, 0.0, c
  else
    r, g, b = c, 0.0, x
  end
  
  # Explicit cast to Float32
  {(r + m).to_f32, (g + m).to_f32, (b + m).to_f32}
end
  
  def draw_border
    # Draw a yellow border around the window
    @renderer.draw_color = SDL::Color[255, 255, 0, 255]
    
    # Top border
    @renderer.draw_line(0, 0, @width - 1, 0)
    # Bottom border
    @renderer.draw_line(0, @height - 1, @width - 1, @height - 1)
    # Left border
    @renderer.draw_line(0, 0, 0, @height - 1)
    # Right border
    @renderer.draw_line(@width - 1, 0, @width - 1, @height - 1)
  end
  
  def print_status
    print "\r" + " " * 80 + "\r"  # Clear line
    print "Crystal SDL2 Mandelbrot | "
    print "Zoom: #{@zoom.round(2)}x | "
    print "Center: #{@center_x.round(4)}, #{@center_y.round(4)} | "
    print "Iterations: #{@max_iterations} | "
    print "Colors: #{@color_scheme} | "
    print "Render: #{@render_time.round(1)}ms | "
    print "FPS: #{@fps}"
    STDOUT.flush
  end
  
  def reset_view
    @center_x = -0.5_f64
    @center_y = 0.0_f64
    @zoom = 1.0_f64
    @max_iterations = 256
    @color_scheme = 0
    @needs_redraw = true
    puts "\nView reset"
  end
  
  def cleanup
    puts "\nGoodbye!"
  end
end

# ASCII version from Debian package
def print_density(d)
  if d > 8
    print ' '
  elsif d > 4
    print '.'
  elsif d > 2
    print '*'
  else
    print '+'
  end
end

def mandelconverger(real, imag, iters, creal, cimag)
  if iters > 255 || real*real + imag*imag >= 4
    iters
  else
    mandelconverger real*real - imag*imag + creal, 2*real*imag + cimag, iters + 1, creal, cimag
  end
end

def mandelconverge(real, imag)
  mandelconverger real, imag, 0, real, imag
end

def mandelhelp(xmin, xmax, xstep, ymin, ymax, ystep)
  ymin.step(to: ymax, by: ystep) do |y|
    xmin.step(to: xmax, by: xstep) do |x|
      print_density mandelconverge(x, y)
    end
  end
end

def mandel(realstart, imagstart, realmag, imagmag)
  mandelhelp realstart, realstart + realmag*78, realmag, imagstart, imagstart + imagmag*40, imagmag
end

# Main: Choose which version to run
puts "Choose Mandelbrot version:"
puts "1. ASCII version (original from Debian package)"
puts "2. SDL2 Graphics version (interactive, uses SDL2 bindings)"
print "Enter choice (1 or 2): "
choice = gets.to_s.strip

case choice
when "1"
  puts "\nRunning ASCII Mandelbrot..."
  mandel -2.3, -1.3, 0.05, 0.07
when "2"
  puts "\nRunning SDL2 Mandelbrot Explorer..."
  begin
    explorer = MandelbrotExplorer.new
  rescue ex
    puts "Error: #{ex.message}"
    puts ex.backtrace.join("\n")
  end
else
  puts "Invalid choice. Running ASCII version by default."
  mandel -2.3, -1.3, 0.05, 0.07
end
