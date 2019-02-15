# require "childprocess"
require 'fastimage'

#
# abstract command
#
class Command
  def initialize whph_dir, current_dir
    @whph_dir = whph_dir
    @current_dir = current_dir
  end

  def run
    unimplemented!
  end

  def stop
    unimplemented!

  end

  def unimplemented!
    raise "command #{self.class} is not implemented yet"
  end


  protected

  def bin_path
    File.join @current_dir, "bin"
  end
end

class ShellCmd < Command
  def run
    @p = ChildProcess.build(shell_cmd, cmd_args)
    @p.leader = true
    @p.detach = true
    @p.start
  end

  def stop
    return unless @p
    @p.stop
  end

  protected

  def shell_cmd
    return File.join(bin_path, "shell.command")
  end

end

#
# copy vagrant's ssh key to clipbpard
#
class CopyKeyCmd < ShellCmd
  protected

  def cmd_args
    r = ""

    r << "( "
    r << "cd #{@whph_dir}"
    r << " && "
    r << "vagrant up slave"
    r << " && "
    r << "vagrant ssh slave -c 'cat ~/.ssh/id_rsa.pub'"
    r << " | pbcopy"
    r << " ); exit"

    return r
  end
end


#
# start local copy o the website
#
class StartCmd < ShellCmd
  def cmd_args
    r = "( "
    r << "cd #{@whph_dir}"
    r << " && "
    r << "vagrant up slave"
    r << " && "
    r << "vagrant ssh slave -c 'bash /vagrant/bin/whph-slave-site-watch.sh'"
    r << " ); exit"

    return r
  end
end

#
# start local copy o the website
#
class CleanCmd < ShellCmd
  def cmd_args
    r = "( "
    r << "cd #{@whph_dir}"
    r << " && "
    r << "vagrant ssh slave -c 'bash /vagrant/bin/whph-slave-site-clean.sh'"
    r << " ); exit"

    return r
  end
end

#
# vagrant halt and clean everything
#
class StopCmd < ShellCmd
  protected

  def cmd_args
    r = " ( "
    r << "cd #{@whph_dir}"
    r << " && "
    r << "vagrant halt slave"
    r << " ); exit"

    return r
  end
end


class Dirs
  def whph_dir
    @whph_dir = Shoes::ask_open_folder unless @whph_dir
    return @whph_dir
  end

  def pictures_dir
    return File.join(whph_dir, "pictures/2018")
  end

  def texts_dir
    return File.join(whph_dir, "ru")
  end


  def current_dir
    return File.expand_path(File.dirname(__FILE__))
  end
end

DIRS = Dirs.new

bkg_picture_path = `find #{DIRS.pictures_dir} -type f`.split("\n").shuffle.first
p_w, p_h = FastImage.size bkg_picture_path


FILL_COLORS = (0xF3F..0xF90).to_a


module Helpers
  def self.random_color
    "#" + FILL_COLORS.shuffle.first.to_s(16)
  end

  def self.quote_of_the_day
    File.read(`find #{DIRS.texts_dir} -name '*.md'`.split("\n").shuffle.first)
  end
end

Shoes.app width: 800,
  height: (p_h.to_f*800.0)/p_w.to_f,
  title: "WHPH Master of Ceremony" do

  debug p_w
  debug p_h
  # background "#F3F".."#F90"

  background bkg_picture_path, height: (p_h.to_f*800.0)/p_w.to_f, width: 800

  @copy_key_cmd = CopyKeyCmd.new(DIRS.whph_dir, DIRS.current_dir)
  @start_cmd = StartCmd.new(DIRS.whph_dir, DIRS.current_dir)
  @clean_cmd = CleanCmd.new(DIRS.whph_dir, DIRS.current_dir)
  @stop_cmd = StopCmd.new(DIRS.whph_dir, DIRS.current_dir)

  # @arrow = arrow 150, 200, 100 do
  #   stroke "#F3F".."#F90"
  # end

  # animate do
  #   @arrow.rotate (Time.now.to_i % 360)
  # end
  title "WHPH Master of Ceremony",
    top:    30,
    fill: Helpers::random_color

  stack(margin: 6, top: 120) do

    flow do
      fill Helpers::random_color
      para(strong(Helpers.quote_of_the_day[0..700]))
    end

    fill Helpers::random_color

    flow do
      banner (link("where am I?") {
              window do
                stack do
                  fill Helpers::random_color
                  title "some useful things"

                  fill Helpers::random_color
                  para "aaa"
                end
              end
            })
    end

    flow do
      @start = button "Start!"  do
        debug "start: running"

        @start_cmd.run

        debug "start: done"
      end

      fill Helpers::random_color
      para "start whph local website"
    end

    flow do
      @stop = button "Stop!" do
        debug "stop: running"

        @stop_cmd.run

        debug "stop: done"
      end

      fill Helpers::random_color
      para "stop whph local website"
    end

    flow do
      @clean = button "Clean!"  do
        debug "clean: running"

        @clean_cmd.run

        debug "clean: done"
      end

      fill Helpers::random_color
      para "clean if you have been told to do that"
    end

    flow do
      @copy_key = button "SSH_KEY -> Clipboard"  do
        debug "copy_key: running"

        @copy_key_cmd.run

        debug "copy_key: done"
      end

      fill Helpers::random_color
      para "copy ssh key to clipboard"
    end

    flow do
      button "kill'em all!" do
        debug "kill: running"

        @copy_key_cmd.stop
        @start_cmd.stop
        @stop_cmd.stop
        @clean_cmd.stop

        debug "kill: done"
      end
    end


    fill Helpers::random_color

    para "press ",
      strong("cmd+/"),
      "  to see console messages"

    fill Helpers::random_color

    para "WHPH dir: #{DIRS.whph_dir}"
    debug "WHPH dir: #{DIRS.whph_dir}"
    debug "current dir: #{DIRS.current_dir}"


    # button "Click me" do alert "Nice click!" end
    # image "http://shoesrb.com/img/shoes-icon.png",
    #       margin_top: 20, margin_left: 10
  end
end
