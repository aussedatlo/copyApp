#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'net/scp'
require 'open3'
require 'colorize'
require 'optparse'
require 'flammarion'

class RemoteApp
  def initialize(ip_address, username, tty)
    @file        = "SuperviseurUcineo"
    @path_local  = "./build/ucineo-generic3/src/sv/"
    @path_target = "/opt/bin/superviseur/"
    @ip_address = ip_address
    @username = username
    @session = NIL
    @tty = (tty == NIL ? "" : "> #{tty}")
  end

  def connect
    @session = Net::SSH.start(@ip_address, @username)
  end

  def close
    @session.close
  end

  def start
      @session.exec!("/etc/init.d/S99superviseur start #{@tty}")
  end

  def stop
    @session.exec!("/etc/init.d/S99superviseur stop #{@tty}")
    while running? do
      sleep(1)
    end
  end

  def running?
    output = @session.exec!("ps |grep #{@file} |grep -v grep")
    output.length > 1
  end

  def upload!
    puts @path_local + @file, @path_target
    @session.scp.upload! @path_local + @file, @path_target
  end

  def rebuild!
    cmd = './build.sh ucineo-generic3'
    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        puts line
      end
      puts "errors:".red
      while line = stderr.gets
        puts line
      end
      puts line
      wait_thr.value.success?
    end
  end
end


class App
  def initialize
    @file        = "SuperviseurUcineo"
    @path_local  = "./build/ucineo-generic3/src/sv/"
    @path_target = "/opt/bin/superviseur/"

    @f = Flammarion::Engraving.new
    @f.orientation = :horizontal

    @f.puts("Gerer l'application '#{@file}'")

    @f.subpane(:actions).puts("Parameters:".yellow)
    @f.pane(:logpane).puts("Logs:".yellow)
    @f.pane(:logpane).subpane(:log).puts("En attente d'action...")

    @ip = @f.subpane(:actions).input("Ip adress", value:"192.168.0.62")
    @tty = @f.subpane(:actions).input("tty to use", value:"/dev/pts/0")
    @f.subpane(:actions).button(:start) do
      app = RemoteApp.new(@ip, "root", @tty)
      app.connect
      @f.pane(:logpane).subpane(:log).replace("Starting app\n")
      app.start
      @f.pane(:logpane).subpane(:log).puts("Start ok".green)
      app.close
    end
    @f.subpane(:actions).button(:stop) do
      app = RemoteApp.new(@ip, "root", @tty)
      app.connect
      @f.pane(:logpane).subpane(:log).replace("Stopping app\n")
      app.stop
      @f.pane(:logpane).subpane(:log).puts("Stop ok".green)
      app.close
    end
    @f.subpane(:actions).button(:build) do
      @f.pane(:logpane).subpane(:log).replace("Building app\n")
      app = RemoteApp.new(@ip, "root", @tty)
      if app.rebuild!
        @f.pane(:logpane).subpane(:log).puts("Building app ok".green)
      else
        @f.pane(:logpane).subpane(:log).puts("Building app ko".red)
      end
    end
    @f.subpane(:actions).button(:transfert) do
      @f.pane(:logpane).subpane(:log).replace("Transfert app\n")
      app = RemoteApp.new(@ip, "root", @tty)
      app.connect
      app.stop
      @f.pane(:logpane).subpane(:log).puts("Stop ok".green)
      if app.upload!
        @f.pane(:logpane).subpane(:log).puts("transfet ok".green)
      else
        @f.pane(:logpane).subpane(:log).puts("transfet failed".red)
      end
      app.close
    end
    @f.subpane(:actions).button(:all) do
      @f.pane(:logpane).subpane(:log).puts("All")
    end
  end

  def wait
    @f.wait_until_closed
  end
end

app = App.new
app.wait