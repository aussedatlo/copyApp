#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'open3'
require 'colorize'
require 'flammarion'

$CONF_FILE = "app.yml"

class FenetreApp

  # Constructeur
  def initialize(conf_file)
    # Chargement des paramètres de config
    @conf_file = conf_file
    @conf = YAML.load_file(@conf_file)
    @input_conf = {}

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
      @input_conf[key] = @f.subpane(:p_input).input(key, value:value)
    end # each
    # Bouton de sauvegarde des paramètres
    @f.subpane(:p_input).button("Save") do
      @input_conf.each do |key, value|
        log_actions "Paramètres sauvegardés", true
        # On récupère la valeur en string de chaque input
        # puis on met a jour les configs qu'on sauvegarde
        # ensuite dans le fichier yml
        @conf[:configs][key] = value.to_s
      end # each
      File.open(@conf_file, "w") { |file| file.write(@conf.to_yaml) }
    end # button

    # Panel d'actions
    @f.subpane(:p_actions)
    @f.subpane(:p_input).puts("# Actions à exécuter".yellow)
    @conf[:actions].each do |item|
      @f.subpane(:p_input).button(item[:name]) do
        @f.pane(:log, weight:1.8).subpane(:log_actions).replace("")
        log_actions "commande #{item[:name]}", true

        cmd = parse_cmd item[:cmd]
        log_actions "#{cmd}".blue
        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
          # On affiche le stdout en temps réel
          while line = stdout.gets
            puts line
          end
          # Puis on affiche toutes les erreurs d'un coup
          puts "errors:".red
          while line = stderr.gets
            puts line
          end
          puts line
          # Affichage du résultat
          if wait_thr.value.success?
            log_actions "resultat ok".green
          else
            log_actions "resultat ko".red
          end # if
        end #popen3 cmd
      end # button
    end # each

    # Panel de log
    @f.pane(:log, weight:1.8).puts("Logs des actions".yellow)
    @f.pane(:log, weight:1.8).subpane(:log_actions).puts("en attente d'actions...")
  end # initialize

  # Remplace les balises <> par leurs valeurs de configs
  def parse_cmd(str)
    ret = str.clone
    str.scan(/<([^>]*)>/).each do |item|
      ret = ret.sub "<#{item.first}>", @conf[:configs][item.first.to_sym].to_s
    end
    return ret
  end

  # Affiche dans le panel de log
  def log_actions(str, clean=false)
    if clean
      @f.pane(:log, weight:1.8).subpane(:log_actions).replace("")
      puts "=================="
    end
    puts str
    @f.pane(:log, weight:1.8).subpane(:log_actions).puts(str)
  end # log_actions

  # Attend que la fenêtre se ferme
  def wait
    @f.wait_until_closed
  end # wait
end

# Main

if ARGV.length > 0
  conf = ARGV.first
else
  conf = $CONF_FILE
end

app = FenetreApp.new(conf)
app.wait