require "../src/sdl"
require "../src/image"

SDL.init(SDL::Init::VIDEO)
at_exit { SDL.quit }
window = SDL::Window.new("SDL Image", 640, 640)

SDL::IMG.init(SDL::IMG::Init::PNG)
at_exit { SDL::IMG.quit }

png = SDL::IMG.load(File.join(__DIR__, "data", "sample.png"))
png = png.convert(window.surface)

loop do
  case event = SDL::Event.wait
  when SDL::Event::Quit
    break
  end

  png.blit(window.surface)
  window.update
end
