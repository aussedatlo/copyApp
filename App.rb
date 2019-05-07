#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'open3'
require 'colorize'
require 'flammarion'

$CONF_FILE = "app.yml"
$COLORIZE = [ {:str => "errors:"  , :color => :red    },
              {:str => "error:"   , :color => :red    },
              {:str => "warning:" , :color => :yellow },
              {:str => "note:"    , :color => :cyan   } ]

class FenetreApp

  def p_input; @f.pane(:p_input); end
  def p_log; @f.pane(:log, weight:3).subpane(:log_actions); end
  def p_head; @f.pane(:log, weight:3).subpane(:log_head); end

  # Constructeur
  def initialize(conf_file)
    # Chargement des paramètres de config
    @conf_file = conf_file
    @conf = YAML.load_file(@conf_file)
    @input_conf = {}

    # Construction de la fenêtre suivant le fichier de conf
    @f = Flammarion::Engraving.new(exit_on_disconnect:true)
    @f.orientation = :horizontal

    # Initialisation des panes
    p_input
    p_head
    p_log
    # On cache le pane par defaut
    @f.pane("default").hide

    # Panel de configurations
    p_input
    p_input.puts("# Configurations de l'application".yellow)
    # Differents input d'option de l'application
    @conf[:configs].each do |key, value|
      # On stock les inputs dans un hash a part car il faut les convertir
      # en string lors de la sauvegarde
      @input_conf[key] = p_input.input(key, value:value)
    end # each
    # Bouton de sauvegarde des paramètres
    p_input.button("Save") do
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
    p_input.puts("# Actions à exécuter".yellow)
    @conf[:actions].each do |item|
      p_input.button(item[:name]) do

        cmd = parse_cmd item[:cmd]
        log_actions "#{cmd}".cyan, true
        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
          # On affiche le stdout en temps réel
          while line = stdout.gets
            log_actions line.strip
          end
          # Puis on affiche toutes les erreurs d'un coup
          if line = stderr.gets
            log_actions "============".red
            log_actions line.strip
          end
          while line = stderr.gets
            log_actions line.strip
          end
          puts line
          # Affichage du résultat
          if wait_thr.value.success?
            log_actions ":Success".green
          else
            log_actions ":Failure".red
          end # if
        end #popen3 cmd
      end # button
    end # each

    # Panel de log
    p_head.puts("# Logs des actions".yellow)
    p_log.puts("en attente d'actions...")
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
      p_log.replace("")
    end # if
    # Met en couleurs certains mots dans le tableau de hash COLORIZE
    $COLORIZE.each do |item|
      str.sub! item[:str], item[:str].colorize(item[:color])
    end # each
    p_log.puts(str)
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