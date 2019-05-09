#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'open3'
require 'colorize'
require 'flammarion'
require 'thread'

# TODO: - stderr.read au lieu de la boucle while
#       - menu ?
#       - Stop la commande lors d'une autre commande

# Hash de mise en couleur des mots dans les logs
$COLORIZE = [ {:str => "errors:"  , :color => :red    },
              {:str => "error:"   , :color => :red    },
              {:str => "warning:" , :color => :yellow },
              {:str => "note:"    , :color => :cyan   } ]

module ParseColor
  # Remplace les balises <> par leurs valeurs de configs
  def parse_cmd(str)
    ret = str.clone
    str.scan(/<([^>]*)>/).each do |item|
      ret = ret.sub "<#{item.first}>", @conf[:configs][item.first.to_sym].to_s
    end
    return ret
  end
end

class FenetreApp
  include ParseColor
  # Definition des principaux panes
  def p_input;    @f.pane(:p_input);                              end
  def p_conf;     @f.pane(:p_input).subpane(:conf);               end
  def p_actions;  @f.pane(:p_input).subpane(:actions);            end
  def p_log;      @f.pane(:log, weight:3).subpane(:log_actions);  end
  def p_head;     @f.pane(:log, weight:3).subpane(:log_head);     end

  # Constructeur
  def initialize(conf_file)
    # Chargement des paramètres de config
    @conf_file  = conf_file
    @conf       = YAML.load_file(@conf_file)
    @input_conf = {}
    @last_cmd   = nil
    @mutex      = Mutex.new

    # Construction de la fenêtre suivant le fichier de conf
    @f = Flammarion::Engraving.new(exit_on_disconnect:true)
    @f.orientation = :horizontal

    # Initialisation des panes
    p_input.break()
    p_input.checkbox("Configurations de l'application".yellow,
                      value: true) do |item|
      item["checked"] ? p_conf.show : p_conf.hide
    end
    p_conf
    p_input.break()
    p_input.checkbox("Actions à exécuter".yellow,
                      value: true) do |item|
      item["checked"] ? p_actions.show : p_actions.hide
    end
    p_actions
    p_head
    p_log

    # On cache le pane par defaut
    @f.pane("default").hide

    # Panel de configurations
    # Differents input d'option de l'application
    @conf[:configs].each do |key, value|
      # On stock les inputs dans un hash a part car il faut les convertir
      # en string lors de la sauvegarde
      @input_conf[key] = p_conf.input(key, value:value)
    end # each
    # Bouton de sauvegarde des paramètres
    p_conf.button("Save") do
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
    @conf[:actions].each do |item|
      p_actions.button(item[:name]) do

        cmd = parse_cmd item[:cmd]
        log_actions "#{cmd}".cyan, true
        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
          # On kill l'ancien process s'il le faut
          @mutex.lock
          if @last_cmd
            begin
              Process.kill("KILL",@last_cmd)
            rescue Errno::ESRCH
            end
          end
          # On sauvegarde le pid de ce thread pour le kill a
          # la prochaine commande executée
          @last_cmd = wait_thr.pid
          @mutex.unlock

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
          # Affichage du résultat
          @mutex.lock
          if wait_thr.value.success?
            log_actions ":Success".green
          elsif @last_cmd == wait_thr.pid
            log_actions ":Failure".red
          end # if
          @mutex.unlock
        end #popen3 cmd
      end # button
    end # each

    # Panel de log
    p_head.puts("# Logs des actions".yellow)
    p_log.puts("en attente d'actions...")

    @f.wait_until_closed
  end # initialize

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
end # FenetreApp

class FenetreError
  def initialize str
    @f = Flammarion::Engraving.new(exit_on_disconnect:true)
    @f.orientation = :horizontal
    @f.puts("error: ".red + str)
    @f.wait_until_closed
  end
end # FenetreError

# Main
if ARGV.length == 1
  conf = ARGV.first
elsif ARGV.length == 0
  conf = "app.yml"
else
  FenetreError.new("Nombre d'argument trop élevé")
end

# Test de l'existence du fichier
if File.file?(conf) == false
  FenetreError.new("fichier '#{conf}' non trouvé")
end

# Lancement de l'app
app = FenetreApp.new(conf)