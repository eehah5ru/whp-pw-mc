# -*- coding: utf-8 -*-
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


#
# shell command
#
class ShellCmd < Command
  #
  # save instance of the command to kill them if it's needed
  #
  def self.register_instance a_cmd
    @cmds = [] unless @cmds

    @cmds << a_cmd
  end

  #
  # stop all existing shell commands' processes
  #
  def self.stop_them_all
    return unless @cmds

    @cmds.each { |c|
      c.stop
    }
  end

  
  def initialize whph_dir, current_dir
    ShellCmd.register_instance self
    
    super whph_dir, current_dir
  end
  
  def run
    @p = Process.spawn(shell_cmd, cmd_args)
    Process.detach @p
  end

  #
  # kill child process
  #
  def stop
    return unless @p
    
    begin
      Process.kill(:SIGINT, @p)
    rescue Errno::ESRCH
      STDERR.puts "#{self.class.name} already killed"
    end
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
    r << "| osascript -e 'display notification \"SSH Key was copied to clipboard!\" with title \"WHPH MC\"'"
    r << " ); exit"

    return r
  end
end


#
# setup vagrant environment
#
class SetupVagrantCmd < ShellCmd

  protected
  
  def cmd_args
    r = "( ( "
    r << "cd #{@whph_dir}"
    r << " && "
    r << "vagrant plugin install vagrant-vbguest"
    r << " && "
    r << "vagrant plugin install vagrant-hostsupdater"
    r << " && "
    r << "vagrant up slave"
    r << " && "    
    r << " vagrant provision slave" 
    r << " ) || read -p 'Take a screenshot and press enter to continue' ); exit"

    return r
  end
end

#
# start local copy o the website
#
class StartCmd < ShellCmd
  def cmd_args
    r = "( ( "
    r << "cd #{@whph_dir}"
    r << " && "
    r << "vagrant up slave"
    r << " && "
    r << "vagrant ssh slave -c 'bash /vagrant/bin/whph-slave-site-watch.sh'"
    r << " ) || read -p 'Take a screenshot and press enter to continue' ); exit"

    return r
  end
end

#
# start syncing
#
class SyncFilesCmd < ShellCmd
  def cmd_args
    r = "( ( "
    r << "cd #{@whph_dir}"
    r << " && "
    r << "vagrant up slave"
    r << " && "
    r << "vagrant rsync-auto slave"
    r << " ) || read -p 'Take a screenshot and press enter to continue' ) ; exit"

    return r    
  end
end

#
# start local copy o the website
#
class CleanCmd < ShellCmd
  def cmd_args
    r = "( ( "
    r << "cd #{@whph_dir}"
    r << " && "
    r << "vagrant ssh slave -c 'bash /vagrant/bin/whph-slave-site-clean.sh'"
    r << " ) || read -p 'Take a screenshot and press enter to continue' ) ; exit"

    return r
  end
end

#
# kill server, clean and start again
#
class KillCleanStartCmd < ShellCmd
  def cmd_args
    r = "( ( "
    r << "cd #{@whph_dir}"
    r << " && "
    # kill all site processes
    r << "vagrant ssh slave -c 'killall -9 site'"
    r << " && "
    # clean hakyll
    r << "vagrant ssh slave -c 'bash /vagrant/bin/whph-slave-site-clean.sh'"
    r << " && "
    # start hakyll again
    r << "vagrant ssh slave -c 'bash /vagrant/bin/whph-slave-site-watch.sh'"
    # exit to close terminal window
    r << " ) || read -p 'Take a screenshot and press enter to continue' ) ; exit"
    
    return r 
  end
  
end

#
# vagrant halt and clean everything
#
class StopCmd < ShellCmd
  protected

  def cmd_args
    r = "( ( "
    r << "cd #{@whph_dir}"
    r << " && "
    r << "vagrant halt slave"
    r << " && "
    r << "( kill $(ps aux | grep 'vagrant' | awk '{print $2}') )"
    r << " ) || read -p 'Take a screenshot and press enter to continue' ) ; exit"

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
    return whph_dir #Dir.getwd #File.expand_path(File.dirname(__FILE__))
  end
end

#
# dirs collection
#
DIRS = Dirs.new


#
# colors for GUI
#
FILL_COLORS = (0xF3F..0xF90).to_a


#
# GUI HELPERS
#
module Helpers
  def self.random_color
    "#" + FILL_COLORS.shuffle.first.to_s(16)
  end

  def self.quote_of_the_day
    File.read(`find #{DIRS.texts_dir} -name '*.md'`.split("\n").shuffle.first)
  end

  def self.bkg_picture
    r = `find #{DIRS.pictures_dir} -type f | grep -v DS_Store`.split("\n").shuffle.first
    w, h = FastImage.size r

    return r, w, h
  end
end


#
#
# SHOES APP
#
#

#
# get bkg picture and window width and height
#
main_bkg, main_w, main_h = Helpers.bkg_picture

#
# the app
#
Shoes.app width: 800,
  height: (main_h.to_f*800.0)/main_w.to_f,
  title: "WHPH Master of Ceremony" do

  background main_bkg, height: (main_h.to_f*800.0)/main_w.to_f, width: 800

  @copy_key_cmd = CopyKeyCmd.new(DIRS.whph_dir, DIRS.current_dir)
  @start_cmd = StartCmd.new(DIRS.whph_dir, DIRS.current_dir)
  @clean_cmd = CleanCmd.new(DIRS.whph_dir, DIRS.current_dir)
  @kill_clean_start_cmd = KillCleanStartCmd.new(DIRS.whph_dir, DIRS.current_dir)  
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
      banner (link("where am I? (Click'n'Read before start)") {
                wtf_bkg, wtf_w, wtf_h = Helpers.bkg_picture

                window width => 400 ,:height => (wtf_h.to_f*400.0)/wtf_w.to_f do
                  background wtf_bkg, height: (wtf_h.to_f*400.0)/wtf_w.to_f, width: 400
                  stack do
                    fill Helpers::random_color
                    title "some useful things before we start:"

                    fill Helpers::random_color
                    para "please install ", link("VirtualBox"){`open 'https://www.virtualbox.org/wiki/Downloads'`}

                    #
                    # move VBox machines to external drive
                    #
                    fill Helpers::random_color
                    para "Если у тебя нет места на жестком диске ноутбука, поменяй в настройках virtualbox папку, где будут храниться твои виртуальные машины: ", code("Menu -> VirtualBox -> Preferences -> General -> Default Machine Folder"), ". Например, можно указать папку на внешнем жестком диске. Главное, чтобы у тебя было свободно где-то 10Гб."

                    #
                    # install vagrant
                    #
                    fill Helpers::random_color
                    para "please install ", link("vagrant"){`open 'https://www.vagrantup.com/downloads.html'`}

                    #
                    # setup button
                    #
                    flow do
                      button "Setup" do
                        debug "setup: running"

                          SetupVagrantCmd.new(DIRS.whph_dir, DIRS.current_dir).run

                        debug "setup: done"
                      end

                      fill Helpers::random_color
                      para "Setup whph local website. Run it only once in the very beginning"
                    end

                  end
                end
              })
    end

    flow do
      @start = button "Start Server"  do
        debug "start: running"

        @start_cmd.run

        debug "start: done"
      end

      fill Helpers::random_color
      para "start whph local website"
    end

    flow do
      button "Syncing files" do
        debug "syncing: running"

        SyncFilesCmd.new(DIRS.whph_dir, DIRS.current_dir).run

        debug "syncing: done"
      end

      fill Helpers::random_color
      para "start syncing your changes with local server"
    end

    flow do
      @open_in_browser = button "Open in browser" do
        debug "open in browser: running"

        r = `open http://work-hard.test:8001/ru/2018/`

        debug "open in browser: done"
      end

      fill Helpers::random_color
      para "Open LOCAL TEST WEBSITE in browser"
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
      @clean = button "Clean & Start Again"  do
        debug "clean: running"

        @kill_clean_start_cmd.run

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
      
      para "Press to copy ssh key to clipboard.", link("Теперь отправь по электронной почте ssh-key Коле или Дине, чотобы они дали тебе доступ к файлам на сервере сайта РБОБ"){`open 'mailto:eeefff.org@gmail.com?subject=ssh-key-from-!!!!!&body=paste-your-ssh-key-here'`}
    end

    flow do
      button "kill'em all!" do
        debug "kill: running"

        ShellCmd.stop_them_all

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
