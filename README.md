# copyApp

Script ruby/flammarion générant une interface graphique permettant
d'executer des commandes shells directement à partir de boutons.

## Installation

Le script requiert les dépendances suivantes :

```
sudo apt install ruby gem
sudo gem install flammarion colorize
```
## Utilisation

Le script se base sur un fichier YAML afin de générer l'interface. Par défault,
le script ira chercher le fichier `app.yml` dans le dossier actuel.
Sinon, il est possible de préciser le fichier à charger de la manière suivante:

```
./App <config_file.yml>
```

Le fichier de configuration YAML est composé de deux sections principales.

### Section `:configs`

Cette section contient l'ensemble des variables qui peuvent être utilisées lors
des commandes personnalisées, mais aussi modifié directement via l'interface.

La section `:configs` est de la forme :
```yml
---
:configs:
  :variable_1: value_1
  :variable_2: value_2
  :variable_3: value_3
```

### Section `:actions`

Cette section contient l'ensemble des actions à effectuer. L'interface va
générer un bouton contenant le `:name` de la commande permettant d'effectuer la
commande `:cmd`.

Il est possible d'utiliser les variables prédéfinies dans la section `:configs`
pour adapter les commandes en utilisant les balises `<>`.

Par exemple :
```yml
---
:configs:
  :ip: 192.168.0.1
:actions:
- :name: Ping
  :cmd: ping <ip>
```
Le bouton `Ping` executera exactement la commande `ping 192.168.0.1`.


## Astuces

Pour plus de confort, créer un lien symbolique du script vers `/usr/bin`.

```
sudo ln -s /<path_install>/App.rb /usr/bin/App
App <yaml_file>
```
