#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'net/ssh'
require 'net/scp'
require 'open3'
require 'colorize'
require 'optparse'
require 'flammarion'

$CONF_FILE = "app.yml"

class FenetreApp

  # Constructeur
  def initialize
    # Chargement des paramètres de config
    @conf = YAML.load_file($CONF_FILE)
    @input_conf = {}
    puts @conf

    # Construction de la fenêtre suivant le fichier de conf
    @f = Flammarion::Engraving.new
    @f.orientation = :horizontal

    # Panel de configurations
    @f.subpane(:p_input)
    @f.subpane(:p_input).puts("# Configurations de l'application".yellow)
    # Differents input d'option de l'application
    @conf[:configs].each do |key, value|
      # On stock les inputs dans un hash a part car il faut les convertir
      # en string lors de la sauvegarde
      puts(key)
      @input_conf[key] = @f.subpane(:p_input).input(key, value:value)
    end # each
    puts @input_conf
    # Bouton de sauvegarde des paramètres
    @f.subpane(:p_input).button("Save") do
      @input_conf.each do |key, value|
        log_actions "Paramètres sauvegardés", true
        # On récupère la valeur en string de chaque input
        # puis on met a jour les configs qu'on sauvegarde
        # ensuite dans le fichier yml
        @conf[:configs][key] = value.to_s
      end # each
      File.open($CONF_FILE, "w") { |file| file.write(@conf.to_yaml) }
    end # button

    # Panel d'actions
    @f.subpane(:p_actions)
    @f.subpane(:p_input).puts("# Actions à exécuter".yellow)
    @conf[:actions].each do |item|
      @f.subpane(:p_input).button(item["name"]) do
        @f.pane(:log).subpane(:log_actions).replace("")
        log_actions "commande #{item["name"]}", true

        if item["ssh"]
          ip = @conf[:configs]["ip"]
          user = @conf[:configs]["user"]
          tty = @conf[:configs]["tty"]
          if item["use_path"]
            cmd = @conf[:configs]["path"] + @conf[:configs]["app"] + " " + item["cmd"]
          else
            cmd = item["cmd"]
          end
          log_actions "Starting ssh connexion at #{user}@#{ip}"
          session = Net::SSH.start(ip, user)
          log_actions "Connected"
          log_actions "Executing " + cmd
          session.exec(cmd + ">" + tty)
          log_actions "Disconnecting"
          session.close
        end # if ssh
      end # button
    end # each

    # Panel de log
    @f.pane(:log).puts("Logs des actions".yellow)
    @f.pane(:log).subpane(:log_actions).puts("en attente d'actions...")





  end # initialize

  def log_actions(str, clean=false)
    if clean
      @f.pane(:log).subpane(:log_actions).replace("")
    end
    @f.pane(:log).subpane(:log_actions).puts(str)
  end # log_actions



  def wait
    @f.wait_until_closed
  end # wait
end

# Main
app = FenetreApp.new
app.wait