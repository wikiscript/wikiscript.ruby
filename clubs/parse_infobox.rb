$LOAD_PATH.unshift( "./wikiscript-parser/lib" )
$LOAD_PATH.unshift( "./wikitree/lib" )

require 'wikiscript/parser'

require_relative '../countries/templates'    ## wikipedia template helpers


module Wikitree
class Template
  include TemplateHelper
end # class Template
end # module Wikitree


require 'webget'   ## note: includes/pulls in csvreader too


$LOAD_PATH.unshift( 'C:/Sites/sportdb/sport.db/sportdb-setup/lib' )

require 'sportdb/setup'
SportDb::Boot.setup   ## setup dev load path


require 'sportdb/catalogs'






path = './data/eng.clubs.txt'
recs = SportDb::Import::WikiReader.read( path )

recs.each_with_index do |rec,i|
  puts "  [#{i+1}] #{rec.name}"
end

puts "   #{recs.size} record(s)"
puts





def parse_infobox( text )   ## note: returns a data hash
  puts "==> parse_infobox:"
  puts text[0..200]
  puts

  parser = Wikiscript::Parser.new( text )
  nodes = parser.parse

  puts "#{nodes.size} node(s):"
  ## pp nodes

  refs = Wikiscript::References.new( nodes )  ## note: (SIDE EFFECT!) will auto-number reference (nodes)

  infobox = Wikiscript::Infobox.new( nodes[0] )
  data = infobox.to_json

  ## adding refs
  puts "adding refs:"
  refs = refs.to_json
  pp refs
  data.merge!( refs )
  data
end



######################
## cache root for wikipedia .txt pages
root = "#{Webcache.root}/en.wikipedia.org"


outdir = "./clubs/o"


recs.each_with_index do |rec,i|
  name   = rec.name.gsub( ' ', '_' )

  puts "   >#{name}<"

  txt = File.open( "#{root}/#{name}.txt", 'r:utf-8') {|f| f.read }
  pp txt[0..200]
  puts

  infobox_txt = Wikiscript.find_infobox( txt )
  pp infobox_txt[0..200]
  puts


  path = "#{outdir}/_source/#{name}.txt"
  FileUtils.mkdir_p( File.dirname( path ) ) ## make sure path exits

  File.open( path, 'w:utf-8') {|f| f.write( infobox_txt ) }


  data = parse_infobox( infobox_txt )


  path = "#{outdir}/#{name}.json"
  FileUtils.mkdir_p( File.dirname( path ) ) ## make sure path exits

  File.open( path, 'w:utf-8') { |f| f.write( JSON.pretty_generate( data )) }

  ## break if i > 2
end

puts "bye"

