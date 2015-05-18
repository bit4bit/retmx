#Libreria para leer archivo TMX de mapeditor.org
#Author:: Jovany Leandro G.C (mailto: bit4bit@riseup.net)
#Copyright:: Copyright (c) 2013 Jovany Leandro G.C
#License:: GPLv3 or any later version
#date: 2011-12-10
#last-update: 2013-10-12
require 'rexml/document'
require 'base64'
require 'zlib'
require 'stringio'

#=== RETMX
#This is a library for read TMX Map-Form
#now support 0.8 of the format.
#
#example:
#<code>
#tmx = RETMX.load("myfile.tmx")
#tmx.layers.each {|name, layer| ...} #iterate over layers
#tmx.tilesets.each {|firstgid, tileset| ... #iterate  tilesets
# tileset.each { |tile| #iterate tiles of the tileset
#  ...
# tile.property.each {|name, value| ...} #iterate properties
# }
#}
#tmx.objectgroups.each{|name, objectgroup| ...
#</code>
module RETMX
  include REXML

  def RETMX.load(file)
    m = Map.new(file)
  end


  #Wraps any number of custom properties. Can be used as a child of the map, tile (when part of a tileset), layer, objectgroup and object elements.
  class Properties
    include Enumerable


    def initialize(xml)
      @xml = xml
      @property = {}
      @xml.elements.each('properties/property') {|e|
        @property[e.attributes['name']] = e.attributes['value']
      }
    end

    def [](i)
      @property[i]
    end

    #Iterate over properties calling block with +name+ and +value+ of property
    def each
      @property.each {|n, v| yield n,v}
    end
  end


  #The +tilewidth+ and +tileheight+ properties determine the general grid size of the map. The individual tiles may have different sizes. Larger tiles will extend at the top and right (anchored to the bottom left).
  class Map


    #The TMX format version, generally 1.0
    attr_reader :version

    #Map orientation. Tiled supports "orthogonal" and "isometric" at the moment.
    attr_reader :orientation

    #The map width in tiles.
    attr_reader :width

    #The map height in tiles.
    attr_reader :height

    #The width of a tile.
    attr_reader :tilewidth

    #The height of a tile.
    attr_reader :tileheight

    #The background color of the map. (since 0.9.0)
    attr_reader :backgroundcolor
    
    #Layers on map
    attr_reader :layers
    
    #Tileset on map
    attr_reader :tilesets

    #Objects groups on map
    attr_reader :objectgroups

    #ImageLayers
    attr_reader :imagelayers
    
    #Properties on map
    attr_reader :property

    #File where get map
    attr_reader :file

    #REXML internal
    attr_reader :xml
    def initialize(file)

      raise RuntimeError, "Need a .tmx" unless File.exists? file
      doc = REXML::Document.new(File.new(file)).root
      doc.context['base_path'] = File.dirname(file)
      @file = file
      @version = doc.attributes['version'].to_f
      @orientation = doc.attributes['orientation']
      @width = doc.attributes['width'].to_i
      @height = doc.attributes['height'].to_i
      @tilewidth = doc.attributes['tilewidth'].to_i
      @tileheight = doc.attributes['tileheight'].to_i
      @backgroundcolor = doc.attributes['backgroundcolor']
      @tilesets = {}
      @layers = {}
      @objectgroups = {}
      @imagelayers = {}
      @xml = doc

      build(doc)
    end

    private
    def build(doc)
      doc.elements.each("tileset") { |e|
        @tilesets[e.attributes['firstgid']] = TileSet.new(self, e)
      }
      @tilesets.sort_by { |k,v| k} #sort asc
      doc.elements.each("layer") { |e|
        @layers[e.attributes['name']] = Layer.new(self, e)
      }
      doc.elements.each("imagelayer") { |e|
        @imagelayers[e.attributes['name']] = ImageLayer.new(self, e)
      }
      doc.elements.each("objectgroup") { |e|
        @objectgroups[e.attributes['name']] = ObjectGroup.new(self, e)
      }
      @property = Properties.new(doc)
    end

    #The object group is in fact a map layer, and is hence called "object layer" in Tiled Qt.
    class ObjectGroup
      include Enumerable

      #The name of the object group.
      attr_reader :name

      #The x coordinate of the object group in tiles. Defaults to 0 and can no longer be changed in Tiled Qt.
      attr_reader :x

      #The y coordinate of the object group in tiles. Defaults to 0 and can no longer be changed in Tiled Qt.
      attr_reader :y

      #The width of the object group in tiles. Meaningless.
      attr_reader :width

      #The height of the object group in tiles. Meaningless
      attr_reader :height


      def initialize(map, xml)
        @map = map
        @name = xml.attributes['name']
        @x = xml.attributes['x'].to_i
        @y = xml.attributes['y'].to_i
        @width = xml.attributes['width'].to_i
        @height = xml.attributes['height'].to_i
        @opacity = xml.attributes['opacity'].nil? ? 1.0 : xml.attributes['opacity'].to_f
        @visible = xml.attributes['visible'].nil? ? 1 : xml.attributes['visible'].to_i
        
        @objects = {}
        build(xml)
      end


      def each(type = nil)
        return @objects[type].each { |i| yield i}  unless type.nil?
        return @objects.each { |i| yield i}
      end
      
      private
      def build(xml)
        xml.elements.each('object') {|e|
          @objects[e.attributes['type']] ||= []
          @objects[e.attributes['type']] << Object.new(self, e)
        }
      end


=begin
While tile layers are very suitable for anything repetitive aligned to the tile grid, sometimes you want to annotate your map with other information, not necessarily aligned to the grid. Hence the objects have their coordinates and size in pixels, but you can still easily align that to the grid when you want to.

You generally use objects to add custom information to your tile map, such as spawn points, warps, exits, etc.

When the object has a gid set, then it is represented by the image of the tile with that global ID. Currently that means width and height are ignored for such objects. The image alignment currently depends on the map orientation. In orthogonal orientation it's aligned to the bottom-left while in isometric it's aligned to the bottom-center.  
=end
      class Object
        #The name of the object. An arbitrary string.
        attr_reader :name

        #The type of the object. An arbitrary string.
        attr_reader :type
        
        #The x coordinate of the object in pixels.
        attr_reader :x

        #The y coordinate of the object in pixels.
        attr_reader :y

        #The width of the object in pixels.
        attr_reader :width

        #The height of the object in pixels.
        attr_reader :height

        #An reference to a tile (optional).
        attr_reader :gid

        #Properties
        attr_reader :property

        #The rotation of the object in degrees clockwise.
        attr_reader :rotation
        
        #Whether the object is shown (1) or hidden (0). Defaults to 1.
        attr_reader :visible

        #Points only for polygon, polyline
        attr_reader :points
        
        def initialize(og, e)
          @objectgroup = og
          @name = e.attributes['name']
          @type = e.attributes['type']
          @x = e.attributes['x'].to_i
          @y = e.attributes['y'].to_i
          @width = e.attributes['width'].to_i
          @height = e.attributes['height'].to_i
          @gid = e.attributes['gid'].nil? ? nil : e.attributes['gid'].to_i
          @rotation = e.attributes['rotation'].to_i
          @visible = e.attributes['visible'].nil? ? 1 : e.attributes['visible'].to_i
          
          @property = Properties.new(e)
          @points ||= get_points(e, 'polyline')
          @points ||= get_points(e, 'polygon')
        end

        private 
        def get_points(e, type)
          points = []
          e.elements.each(type){|pe|
            x1 = x2 = y1 = y2 = 0
            pe.attributes['points'].split(' ').each {|pair|
              x, y = pair.split(',').map{|v| v.to_i}
              points << [@x + x, @y + y]
            }
          }
          return points if points.size > 0
          return nil
        end
      
      end
    end

    class ImageLayer
      #The name of the image layer
      attr_reader :name
     
      #The width of the image layer in tiles. Meaningless.
      attr_reader :width

      #The height of the image layer in tiles. Meaningless.
      attr_reader :height
      
      #The opacity of the layer as a value from 0 to 1. Defaults to 1.
      attr_reader :opacity

      #Whether the layer is shown (1) or hidden (0). Defaults to 1.
      attr_reader :visible

      #Properties
      attr_reader :property
      
      #Imagen
      attr_reader :image
      
      #Map Belongs
      attr_reader :map
      def initialize(map, xml)
        @map = map
        @name = xml.attributes['name']
        @width = xml.attributes['width'].to_i
        @height = xml.attributes['height'].to_i

        @opacity = 1
        @opacity = xml.attributes['opacity'].to_f  unless xml.attributes['opacity'].nil?
        
        @visible = 1
        @visible = xml.attributes['visible'].to_i unless xml.attributes['visible'].nil?
        @image = Image.new(xml)
        @property = Properties.new(xml)
      end
      
    end
    

    class Layer
      #The name of the layer.
      attr_reader :name

      #The x coordinate of the layer in tiles. Defaults to 0 and can no longer be changed in Tiled Qt.
      attr_reader :x

      #The y coordinate of the layer in tiles. Defaults to 0 and can no longer be changed in Tiled Qt.
      attr_reader :y

      #The width of the layer in tiles. Traditionally required, but as of Tiled Qt always the same as the map width.
      attr_reader :width

      #The height of the layer in tiles. Traditionally required, but as of Tiled Qt always the same as the map height.
      attr_reader :height

      #The opacity of the layer as a value from 0 to 1. Defaults to 1.
      attr_reader :opacity

      #Whether the layer is shown (1) or hidden (0). Defaults to 1.
      attr_reader :visible

      #Data
      attr_reader :data

      #Map belongs
      attr_reader :map
      
      #Properties 
      attr_reader :property

      def initialize(map, xml)
        @map = map
        @name = xml.attributes['name']
        @x =  xml.attributes['x'].nil? ? 0 : xml.attributes['x']
        @y = xml.attributes['y'].nil? ? 0 : xml.attributes['y']
        @width = xml.attributes['width'].nil? ? map.width : xml.attributes['width'].to_i
        @height = xml.attributes['height'].nil? ? map.height : xml.attributes['height'].to_i
        @opacity = xml.attributes['opacity'].nil? ? 1 : xml.attributes['opacity'].to_i
        @visible = xml.attributes['visible'].nil? ? 1 : xml.attributes['visible'].to_i
        @opacity = xml.attributes['opacity'].nil? ? 1 : xml.attributes['opacity'].to_f
        @data = nil
        build(xml)
      end

      
      #This function is used for render the layer
      def render(&block) #:yields: block_y, block_x, tileset, index
        srect = Struct.new(:x, :y, :w, :h)
        @height.times {|by| #block row
          @width.times {|bx| #block col 
            cell = @data[(by * @width) + bx ]
            
            @map.tilesets.reverse_each {|k, t|
              if t.firstgid <= cell.gid
                cell = cell.clone
                cell.gid -= t.firstgid
                block.call(self, bx, by, t, cell)
                break
              end
            }
          }
        }

      end

      #This function render partial of layer
      #:x: offset in tiles
      #:y: offset in tiles
      #:w: in tiles
      #:h: in tiles
      def render_partial(x, y, w, h, &block)
        h.times {|by|
          w.times {|bx|
            
            cell = @data[((by + y )  * @width) + (bx + x + @height)]
            @map.tilesets.reverse_each {|k, t|

              if t.firstgid <= cell.gid
                cell = cell.clone
                cell.gid -= t.firstgid
                block.call(self, bx, by, t, cell)
                break
              end
            }
          }
        }
      end
      
        
      #This function render partial of layer using pixel
      #:x: offset in pixel
      #:y: offset in pixel
      #:w: in pixel
      #:h: in pixel
      def render_partial_pixel(px, py, pw, ph, &block)
        cols = pw / map.tilewidth
        rows = ph / map.tileheight
        rows += 1; cols += 1
        y = py / map.tileheight
        x = px / map.tilewidth
        rows.times {|by|
          cols.times {|bx|
            cell = @data[((by + y )  * @width) + (bx + x + @height)]
            @map.tilesets.each {|k, t|

              if t.firstgid <= cell.gid
                cell = cell.clone
                cell.gid -= t.firstgid
                block.call(self, bx, by, t, cell)
                break
              end
            }
          }
        }
      end

      private
      def build(doc)
        @data = Data.new(self, doc.elements['data'])
        @property = Properties.new(doc)
      end

      class Data
        include Enumerable
        GID_FLIP_X = 0x80000000 #horizontally
        GID_FLIP_Y = 0x40000000 #vertically
        GID_FLIP_D = 0x20000000 #diagonally

        #The encoding used to encode the tile layer data. When used, it can be "base64" and "csv" at the moment.
        attr_reader :encoding

        #The compression used to compress the tile layer data. Tiled Qt supports "gzip" and "zlib".
        attr_reader :compression

        #Layer belongs
        attr_reader :layer

        #REXML internal
        attr_reader :xml


        def initialize(layer, xml)
          @layer = layer
          @xml = xml
          @encoding = xml.attributes['encoding']
          @compression = xml.attributes['compression']
          
          @raw = []
          @raw_data = xml.text
          @data = []

          #decoding
          case @encoding
            when 'base64'
            @raw_data = Base64.decode64(@raw_data)
            when 'csv'
            @raw_data = @raw_data.tr("\n",'')
          end

          #inflate compress
          case @compression
          when 'zlib'
            zs = Zlib::Inflate.new
            @raw_data = zs.inflate(@raw_data)
            zs.finish
            zs.close
          when 'gzip'
            gz = Zlib::GzipReader.new(StringIO.new(@raw_data))
            @raw_data = gz.read
            gz.close
          end

          #Data XML
          if @encoding.nil? and @compression.nil?
            xml.elements.each('tile') {|e|
              @raw << e.attributes['gid'].to_i
            }
          elsif @encoding == 'csv'
            @raw = @raw_data.split(',').collect {|x| x.to_i}
          else
            @raw = @raw_data.unpack("L*")
          end

          get_data
        end

        def size
          @data.size
        end

        def [] (i)
          @data[i]
        end

        def each
          @data.each { |i| yield i }
        end

        private

        #Discover, global tile id
        def decode_gid(raw_gid)
          flags = 0
          flags += 1 if (raw_gid & GID_FLIP_X) == GID_FLIP_X
          flags += 2 if (raw_gid & GID_FLIP_Y) == GID_FLIP_Y
          flags += 3 if (raw_gid & GID_FLIP_D) == GID_FLIP_D
          gid = raw_gid & ~(GID_FLIP_X | GID_FLIP_Y | GID_FLIP_D)
          return [gid, flags]
        end

        #Extract array of gids from array of ints
        def get_data
          tile_index = 0
          srect = Struct.new(:x, :y, :w, :h)
          gi = Struct.new(:gid, :flags, :rect)
          @layer.height.times {|y|
            @layer.width.times {|x|
              next_gid = @raw[tile_index]
              gid, flags = decode_gid(next_gid)
            
              rect = nil
              @layer.map.tilesets.reverse_each {|k, t|
                if t.firstgid <= gid
                  cell_gid = gid - t.firstgid
                  cols = t.image.width / t.tilewidth
                  rect = srect.new(
                                     t.margin + (t.tilewidth + t.spacing) * (cell_gid % cols.to_i),
                                     t.margin + (t.tileheight + t.spacing) * (cell_gid / cols.to_i),
                                     t.tilewidth,
                                     t.tileheight
                                     )

                  break
                end
              }

              @data[tile_index] = gi.new(gid, flags, rect)
              tile_index += 1             
            }
          }
        end
      end
    end


    class TileSet
      include Enumerable

      #The first global tile ID of this tileset (this global ID maps to the first tile in this tileset).
      attr_reader :firstgid
      
      #If this tileset is stored in an external TSX (Tile Set XML) file, this attribute refers to that file.
      attr_reader :source

      #The name of this tileset.
      attr_reader :name

      #The (maximum) width of the tiles in this tileset.
      attr_reader :tilewidth

      #The (maximum) height of the tiles in this tileset.
      attr_reader :tileheight

      #The spacing in pixels between the tiles in this tileset (applies to the tileset image).
      attr_reader :spacing

      #The margin around the tiles in this tileset (applies to the tileset image).
      attr_reader :margin

      #Image has
      attr_reader :image

      #Properties
      attr_reader :property

      #Map belongs
      attr_reader :map

      attr_reader :tiles
      def initialize(map, xml)
        @map = map
        @firstgid = xml.attributes['firstgid'].to_i
        @source = xml.attributes['source']
        
        unless @source.nil?
          xml = REXML::Document.new(File.new(File.join(xml.context['base_path'], @source))).root
        end

        @name = xml.attributes['name']
        @tilewidth = xml.attributes['tilewidth'].to_i
        @tileheight = xml.attributes['tileheight'].to_i
        @spacing = xml.attributes['spacing'].nil? ? 0 : xml.attributes['spacing'].to_i
        @margin = xml.attributes['margin'].nil? ? 0 : xml.attributes['margin'].to_i

        @image = nil
        #array of Rects that know how cut a image
        @tiles = {}
        build(xml)

      end

      
      #Get tile at index +i+
      def at(i)
        return @tiles[i] if @tiles.has_key?(i)
      end

      def [](i)
        return @tiles[i] if @tiles.has_key?(i)
      end
      
      def each
        @tiles.each{|id, tile| yield tile}
      end
      
      private
      def build(xml)
        @image = Image.new(xml, File.dirname(@source.to_s))
        @property = Properties.new(xml)
        
        xml.elements.each('tile') do |e|
          @tiles[e.attributes['id'].to_i] = Tile.new(e)
        end
        
      end

      class Tile
        #The local tile ID within its tileset.
        attr_reader :id

        #propierties for tile
        attr_reader :property

        #@todo terrain how work?

        def initialize(e)
          @property = Properties.new(e)
          @id = e.attributes['id'].to_i
        end
      end
    end
    class Image
      #The reference to the tileset image file (Tiled supports most common image formats).
      attr_reader :source
      
      #Defines a specific color that is treated as transparent (example value: "FF00FF" for magenta).
      attr_reader :trans
      
      #Width of image
      attr_reader :width
      
      #Height of image
      attr_reader :height
      
      def initialize(xml, base_path = "")
        doc = xml.elements['image']
        @source = File.join(base_path, doc.attributes['source'].to_s)
        @trans = doc.attributes['trans'].to_s
        @width = doc.attributes['width'].to_i
        @height = doc.attributes['height'].to_i
      end
    end
  end
end
