require 'test/unit'
require 'retmx'

class RETMXTest < Test::Unit::TestCase
  def setup
    @tmx = RETMX.load("test/test.tmx")
  end
  
  def test_load
    assert_kind_of RETMX::Map, @tmx
  end
  
  def test_map
    assert_equal 1.0, @tmx.version
    assert_equal "orthogonal", @tmx.orientation
    assert_equal 10, @tmx.width
    assert_equal 20, @tmx.height
    assert_equal 32, @tmx.tilewidth
    assert_equal 32, @tmx.tileheight
    assert_equal "#aaff00", @tmx.backgroundcolor
    assert_instance_of RETMX::Properties, @tmx.property
    assert_instance_of Hash, @tmx.tilesets
    assert_instance_of Hash, @tmx.layers
    assert_instance_of Hash, @tmx.objectgroups
    assert_instance_of Hash, @tmx.imagelayers
  end
  

  def test_tilesets
    @tmx.tilesets.each {|firstgid, tileset|
      assert_kind_of RETMX::Map::TileSet, tileset
      tileset.each{|tile|
        assert_kind_of RETMX::Map::TileSet::Tile, tile
      }
      
      assert_equal("azul", tileset[1].property['color'] )
      assert_equal("rojo", tileset[2].property['color'] )
      assert_equal("verde", tileset[3].property['color'] )
      assert_equal 0, tileset.spacing
    }
  end
  
  def test_layers
    layer = @tmx.layers["layer_test"]
    assert_kind_of RETMX::Map::Layer, layer
    assert_equal "layer_test", layer.name
    assert_equal 10, layer.width
    assert_equal 20, layer.height
    assert_equal 0, layer.x
    assert_equal 0, layer.y
    assert_equal 1, layer.opacity
    assert_equal 1, layer.visible
  end
  
  def test_imagelayer
    imagelayer = @tmx.imagelayers["image_test"]
    assert_kind_of RETMX::Map::ImageLayer, imagelayer
    assert_equal "image_test", imagelayer.name
    assert_equal 10, imagelayer.width
    assert_equal 20, imagelayer.height
    assert_equal 1, imagelayer.opacity
    assert_equal 1, imagelayer.visible
    assert_equal "test", imagelayer.property['test']
    assert_equal "patron_juego.png", imagelayer.image.source
  end

  def test_objectgroup
    objectgroup = @tmx.objectgroups['object_test']
    assert_equal 10, objectgroup.width
    assert_equal 20, objectgroup.height
  end
  
  
end
