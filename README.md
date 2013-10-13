RETMX
=====
Libreria Ruby que permite leer archivo TMX (Map Format) de mapeditor.org

Falta:
 * tileset > terraintypes
 
 
```ruby
 tmx = RETMX.load("myfile.tmx")
 tmx.layers.each {|name, layer| ...} #iterate over layers
 tmx.tilesets.each {|firstgid, tileset| ... #iterate  tilesets
  tileset.each { |tile| #iterate tiles of the tileset
   ...
  tile.property.each {|name, value| ...} #iterate properties
  }
 }
 tmx.objectgroups.each{|name, objectgroup| ...
```

.

Ruby Reader TMX Map Format
